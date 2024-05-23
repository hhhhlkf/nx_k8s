#!/bin/bash

## 构建模型的sts
# 提示用户输入StatefulSet名字
read -p "Enter the StatefulSet name: " statefulset_name

# 提示用户输入副本数
read -p "Enter the number of replicas: " replicas

# 提示用户输入volume分配空间大小
read -p "Enter the volume size: " volume_size

# 打印用户输入的值
echo "StatefulSet name: $statefulset_name"
echo "Number of replicas: $replicas"
echo "Volume size: $volume_size"

# 拷贝sts_template.yml文件
new_file_name="sts_$statefulset_name.yml"

# 拷贝sts_template.yml文件
cp -f ../template/sts_changeos_template.yml $new_file_name

# 使用sed命令修改文件内容
sed -i "s/module-name-/$statefulset_name-/g" $new_file_name
sed -i "s/num_XXX/$replicas/g" $new_file_name
sed -i "s/storage_XXX/$volume_size/g" $new_file_name
lowercase_volume_size=$(echo "$volume_size" | tr '[:upper:]' '[:lower:]')
sed -i "s/XXX-pvc/$lowercase_volume_size-pvc/g" $new_file_name

echo "File $new_file_name has been modified."

# 判断是否要创建statefulset
read -p "Do you want to create the StatefulSet? (y/n): " create
if [ "$create" == "y" ]; then
    kubectl apply -f $new_file_name
    # 初始化ready变量为0
    ready="0/$replicas"

    # 使用while循环定期检查StatefulSet的状态
    while [ "$ready" != "$replicas/$replicas" ]; do
        # 使用kubectl get statefulsets命令获取StatefulSet的状态
        output=$(kubectl get statefulsets $statefulset_name-pv-sts)

        # 使用grep和awk命令解析输出，获取READY列的值
        ready=$(echo "$output" | grep $statefulset_name-pv-sts | awk '{print $2}')

        # 如果StatefulSet还没有运行成功，等待5秒然后再次检查
        if [ "$ready" != "$replicas/$replicas" ]; then
            echo "Waiting for $statefulset_name to be ready..."
            sleep 3
        fi
    done
    echo "$statefulset_name is running successfully."
    echo "StatefulSet created successfully."

    sudo bash divide_images.sh $statefulset_name-$lowercase_volume_size-pvc
    mkdir -p ../check_output/
    sudo bash ./check_isdone.sh $statefulset_name-pv-sts $statefulset_name-$lowercase_volume_size-pvc >> ../check_output/$statefulset_name-pv-sts.txt &
else
    echo "StatefulSet not created."
fi

echo "$(kubectl get sts)"
echo "$(kubectl get pvc)"



