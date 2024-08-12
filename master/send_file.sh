#!/bin/bash

# 定义目标主机的用户名、密码和IP地址
username=<username>
password=<password>
ip=<ip>

# 定义文件的路径
path="/home/nvidia/Desktop/FileSend"

# 循环发送文件
while true; do
    # 找到文件夹中的所有.txt和.png文件，并按照文件名中的坐标从小到大排序
    files=$(ls $path/UAV_*.txt $path/UAV_*.png $path/DAM_*.txt $path/DAM_*.png | sort -t '_' -k2n -k3n)

    for file in $files; do
        # 发送文件
        echo $password | scp "$file" "$username@$ip:/path/to/destination"

        # 删除已发送的文件
        rm "$file"

        # 每秒发送一次
        sleep 1
    done
done