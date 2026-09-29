#!/bin/bash
# BugOS - NOTIFICATION_FIX (A16)
# Credit: hướng dẫn gốc của @MMETMAmods
# Chạy từ thư mục gốc của repo (work_dir=$(pwd)), sau khi đã có build/baserom/images

work_dir=$(pwd)
MAIN_FOLDER="$work_dir/build/baserom/images/"
NF="$work_dir/bin/package/NOTIFICATION_FIX/A16"

for s in PowerKeeper.sh patchMIUIServices.sh; do
    if [[ -f "$NF/$s" ]]; then
        bash "$NF/$s" || echo "[NOTIFICATION_FIX] $s kết thúc với lỗi (bỏ qua, build tiếp tục)"
    else
        echo "[NOTIFICATION_FIX] Không thấy $NF/$s, bỏ qua"
    fi
done