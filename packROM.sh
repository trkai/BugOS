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

#Generate Super.img
superSize=$(bash $work_dir/bin/getSuperSize.sh $getvar)
repack $superSize
repack "Super image size: ${superSize}"
repack "Packing super.img"
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

# Pack super.img
if [[ "$is_ab_device" == false ]]; then
    repack "Packing super.img for A-only device"
    GROUP_SIZE=$((superSize - 134217728))
    lpargs="-F --output build/baserom/images/super.img --metadata-size 65536 --super-name super --metadata-slots 2 --block-size 4096 --device super:$superSize --group=qti_dynamic_partitions:$GROUP_SIZE"

    for pname in odm mi_ext system system_ext product vendor; do
        if [ -f "build/baserom/images/${pname}.img" ]; then
            if [[ "$OSTYPE" == "darwin"* ]]; then
                subsize=$(stat -f%z "build/baserom/images/${pname}.img")
            else
                subsize=$(du -sb "build/baserom/images/${pname}.img" | awk '{print $1}')
            fi
            repack "Super sub-partition [$pname] size: [$subsize]"
            lpargs="$lpargs --partition ${pname}:readonly:${subsize}:qti_dynamic_partitions --image ${pname}=build/baserom/images/${pname}.img"
        fi
    done

else
    repack "Packing super.img for V-AB device"

    GROUP_SIZE=$((superSize - 134217728))   # 128MB margin

    lpargs="-F --virtual-ab --output $IMG_DIR/super.img --metadata-size 65536 --super-name super --metadata-slots 3 --block-size 4096 --device super:$superSize --group=qti_dynamic_partitions_a:$GROUP_SIZE --group=qti_dynamic_partitions_b:$GROUP_SIZE"

    for pname in ${super_list}; do
        if [ -f "build/baserom/images/${pname}.img" ]; then
            subsize=$(du -sb "build/baserom/images/${pname}.img" | awk '{print $1}')
            repack "Super sub-partition [$pname] size: [$subsize]"
            lpargs="$lpargs --partition ${pname}_a:readonly:${subsize}:qti_dynamic_partitions_a --image ${pname}_a=build/baserom/images/${pname}.img --partition ${pname}_b:readonly:0:qti_dynamic_partitions_b"
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
