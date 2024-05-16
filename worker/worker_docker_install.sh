# !/bin/bash

# 检查Docker是否已经安装
if ! (command -v docker &>/dev/null); then
    echo "Docker is not installed, start to install Docker.."

    # 更新apt包索引
    sudo apt-get update

    # 安装docker引擎
    sudo apt install docker.io=20.10.21
    sudo service docker start

    # 添加当前用户到docker用户组
    sudo usermod -aG docker ${USER}

    # 设置docker开机自启
    sudo systemctl enable docker

    echo "Docker is installed successfully!"

    docker version
    docker info
else
    echo "Docker has been installed!"
fi

# 修改节点名称
sudo hostnamectl set-hostname Worker

echo "The hostname of the node is changed to worker!"

# cgroup驱动修改
cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

EOF

sudo systemctl enable docker
sudo systemctl daemon-reload
sudo systemctl restart docker

#配置网络
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward=1 # better than modify /etc/sysctl.conf
EOF

sudo sysctl --system

# 修改/etc/fstab文件

# 检查swap是否已经关闭
if [[ $(cat /proc/swaps | wc -l) -le 1 ]]; then
    echo "Swap is already off."
    # 运行脚本master_k8s_install.sh
else
    echo "Swap is on. Turning off..."

    # 关闭swap
    sudo swapoff -a
    sudo sed -ri '/\sswap\s/s/^#?/#/' /etc/fstab

    echo "Swap is turned off."

fi
