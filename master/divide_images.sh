#!/bin/bash

echo "Starting script..."

# 获取所有.png文件的列表
echo "Getting list of .png files..."
png_files=(../../changeOS/images/*.png)

# 获取所有目标目录的列表
echo "Getting list of target directories..."
target_dirs=($(ls -d ../nfs_share/*/ | grep "$1"))

# 清空所有目标目录中input和output文件夹中的所有文件
echo "Clearing all target directories..."
for target_dir in "${target_dirs[@]}"; do
    echo "Clearing directory $target_dir..."
    mkdir -p "${target_dir:?}"/input "${target_dir:?}"/output
    rm -rf "${target_dir:?}"/input/* "${target_dir:?}"/output/*
done

# 获取.png文件的数量和目标目录的数量
num_png_files=${#png_files[@]}
num_target_dirs=${#target_dirs[@]}
echo "num_target_dirs: $num_target_dirs"

# 计算每个目录应接收的文件数量
echo "Calculating number of files per directory..."
num_files_per_dir=$(( (num_png_files + num_target_dirs - 1) / num_target_dirs ))

# 分发文件
echo "Distributing files..."
for (( i=0; i<num_png_files; i++ )); do
    # 如果已经复制了50张图片，就停止复制
    if (( i >= 50 )); then
        echo "Copied 50 files, stopping..."
        break
    fi

    # 计算目标目录的索引
    target_dir_index=$(( i % num_target_dirs ))

    # 获取目标目录
    target_dir=${target_dirs[$target_dir_index]}

    # 获取.png文件
    png_file=${png_files[$i]}
    echo "Current .png file: $png_file"

    # 将.png文件复制到目标目录
    echo "Copying $png_file to $target_dir/input/..."
    cp "$png_file" "${target_dir}input/"
done

echo "Script finished."