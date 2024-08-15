#!/bin/bash
out_file="/home/nvidia/Desktop/FileSend"
share_file="../nfs_share" # 替换为实际路径

start_time=$(date +%s)

while true; do
    all_done=true

    # 循环遍历 $share_file 下的所有子目录
    for dir in "$share_file"/*; do
        if [ -d "$dir" ] && [[ $(basename "$dir") == *"$2"* ]]; then # 如果是目录
            if [ -d "${dir}/output" ]; then                          # 检查 /output 文件夹是否存在
                # 检查 /output 文件夹中是否有 .png 文件
                if [ "$(ls -A "${dir}/output"/*.png 2>/dev/null)" ]; then
                    # 将 /output 文件夹中的所有 .png 文件拷贝到 $out_file 中，并保持原有的文件名
                    for file in "${dir}/output"/*.png; do
                        cp "$file" "$out_file/"
                    done
                else
                    all_done=false
                    break
                fi
            else
                all_done=false
                break
            fi
        fi
    done

    echo "$(date) - checking again in 2 seconds"
    sleep 2

done
