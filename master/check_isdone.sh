#!/bin/bash

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
        kubectl scale sts $1 --replicas=0
        break
    else
        echo "Inference not completed, checking again in 5 seconds"
        sleep 5
    fi
done