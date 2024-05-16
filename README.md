# 脚本运行相关说明

## 运行前准备

- nx板系统预装时默认不开启ssh远程连接，因此需要手动修改相关配置，具体参考：

https://blog.csdn.net/LUCKWXF/article/details/96107481 中问题二的解决方案。

- 需将各nx板系统的root用户密码修改成root，以便统一访问。
- 该脚本建议在root用户下运行

## Master脚本运行

在master节点下的k8s/master文件夹下运行下述脚本。运行前需注意，作为master和worker的服务器均需处于一个网段中。

```shell
bash master_docker_install.sh
```

> [!IMPORTANT]
>
> 由于拷贝操作需要ssh密钥验证，可以在运行所有脚本之前先在master节点上对所有待加入worker结点进行ssh远程登陆以自动获取权限，之后master结点将可以通过ssh给worker结点传输数据。

## Worker脚本运行

当master节点相关脚本运行到输入ip以添加结点时，输入想要添加的worker结点ip，该脚本文件夹将会被拷贝到worker结点，至此务必先运行worker结点。在每个worker节点下的k8s/worker文件夹下运行下述脚本：

```shell
bash worker_docker_install.sh
```

## 脚本结构

树状图展示了脚本文件夹k8s的具体结构：

```bash
k8s
├── check_output
│   ├── redis1-pv-sts.txt
│   └── redis-pv-sts.txt
├── master
│   ├── check_isdone.sh
│   ├── check_script.sh
│   ├── class.yaml
│   ├── deployment.yaml
│   ├── divide_images.sh
│   ├── kube-flannel.yml
│   ├── master_docker_install.sh
│   ├── master_k8s_install.sh
│   ├── master_shutdown.sh
│   ├── master_sts_create.sh
│   ├── rbac.yaml
├── nfs_share
│   ├── default-redis1-50mi-pvc-redis1-pv-sts-0-pvc-a7f11298-5657-4cf1-8fac-497663949c5f
│   │   └── done
│   ├── default-redis-50mi-pvc-redis-pv-sts-0-pvc-e90c1049-e8e4-4f2f-8d0f-040752f539eb
│   │   └── done
│   └── default-redis-50mi-pvc-redis-pv-sts-1-pvc-9eb63a4e-6e9f-432b-b94f-fd30c55eae97
│       └── done
├── template
│   ├── class.yaml
│   ├── deployment.yaml
│   ├── kube-flannel.yml
│   ├── rbac.yaml
│   └── sts_template.yml
└── worker
    ├── join_command.sh
    ├── worker_docker_install.sh
    └── worker_k8s_install.sh
```

### master文件夹

- master文件夹中包含了master节点应该运行的脚本，其中：

`master_docker_install.sh` ：一键安装运行该脚本即可。该脚本在运行结束后会启动运行 `master_k8s_install.sh`脚本

`master_k8s_install.sh`：该脚本主要工作为安装k8s，安装flannel服务端，配置NFS，并循环询问是否部署各模型，若开始部署，则在循环内运行 `aster_sts_create.sh`

`master_sts_create.sh`：该脚本主要工作为部署各模型。在该脚本运行时，需要用户分别输入：*镜像名*、*模型容器名称(statefulSet Name)*、*副本数*、*volume分配空间大小*、*输入指令*、*输入参数*。在其中输入参数格式为：

```bash
["bash", "-c", "command1 && command2 && command3"]
```

在模型容器创建完毕后，脚本内部将运行 `divide_images.sh`进行数据分流，运行 `check_isdone.sh`在后台循环判断模型是否运行完毕

`check_isdone.sh`：该脚本主要为了检测模型是否运行完毕。具体判断条件为循环查看该模型副本挂载的所有文件夹中是否都含有done文件，如果所有的文件夹都有则停止模型服务。运行过程中，脚本的输出保存在check_output文件夹中的 `容器名.txt`中。

`master_shutdown.sh`：关闭整个微服务架构。想要重新运行 `master_docker_install.sh`需要先运行该脚本。

- master文件夹中还包含了若干.yaml文件，该文件用于构建NFS 动态存储卷。
- master文件夹中还包含了flannel.yml文件，该文件用于加载flannel集群通信插件。

### worker文件夹

worker文件夹中包含了worker节点应该运行的脚本，其中：

`worker_docker_install.sh`：一键安装运行该脚本即可。该脚本在运行结束后会启动运行 `worker_k8s_install.sh`脚本

`master_k8s_install.sh`：该脚本主要工作为安装k8s，运行 `join_command.sh`与master连接构成集群，并安装flannel客户端。

`join_command.sh`：该脚本是master节点安装好kubeadm后自动生成的脚本，在worker上执行后该节点将加入master组织的集群。

> [!IMPORTANT]
>
> 注意，worker节点的k8s文件夹是由master节点在安装好kubeadm后直接复制过来的。因此需要等master上的脚本开始提示 `Enter worker node IP (or 'exit' to quit):`字样时，输入对应worker 的IP地址。该步骤后worker节点将接收到k8s文件夹，在此时要开始运行 `worker_docker_install.sh`

### check_output文件夹

用来存储检测模型是否运行完毕的输出，即 `check_isdone.sh`的输出。

### nfs_share文件夹

即NFS共享文件夹存储目录。每一个副本将在该文件夹中创建一个共享文件夹，该副本会指定内部环境的./data文件夹与副本在外部环境自动创建的共享文件夹进行链接，为了使副本可以和外部环境进行数据交互。

### template文件夹

为了满足各种k8s组件的需要，将使用template文件夹中的模板来创建各组件的配置文件，自定义好的配置文件将被存储在master文件夹中。
