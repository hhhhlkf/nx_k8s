#!/bin/bash
dir="../nfs_share"
ip_address=""
NETWORK_CIDR="10.10.0.0/16"

kubeadm reset

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
    docker image inspect $name > /dev/null 2>&1
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

bash join_command.sh

sudo apt -y install nfs-common