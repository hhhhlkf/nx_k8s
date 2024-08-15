#!/bin/bash
c="../nfs_share"
ip_address=""
NETWORK_CIDR="10.10.0.0/16"
sudo apt install -y apt-transport-https ca-certificates curl

curl https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | sudo apt-key add -

cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main
EOF

## 本地下载kubeadm、kubelet和kubectl
# 检查kubeadm、kubelet和kubectl是否已经安装
if ! (command -v kubeadm &> /dev/null) && ! (command -v kubelet &> /dev/null) && ! (command -v kubectl &> /dev/null)
then
    echo "kubeadm, kubelet or kubectl not installed, starting installation..."

    # 更新apt包索引
    sudo apt-get update

    # 安装指定版本的kubeadm、kubelet和kubectl
    sudo apt install -y kubeadm=1.23.3-00 kubelet=1.23.3-00 kubectl=1.23.3-00

    echo "kubeadm, kubelet and kubectl installed successfully"
else
    echo "kubeadm, kubelet and kubectl already installed"
fi


kubeadm version
kubectl version --client


## 循环安装镜像
# 保持软件版本不变
sudo apt-mark hold kubeadm kubelet kubectl

repo=registry.aliyuncs.com/google_containers

for name in `kubeadm config images list --kubernetes-version v1.23.3`; do
    src_name=${name#k8s.gcr.io/}
    src_name=${src_name#coredns/}

    # Check if the image exists
    # docker image inspect $name > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        docker pull $repo/$src_name
        docker tag $repo/$src_name $name
    fi
done

## kubeadm初始化
# 检查网络连接类型

if ip link show eth0 | grep -q "state UP"; then
    # 有线连接
    echo "Ethernet connection detected"
    ip_address=$(ip -f inet -o addr show eth0|cut -d\  -f 7 | cut -d/ -f 1)
    echo "IP address: $ip_address"
elif ip link show wlan0 | grep -q "state UP"; then
    # 无线连接
    echo "Wireless connection detected"
    ip_address=$(ip -f inet -o addr show wlan0|cut -d\  -f 7 | cut -d/ -f 1)
    # 输出ip
    echo "IP address: $ip_address"
else
    echo "No active network connection detected"
    exit 1
fi



# 使用获取的IP地址运行kubeadm init命令
output=$(sudo kubeadm init --pod-network-cidr=$NETWORK_CIDR --apiserver-advertise-address=$ip_address --kubernetes-version=v1.23.3)

# 从输出中提取kubeadm join命令
join_command=$(echo "$output" | grep -A 2 'kubeadm join' | sed ':a;N;$!ba;s/\n/ /g')

join_command=$(echo "$join_command" | tr -d '\\\n\t')

# 将kubeadm join命令保存到shell脚本文件
echo "$join_command" > ../worker/join_command.sh

# 修改文件权限，使其可执行
chmod +x ../worker/join_command.sh

echo "kubeadm join command saved to join_command.sh"

if which sshpass >/dev/null; then
    echo "sshpass is installed."
else
    sudo apt-get install sshpass
fi

#将整个文件发送到worker节点
while true; do
    read -p "Enter worker node IP (or 'exit' to quit): " ip
    if [ "$ip" = "exit" ]; then
        break
    fi
    sshpass -p root ssh root@$ip "rm -rf /home/nvidia/nx_k8s"
    sshpass -p root scp -r ../../nx_k8s root@$ip:/home/nvidia/
done


# 配置kubectl
mkdir -p $HOME/.kube 
sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config 
sudo chown $(id -u):$(id -g) $HOME/.kube/config

kubectl version
kubectl get node

## 安装网络插件
# 使用sed命令修改文件内容
cp -f ../template/kube-flannel.yml .

sed -i "s|\"Network\": \".*\"|\"Network\": \"$NETWORK_CIDR\"|g" kube-flannel.yml

echo "File kube-flannel.yml has been modified."

kubectl apply -f kube-flannel.yml

# 初始化ready变量为0
ready="NotReady"

# 使用while循环定期检查Master节点的状态
while [ "$ready" != "Ready" ]; do
    # 使用kubectl get nodes命令获取Master节点的状态
    output=$(kubectl get nodes)

    # 使用grep和awk命令解析输出，获取STATUS列的值
    ready=$(echo "$output" | grep master | awk '{print $2}')

    # 如果Master节点还没有准备好，等待5秒然后再次检查
    if [ "$ready" != "Ready" ]; then
        echo "Waiting for Master node to be ready..."
        sleep 3
    fi
done

echo "flannel is running successfully."


# 去除master节点的污点
kubectl taint node master node-role.kubernetes.io/master:NoSchedule-
# 修改DiskPressure阈值
# 使用grep命令找到所有包含"EnvironmentFile="的行，然后使用awk命令提取第二个这样的行
line=$(grep 'EnvironmentFile=' /etc/systemd/system/kubelet.service.d/10-kubeadm.conf | awk 'NR==2')

# 使用sed命令从行中提取路径
path=$(echo "$line" | sed 's/EnvironmentFile=-//')

# 将文本添加到路径指向的文件中
text="KUBELET_EXTRA_ARGS=--root-dir=/apps/data/kubelet --eviction-hard=nodefs.available<2% --eviction-hard=imagefs.available<2% --eviction-hard=memory.available<10%"

# 检查文件中是否已经包含该文本
if ! (grep -q "$text" "$path"); then
    # 如果文件中不包含该文本，将其添加到文件中
    echo "$text" > "$path"
fi
# 安装NFS服务端
if ! (dpkg -l | grep -q nfs-kernel-server); then
    # 如果没有安装，使用apt-get命令来安装它
    sudo apt-get install -y nfs-kernel-server
fi

sleep 3
# 创建NFS共享目录
# 检查目录是否存在
if [ ! -d "$dir" ]; then
    # 如果目录不存在，创建它
    sudo mkdir -p "$dir"
    echo "Directory $dir has been created."
else
    echo "Directory $dir already exists."
fi

# 删除/etc/exports文件中包含特定文本的行
sudo sed -i '/(rw,sync,no_subtree_check,no_root_squash,insecure)/d' /etc/exports

dir=$(realpath "$dir")

# 修改/etc/exports文件
echo "$dir *(rw,sync,no_subtree_check,no_root_squash,insecure)" | sudo tee -a /etc/exports


# 重新加载NFS配置
sudo exportfs -ra
sudo exportfs -v

# 启动NFS服务
sudo systemctl start  nfs-server
sudo systemctl enable nfs-server
sudo systemctl status nfs-server

showmount -e 127.0.0.1

# 使用sed命令修改文件内容
cp -f ../template/deployment.yaml .
sed -i "s/XXX.XXX.XXX.XXX/$ip_address/g" deployment.yaml
sed -i "s|/this/is/nfs/path|$dir|g" deployment.yaml

echo "File deployment.yaml has been modified."


cp -f ../template/rbac.yaml .
cp -f ../template/class.yaml .
kubectl apply -f rbac.yaml
kubectl apply -f class.yaml
kubectl apply -f deployment.yaml

# 初始化ready变量为0
ready="0/1"

# 使用while循环定期检查nfs-client-provisioner的状态
while [ "$ready" != "1/1" ]; do
    # 使用kubectl get deploy命令获取nfs-client-provisioner的状态
    output=$(kubectl get deploy nfs-client-provisioner -n kube-system)

    # 使用grep和awk命令解析输出，获取READY列的值
    ready=$(echo "$output" | grep nfs-client-provisioner | awk '{print $2}')

    # 如果nfs-client-provisioner还没有运行成功，等待5秒然后再次检查
    if [ "$ready" != "1/1" ]; then
        echo "Waiting for nfs-client-provisioner to be ready..."
        sleep 3
    fi
done

echo "nfs-client-provisioner is running successfully."

while true; do
    read -p "Do you want to create a statefulset? (yes/no): " answer

    case $answer in
        [Yy]* ) 
            while true; do
                read -p "Do you want to create a changeos model? (yes/no): " answer_model
                case $answer_model in
                    [Yy]* ) 
                        # 如果选择创建 changeos 模型，运行对应的脚本
                        bash ./master_sts_changeos_create.sh
                        break;;
                    [Nn]* ) 
                        # 如果选择不创建 changeos 模型，运行原来的脚本
                        bash ./master_sts_create.sh
                        break;;
                    * ) echo "Please answer yes or no.";;
                esac
            done
            ;;
        [Nn]* ) break;;
        * ) echo "Please answer yes or no.";;
    esac
done

