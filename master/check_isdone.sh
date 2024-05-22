#!/bin/bash
out_file="home/nvidia/Desktop/FileSend"
share_file="../nfs_share"  # Replace this with your actual path
while true; do
    all_done=true

    # 循环遍历 $share_file 下的所有子目录
    for dir in "$share_file"/*; do
        if [ -d "$dir" ]&& [[ $(basename "$dir") == *"$2"* ]]; then  # 如果是目录
            if [ ! -f "$dir/done" ]; then  # 如果 "done" 文件不存在
                all_done=false
                break
            fi
        fi
    done

    if $all_done; then
        echo "Inference completed"
        for dir in "$share_file"/*; do
            # 检查 /output 文件夹是否存在
            if [ -d "${dir}/output" ]; then
                # 将 /output 文件夹中的所有 .png 文件拷贝到 $out_file 中
                cp "${dir}/output"/*.png "$out_file"
            fi
        done
        kubectl scale sts $1 --replicas=0
        break
    else
        echo "Inference not completed, checking again in 5 seconds"
        sleep 5
    fi
done

