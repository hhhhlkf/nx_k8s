# !/bin/bash
data_file="./images/input"▒
if ! which inotifywait > /dev/null; then
    echo "inotify-tools is not installed, installing..."
    sudo apt-get install -y inotify-tools
else
    echo "inotify-tools is already installed, skipping..."
fi

while [ $(ls $data_file | wc -l) -eq 0 ]; do
    echo "No file detected, continue monitoring..."
    sleep 1
done

while inotifywait -t 5 $data_file; do
    echo "New file detected, continue monitoring..."
done

echo "No new file in the last second, exiting..."

python3 ./eval.py
