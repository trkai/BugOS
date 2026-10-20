work_dir=$(pwd)
source $work_dir/functions.sh
tools_dir=${work_dir}/bin/$(uname)/$(uname -m)
export PATH=$(pwd)/bin/$(uname)/$(uname -m)/:$PATH

super_list="vendor mi_ext odm odm_dlkm system system_dlkm vendor_dlkm product product_dlkm system_ext"
os_type=$(cat $work_dir/bin/ddevice/os_type.txt)
base_rom_code=$(cat $work_dir/bin/ddevice/base_rom_code.txt)
androidVER=$(cat $work_dir/bin/ddevice/androidver.txt)
rom_os=$(cat $work_dir/bin/ddevice/rom_os.txt)
regionTYPE=$(cat $work_dir/bin/ddevice/device_type.txt)
device_code=$(cat $work_dir/bin/ddevice/device_f.txt)
getvar=$(cat $work_dir/bin/ddevice/device_f.txt)
# Chuẩn hoá về chữ hoa để so sánh EXT / EROFS không bị lệch
PACK_TYPE=$(cat $work_dir/bin/ddevice/fstype.txt 2>/dev/null | tr -d '\r\n ' | tr '[:lower:]' '[:upper:]')
[ -z "$PACK_TYPE" ] && PACK_TYPE="EROFS"

if [[ $(git branch --show-current) == "beta" ]]; then
    polyxver="$(cat Version)"
    status="Development"
else
    polyxver="$(cat Version)"
    status="Official"
fi

if [[ $rom_os == "MIUI" ]]; then
    os_type="MIUI"
else
    os_type="HyperOS"
fi

# ==================== KIỂM TRA ĐẦU VÀO ====================
IMG_DIR="$work_dir/build/baserom/images"
echo "===== Nội dung $IMG_DIR ====="
ls -la "$IMG_DIR" 2>&1 | head -60

if [ ! -d "$IMG_DIR" ]; then
    error "Không tìm thấy $IMG_DIR - bước build.sh chưa chạy hoặc đã lỗi trước đó."
    exit 1
fi

found_any=false
for pname in ${super_list}; do
    if [ -d "$IMG_DIR/$pname" ]; then
        found_any=true
        break
    fi
done
if [[ "$found_any" == false ]]; then
    error "Không có thư mục partition nào (vendor/system/product...) trong $IMG_DIR. Kiểm tra bước unpack trong build.sh."
    exit 1
fi
# ===========================================================

# Xác định thiết bị A/B TRƯỚC khi đóng gói (vì sau này có thể bị thay đổi)
is_ab_device=false
if [ -f "$IMG_DIR/vendor/build.prop" ] && grep -q "ro.build.ab_update=true" "$IMG_DIR/vendor/build.prop"; then
    is_ab_device=true
elif [ "$(cat $work_dir/bin/ddevice/romtype.txt 2>/dev/null)" = "payload" ]; then
    # ROM payload.bin luôn là thiết bị A/B
    is_ab_device=true
fi
repack "A/B device: $is_ab_device"

repack "Packing partitions to .img"
for pname in ${super_list}; do
    if [ -d "$IMG_DIR/$pname" ]; then
        thisSize=$(du -sb $IMG_DIR/${pname} | awk '{print $1}')
        if [[ $androidVER == "12" ]]; then
           case $pname in
             odm) addSize=104217728 ;;
             system) addSize=114217728 ;;
             vendor) addSize=104217728 ;;
             system_ext) addSize=104217728 ;;
             product) addSize=104217728 ;;
             *) addSize=8054432 ;;
           esac
        else
           case $pname in
             mi_ext) addSize=16777216 ;;
             odm) addSize=16777216 ;;
             system) addSize=16777216 ;;
             vendor) addSize=16777216 ;;
             system_ext) addSize=16777216 ;;
             product) addSize=16777216 ;;
             *) addSize=8054432 ;;
           esac
        fi

        thisSize=$(echo "$thisSize + $addSize" | bc)
        if [[ "$PACK_TYPE" == "EXT" ]]; then
            python3 $work_dir/bin/fspatch.py $IMG_DIR/${pname} $IMG_DIR/config/${pname}_fs_config >/dev/null 2>&1
            python3 $work_dir/bin/contextpatch.py $IMG_DIR/${pname} $IMG_DIR/config/${pname}_file_contexts >/dev/null 2>&1
            make_ext4fs -J -T $(date +%s) -S $IMG_DIR/config/${pname}_file_contexts -l $thisSize -C $IMG_DIR/config/${pname}_fs_config -L ${pname} -a ${pname} $IMG_DIR/${pname}.img $IMG_DIR/${pname} >/dev/null 2>&1
            if [ -f "$IMG_DIR/${pname}.img" ]; then
                repack "Packing [${pname}.img] success"
            else
                repack "Packing [${pname}] failed!"
            fi
        elif [[ "$PACK_TYPE" == "EROFS" ]]; then
            python3 $work_dir/bin/fspatch.py $IMG_DIR/${pname} $IMG_DIR/config/${pname}_fs_config >/dev/null 2>&1
            python3 $work_dir/bin/contextpatch.py $IMG_DIR/${pname} $IMG_DIR/config/${pname}_file_contexts >/dev/null 2>&1
            mkfs.erofs --quiet -zlz4hc,9 --mount-point ${pname} --fs-config-file=$IMG_DIR/config/${pname}_fs_config --file-contexts=$IMG_DIR/config/${pname}_file_contexts $IMG_DIR/${pname}.img $IMG_DIR/${pname} >/dev/null 2>&1
            if [ -f "$IMG_DIR/${pname}.img" ]; then
                repack "Packing [${pname}.img] success"
            else
                repack "Packing [${pname}] failed!"
            fi
        else
            error "Unable to handle img (PACK_TYPE=$PACK_TYPE), exit."
            exit 1
        fi
    fi
done

# Chốt chặn: phải có ít nhất 1 file .img mới đóng super
if ! ls $IMG_DIR/*.img >/dev/null 2>&1; then
    error "Không có partition .img nào để đóng vào super. Kiểm tra fstype/mkfs.erofs và thư mục config."
    exit 1
fi

# ==================== TÍNH TOÁN DUNG LƯỢNG VÀ ĐÓNG GÓI SUPER.IMG ====================
repack "Đang tự động tính toán dung lượng các phân vùng con..."
total_subsize=0
stock_total=$(cat "$work_dir/bin/ddevice/stock_partitions_total.txt" 2>/dev/null || echo 0)

repack "----------------- BẢNG DUNG LƯỢNG PHÂN VÙNG -----------------"
for pname in ${super_list}; do
    img_path="$IMG_DIR/${pname}.img"
    if [ -f "$img_path" ]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            subsize=$(stat -f%z "$img_path")
        else
            subsize=$(du -sb "$img_path" | awk '{print $1}')
        fi
        orig_p=$(cat "$work_dir/bin/ddevice/orig_size_${pname}.txt" 2>/dev/null || echo 0)
        orig_mb=$((orig_p / 1024 / 1024))
        new_mb=$((subsize / 1024 / 1024))
        diff_mb=$((new_mb - orig_mb))
        if [ "$orig_p" -gt 0 ]; then
            repack "  -> [$pname]: $new_mb MB (Gốc: $orig_mb MB | Chênh lệch: ${diff_mb} MB)"
        else
            repack "  -> [$pname]: $new_mb MB"
        fi
        total_subsize=$((total_subsize + subsize))
    fi
done
repack "------------------------------------------------------------"
repack "Tổng dung lượng các phân vùng cần đóng gói: $total_subsize bytes ($((total_subsize / 1024 / 1024)) MB)"
if [ "$stock_total" -gt 0 ]; then
    repack "Tổng dung lượng gốc tương ứng từ ROM nguồn: $stock_total bytes ($((stock_total / 1024 / 1024)) MB)"
fi

# Tính toán dung lượng tối thiểu bắt buộc
# Cần buffer 32MB cho alignment và các block phụ
min_group_size=$((total_subsize + 33554432))
# Làm tròn lên bội số của 4MB (4194304 bytes) theo sector block của lpmake
min_group_size=$(( ((min_group_size + 4194303) / 4194304) * 4194304 ))

# Kích thước super.img tối thiểu = GROUP_SIZE + 128MB (LpMetadata, headers, slot tables)
min_super_size=$((min_group_size + 134217728))
min_super_size=$(( ((min_super_size + 4194303) / 4194304) * 4194304 ))

# Xác định superSize theo thứ tự ưu tiên
superSize=""
# 1. Từ file super.img gốc nếu có
if [ -s "$work_dir/bin/ddevice/superSize.txt" ]; then
    superSize=$(cat "$work_dir/bin/ddevice/superSize.txt" | tr -d '\r\n ')
    repack "Đọc superSize từ ROM gốc: $superSize bytes"
fi

# 2. Hoặc từ tổng các phân vùng gốc + 128MB margin
if [ -z "$superSize" ] || [ "$superSize" -le 0 ] 2>/dev/null; then
    if [ "$stock_total" -gt 0 ]; then
        stock_super_est=$((stock_total + 134217728))
        stock_super_est=$(( ((stock_super_est + 4194303) / 4194304) * 4194304 ))
        superSize=$stock_super_est
        repack "Ước tính superSize từ phân vùng gốc: $superSize bytes"
    fi
fi

# 3. Hoặc tra cứu theo database thiết bị
if [ -z "$superSize" ] || [ "$superSize" -le 0 ] 2>/dev/null; then
    superSize=$(bash $work_dir/bin/getSuperSize.sh $getvar)
    repack "Lấy superSize từ database thiết bị: $superSize bytes"
fi

# 4. Fallback an toàn
if [ -z "$superSize" ] || [ "$superSize" -le 0 ] 2>/dev/null; then
    superSize=10021466112
fi

# CHỐT CHẶN AN TOÀN: Đảm bảo superSize và GROUP_SIZE luôn đủ chỗ cho các phân vùng
if [ "$superSize" -lt "$min_super_size" ]; then
    repack "CẢNH BÁO: superSize ($superSize) nhỏ hơn dung lượng yêu cầu ($min_super_size)!"
    repack "Tự động mở rộng superSize lên $min_super_size (GROUP_SIZE: $min_group_size) để đảm bảo không lỗi..."
    superSize=$min_super_size
    GROUP_SIZE=$min_group_size
else
    GROUP_SIZE=$((superSize - 134217728))
    if [ "$GROUP_SIZE" -lt "$min_group_size" ]; then
        GROUP_SIZE=$min_group_size
        superSize=$((GROUP_SIZE + 134217728))
    fi
fi

free_in_group=$((GROUP_SIZE - total_subsize))
repack "================= THÔNG SỐ ĐÓNG GÓI CUỐI CÙNG ================="
repack "  -> Kích thước Super.img : ${superSize} bytes ($((superSize / 1024 / 1024)) MB)"
repack "  -> Kích thước Group lpmake: ${GROUP_SIZE} bytes ($((GROUP_SIZE / 1024 / 1024)) MB)"
repack "  -> Dung lượng trống dự phòng: ${free_in_group} bytes ($((free_in_group / 1024 / 1024)) MB)"
repack "================================================================"

super_human="$((superSize / 1024 / 1024)) MB"
echo "$super_human" > "$work_dir/bin/ddevice/super_size_human.txt"

# Pack super.img
if [[ "$is_ab_device" == false ]]; then
    repack "Packing super.img for A-only device"
    lpargs="-F --output $IMG_DIR/super.img --metadata-size 65536 --super-name super --metadata-slots 2 --block-size 4096 --device super:$superSize --group=qti_dynamic_partitions:$GROUP_SIZE"

    for pname in odm mi_ext system system_ext product vendor; do
        img_path="$IMG_DIR/${pname}.img"
        if [ -f "$img_path" ]; then
            if [[ "$OSTYPE" == "darwin"* ]]; then
                subsize=$(stat -f%z "$img_path")
            else
                subsize=$(du -sb "$img_path" | awk '{print $1}')
            fi
            lpargs="$lpargs --partition ${pname}:readonly:${subsize}:qti_dynamic_partitions --image ${pname}=$img_path"
        fi
    done

else
    repack "Packing super.img for V-AB device"
    lpargs="-F --virtual-ab --output $IMG_DIR/super.img --metadata-size 65536 --super-name super --metadata-slots 3 --block-size 4096 --device super:$superSize --group=qti_dynamic_partitions_a:$GROUP_SIZE --group=qti_dynamic_partitions_b:$GROUP_SIZE"

    for pname in ${super_list}; do
        img_path="$IMG_DIR/${pname}.img"
        if [ -f "$img_path" ]; then
            if [[ "$OSTYPE" == "darwin"* ]]; then
                subsize=$(stat -f%z "$img_path")
            else
                subsize=$(du -sb "$img_path" | awk '{print $1}')
            fi
            lpargs="$lpargs --partition ${pname}_a:readonly:${subsize}:qti_dynamic_partitions_a --image ${pname}_a=$img_path --partition ${pname}_b:readonly:0:qti_dynamic_partitions_b"
        fi
    done
fi

# Run lpmake
lpmake $lpargs

if [ -f "$IMG_DIR/super.img" ]; then
    repack "Successfully packed super.img."
else
    repack "Unable to pack super.img."
    exit 1
fi

for pname in ${super_list}; do
    rm -rf "$IMG_DIR/${pname}.img" 2>/dev/null
done

find "$work_dir/build" -exec touch -t 200901010000.00 {} + 2> /dev/null || true
