#!/bin/bash

# 查找并终止 divide_images.sh 进程
divide_images_pids=$(pgrep -f divide_images.sh)
if [ -n "$divide_images_pids" ]; then
    echo "Stopping divide_images.sh processes: $divide_images_pids"
    kill $divide_images_pids
else
    echo "No divide_images.sh processes found."
fi

# 查找并终止 check_isdone.sh 进程
check_isdone_pids=$(pgrep -f check_isdone.sh)
if [ -n "$check_isdone_pids" ]; then
    echo "Stopping check_isdone.sh processes: $check_isdone_pids"
    kill $check_isdone_pids
else
    echo "No check_isdone.sh processes found."
fi

echo "Script finished."