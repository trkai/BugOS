#!/bin/bash
work_dir=$(pwd)
source $work_dir/functions.sh

FILE_JSON="$work_dir/bin/ddevice/data/devices.json"
KEY="${1:-$(cat $work_dir/bin/ddevice/device_f.txt 2>/dev/null)}"
KEY=$(echo "$KEY" | tr -d '\r\n ' | tr '[:upper:]' '[:lower:]')

# Tìm key chuẩn theo danh sách thiết bị
EXACT_KEY=$(grep -ix "$KEY" "$work_dir/bin/ddevice/data/devices_data.txt" 2>/dev/null | head -n 1)
[ -z "$EXACT_KEY" ] && EXACT_KEY=$(grep -ix "$KEY" "$work_dir/bin/ddevice/data/pad_data.txt" 2>/dev/null | head -n 1)

if [ -z "$EXACT_KEY" ]; then
  EXACT_KEY="$KEY"
fi

VALUE=""
if [ -f "$FILE_JSON" ] && [ -n "$EXACT_KEY" ]; then
  VALUE=$(jq -r --arg key "$EXACT_KEY" '.[$key] // empty' "$FILE_JSON" 2>/dev/null)
fi

# Nếu kết quả có nhiều tên ngăn cách bằng |, lấy tên đầu tiên gọn nhất
if [[ "$VALUE" == *"|"* ]]; then
  VALUE=$(echo "$VALUE" | cut -d'|' -f1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
fi

# Fallback: nếu không có trong JSON, đọc trực tiếp từ build.prop gốc
if [ -z "$VALUE" ] || [ "$VALUE" = "null" ]; then
  for prop in \
    "$work_dir/build/baserom/images/product/etc/build.prop" \
    "$work_dir/build/baserom/images/system/system/build.prop" \
    "$work_dir/build/baserom/images/vendor/build.prop" \
    "$work_dir/build/baserom/images/odm/etc/build.prop"; do
    if [ -f "$prop" ]; then
      prop_val=$(grep -E "^(ro\.product\.marketname|ro\.product\.product\.marketname|ro\.product\.model)=" "$prop" 2>/dev/null | head -n 1 | cut -d'=' -f2 | tr -d '\r\n')
      if [ -n "$prop_val" ] && [ "$prop_val" != "Xiaomi Device" ]; then
        VALUE="$prop_val"
        break
      fi
    fi
  done
fi

[ -z "$VALUE" ] && VALUE="Xiaomi Device"

# Đồng bộ ghi ra CẢ HAI file để tránh lệch dữ liệu giữa các script
mkdir -p "$work_dir/bin/ddevice"
echo "$VALUE" > "$work_dir/bin/ddevice/name_devices.txt"
echo "$VALUE" > "$work_dir/bin/ddevice/device_name.txt"
