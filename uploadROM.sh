#!/bin/bash
work_dir=$(pwd)
source $work_dir/functions.sh

os_type=$(cat $work_dir/bin/ddevice/os_type.txt 2>/dev/null | tr -d '\r\n')
base_rom_code=$(cat $work_dir/bin/ddevice/base_rom_code.txt 2>/dev/null | tr -d '\r\n')
androidVER=$(cat $work_dir/bin/ddevice/androidver.txt 2>/dev/null | tr -d '\r\n')
rom_os=$(cat $work_dir/bin/ddevice/rom_os.txt 2>/dev/null | tr -d '\r\n')
regionTYPE=$(cat $work_dir/bin/ddevice/device_type.txt 2>/dev/null | tr -d '\r\n')
baserom_type=$(cat $work_dir/bin/ddevice/romtype.txt 2>/dev/null | tr -d '\r\n')

# ƯU TIÊN LẤY CODENAME CHUẨN ĐÃ ĐƯỢC XỬ LÝ
device_f=$(cat $work_dir/bin/ddevice/device_f.txt 2>/dev/null | tr -d '\r\n')
if [[ -z "$device_f" || "$device_f" == "missi" ]]; then
    device_f=$(cat $work_dir/bin/ddevice/device_code.txt 2>/dev/null | tr -d '\r\n')
fi
device_code="$device_f"

if [[ $(git branch --show-current 2>/dev/null) == "beta" ]]; then
    polyxver="$(cat Version 2>/dev/null | tr -d '\r\n')"
    status="Development"
else
    polyxver="$(cat Version 2>/dev/null | tr -d '\r\n')"
    status="Official"
fi

# ========================================================
# LOGIC NHẬN DIỆN HỆ ĐIỀU HÀNH CHUẨN XÁC 100%
if [[ "$base_rom_code" == OS* ]]; then
    true_os="HyperOS"
else
    true_os="MIUI"
fi

os_type=$true_os
# ========================================================

target_out_dir="$work_dir/out/${os_type}_${device_f}_${base_rom_code}"
mkdir -p "$target_out_dir/images/"

repack "Compressing super.img"
if [ -f "$work_dir/build/baserom/images/super.img" ]; then
    zstd --rm $work_dir/build/baserom/images/super.img -o $work_dir/build/baserom/images/super.img.zst > /dev/null 2>&1
elif [ -f "$work_dir/build/baserom/super.img" ]; then
    zstd --rm $work_dir/build/baserom/super.img -o $work_dir/build/baserom/images/super.img.zst > /dev/null 2>&1
fi

repack "Generating flashing script"
# Gom file ảnh hệ thống theo từng kiểu ROM nguồn
if [[ ${baserom_type} == 'payload' ]]; then
    mv -f $work_dir/build/baserom/images/super.img.zst "$target_out_dir/" 2>/dev/null || true
    mv -f $work_dir/build/baserom/images/*.img "$target_out_dir/images/" 2>/dev/null || true
elif [[ ${baserom_type} == 'br' ]]; then
    mv -f $work_dir/build/baserom/firmware-update/* "$target_out_dir/images/" 2>/dev/null || true
    mv -f $work_dir/build/baserom/images/super.img.zst "$target_out_dir/" 2>/dev/null || true
else
    # Nhánh cho Xiaomi.eu hoặc các bản build trích xuất super.img
    mv -f $work_dir/build/baserom/images/super.img.zst "$target_out_dir/" 2>/dev/null || true
    # Chuyển toàn bộ các partition img đi kèm (boot, dtbo, vendor_boot, cust...)
    find $work_dir/build/baserom/ -maxdepth 2 -type f -name "*.img" -exec mv -f {} "$target_out_dir/images/" \; 2>/dev/null || true
fi

# Generate dynamic script flash
cp -rf $work_dir/bin/script2flash/META-INF "$target_out_dir/"
cp -rf $work_dir/bin/script2flash/*.bat "$target_out_dir/" 2>/dev/null || true
cp -rf $work_dir/bin/script2flash/*.sh "$target_out_dir/" 2>/dev/null || true
cp -rf $work_dir/bin/script2flash/cust.img "$target_out_dir/images/" 2>/dev/null || true

mkdir -p "$target_out_dir/META-INF/Data"
echo "$device_f" > "$target_out_dir/META-INF/Data/DeviceCode"
repack "Done"

# Định dạng tên file: BugOS_<codename>_<phiên bản os>_<ngày tháng năm>.zip
build_date=$(TZ=Asia/Ho_Chi_Minh date +%d%m%Y)
final_zip_name="BugOS_${device_code}_${base_rom_code}_${build_date}.zip"

find "$target_out_dir" | xargs touch
pushd "$target_out_dir/" || exit
zip -r "$work_dir/out/$final_zip_name" ./*
popd || exit

repack "Build completed"
repack "Output: $(pwd)/out/$final_zip_name"

output_file="out/$final_zip_name"
echo "$final_zip_name" > $work_dir/bin/ddevice/output_zip.txt
