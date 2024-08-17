# #!/bin/bash

# echo "Starting script..."

# # 获取所有.png文件的列表
# echo "Getting list of .png files..."
# # TODO: 修改为实际路径
# png_files=(/home/nvidia/datasets/ChangeOSdata/*.png)

# # 获取所有目标目录的列表
# echo "Getting list of target directories..."
# target_dirs=($(ls -d ../nfs_share/*/ | grep "$1"))

# # 清空所有目标目录中input和output文件夹中的所有文件
# echo "Clearing all target directories..."
# for target_dir in "${target_dirs[@]}"; do
#     echo "Clearing directory $target_dir..."
#     mkdir -p "${target_dir:?}"/input "${target_dir:?}"/output
#     rm -rf "${target_dir:?}"/input/* "${target_dir:?}"/output/*
# done

# # 获取.png文件的数量和目标目录的数量
# num_png_files=${#png_files[@]}
# num_target_dirs=${#target_dirs[@]}
# echo "num_target_dirs: $num_target_dirs"

# # 计算每个目录应接收的文件数量
# echo "Calculating number of files per directory..."

# # 分发文件
# echo "Distributing files..."
# for (( i=0; i<num_png_files/2; i+=1 )); do
#     # 如果已经复制了50张图片，就停止复制
#     # if (( i >= 50 )); then
#     #     echo "Copied 50 files, stopping..."
#     #     break
#     # fi

#     # 计算目标目录的索引
#     target_dir_index=$(( i % num_target_dirs ))

#     # 获取目标目录
#     target_dir=${target_dirs[$target_dir_index]}

#     # 获取.png文件
#     png_file1=${png_files[$i]}
#     png_file2=${png_file1/post/pre}
#     echo "Current .png files: $png_file1, $png_file2"

#     # 将.png文件复制到目标目录
#     echo "Copying $png_file1 and $png_file2 to $target_dir/input/..."
#     cp "$png_file1" "${target_dir}input/"
#     if (( i+1 < num_png_files )); then
#         cp "$png_file2" "${target_dir}input/"
#     fi
# done

# echo "Script finished."

#!/bin/bash

# 定义目标目录数组
echo "Getting list of target directories..."
target_dirs=($(ls -d ../nfs_share/*/ | grep "$1"))

# 定义备份目录
backup_dir="/home/nvidia/datasets/ChangeOSdata"

# 创建备份目录
mkdir -p "$backup_dir"

# 获取目标目录的数量
num_target_dirs=${#target_dirs[@]}
echo "num_target_dirs: $num_target_dirs"

# 无限循环
while true; do
    # 获取当前目录下的所有以post和pre开头的.png文件
    post_files=($(ls /home/nvidia/datasets/ChangeOSdata/post*.png 2>/dev/null))
    pre_files=($(ls /home/nvidia/datasets/ChangeOSdata/pre*.png 2>/dev/null))

    # 创建一个关联数组来存储成对的文件
    declare -A file_pairs

    # 将post文件添加到关联数组中
    for post_file in "${post_files[@]}"; do
        base_name=$(basename "$post_file" | sed 's/^post//')
        file_pairs["$base_name,post"]="$post_file"
    done

    # 将pre文件添加到关联数组中
    for pre_file in "${pre_files[@]}"; do
        base_name=$(basename "$pre_file" | sed 's/^pre//')
        file_pairs["$base_name,pre"]="$pre_file"
    done
    # 分发文件
    echo "Distributing files..."
    index=0
    for base_name in "${!file_pairs[@]}"; do
        # 检查是否有成对的post和pre文件
        if [[ -n "${file_pairs[$base_name,post]}" && -n "${file_pairs[$base_name,pre]}" ]]; then
            # 计算目标目录的索引
            target_dir_index=$(( index % num_target_dirs ))

            # 获取目标目录
            target_dir=${target_dirs[$target_dir_index]}

            # 获取post和pre文件
            post_file=${file_pairs[$base_name,post]}
            pre_file=${file_pairs[$base_name,pre]}
            echo "Current files: $post_file, $pre_file"

            # 将文件复制到目标目录
            echo "Copying $post_file and $pre_file to $target_dir/input/..."
            cp "$post_file" "${target_dir}/input/"
            cp "$pre_file" "${target_dir}/input/"

            # 将文件移动到备份目录
            echo "Moving $post_file and $pre_file to $backup_dir/..."
            mv "$post_file" "$backup_dir/"
            mv "$pre_file" "$backup_dir/"

            # 增加索引
            index=$((index + 1))
        fi
    done

    echo "Waiting for new files..."
    sleep 5 # 每10秒检查一次文件夹
done

echo "Script finished."