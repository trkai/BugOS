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
device_f=$(cat $work_dir/bin/ddevice/device_f.txt 2>/dev/null | tr -d '\r\n ' | tr '[:upper:]' '[:lower:]')
if is_dummy_codename "$device_f"; then
    device_f=$(cat $work_dir/bin/ddevice/device_code.txt 2>/dev/null | tr -d '\r\n ' | tr '[:upper:]' '[:lower:]')
fi
if is_dummy_codename "$device_f"; then
    device_f="device"
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

# Tạo tệp changelog.txt trong gói ROM zip
if [ -f "$work_dir/bin/ddevice/changelog.txt" ] && [ -s "$work_dir/bin/ddevice/changelog.txt" ]; then
    cp -f "$work_dir/bin/ddevice/changelog.txt" "$target_out_dir/changelog.txt"
else
    cat << EOF > "$target_out_dir/changelog.txt"
==================================================
              BugOS 1.1 Changelog
==================================================
Thiết bị: ${device_code}
Phiên bản: ${base_rom_code}
Ngày đóng gói: ${build_date}

1. Giao diện & Hiển thị:
   - Việt hóa toàn diện HyperOS (58 gói Tory RRO Overlays).
   - Bộ font MiSans Latin VF chuẩn hóa tiếng Việt đầy đủ ký tự.
   - Kích hoạt Gaussian Blur thời gian thực & Advanced Textures.
   - Gỡ bỏ hạn chế phần cứng máy yếu (Xiaomi_NoLowEnd).
   - Xóa bỏ độ trễ khi nhấn giữ nút nguồn (Fix Delay Power Menu).

2. Cuộc gọi & Ứng dụng:
   - Tích hợp Mi Dialer tự động ghi âm 2 chiều không phát âm thanh cảnh báo.
   - Mở khóa Theme Manager cho phép nạp theme bên thứ ba tự do (.mtz).
   - Gỡ bỏ đếm ngược cảnh báo rủi ro của Package Installer.

3. Hệ thống & Tối ưu:
   - Tích hợp CorePatch (hạ cấp và cài đè ứng dụng khác chữ ký).
   - Vô hiệu hóa xác minh Android Verified Boot (Disable AVB) chống bootloop.
   - Khắc phục triệt để lỗi chậm / trễ thông báo ứng dụng (Notification Fix).
   - Mở khóa tần số quét màn hình (hỗ trợ 1Hz LTPO và tần số cao).
   - Dọn sạch ứng dụng rác và tiến trình theo dõi ngầm (Debloated).
==================================================
EOF
fi

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

if [ -f "$work_dir/out/$final_zip_name" ]; then
    final_bytes=$(stat -c%s "$work_dir/out/$final_zip_name" 2>/dev/null || du -sb "$work_dir/out/$final_zip_name" | awk '{print $1}')
    final_mb=$((final_bytes / 1024 / 1024))
    echo "${final_mb} MB" > "$work_dir/bin/ddevice/rom_size.txt"
    repack "Kích thước tệp ROM hoàn chỉnh: ${final_mb} MB ($final_bytes bytes)"

    # Giải phóng thư mục staging ngay để máy chủ không bị đầy ổ đĩa trước khi upload
    rm -rf "$target_out_dir" 2>/dev/null || true
    repack "Đã dọn dẹp thư mục staging để tối ưu bộ nhớ đĩa."
fi
