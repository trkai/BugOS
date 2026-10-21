#!/bin/bash
work_dir=$(pwd)
source "$work_dir/functions.sh" 2>/dev/null || true

KEY="${1:-$(cat "$work_dir/bin/ddevice/device_f.txt" 2>/dev/null)}"
if is_dummy_codename "$KEY"; then
    KEY=$(cat "$work_dir/bin/ddevice/device_code.txt" 2>/dev/null)
fi
KEY=$(echo "$KEY" | tr -d '\r\n ' | tr '[:upper:]' '[:lower:]')
region=$(cat "$work_dir/bin/ddevice/device_type.txt" 2>/dev/null | tr -d '\r\n ')

PYTHON_CMD="python3"
which python3 >/dev/null 2>&1 && python3 --version >/dev/null 2>&1 || PYTHON_CMD="python"

VALUE=$($PYTHON_CMD "$work_dir/bin/ddevice/get_device_name.py" "$KEY" "$region" "$work_dir" 2>/dev/null | tr -d '\r\n')
[ -z "$VALUE" ] && VALUE="Xiaomi Device"

# Đồng bộ ghi ra CẢ HAI file để tránh lệch dữ liệu giữa các script
mkdir -p "$work_dir/bin/ddevice"
echo "$VALUE" > "$work_dir/bin/ddevice/name_devices.txt"
echo "$VALUE" > "$work_dir/bin/ddevice/device_name.txt"
