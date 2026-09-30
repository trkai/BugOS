Baserom="$1"
repo_name="$2"
prefix_id="$3"
builder_name="$4"
builder_id="$5"
work_dir=$(pwd)

# Import functions
tools_dir=${work_dir}/bin/$(uname)/$(uname -m)
export PATH=$(pwd)/bin/$(uname)/$(uname -m)/:$PATH
chmod 777 ${work_dir}/bin/*
chmod 777 ${work_dir}/bin/Linux/x86_64/*
source $work_dir/functions.sh

if [[ $(git branch --show-current) == "beta" ]]; then
    polyxver="$(cat Version)"
	status="Development"
else
    polyxver="$(cat Version)"
	status="Official"
fi

# Fix lỗi cấu hình gói apt/dpkg và cài đặt các phụ thuộc cần thiết
sudo dpkg --configure -a 2>/dev/null || true
sudo apt-get update -y
sudo apt-get install -y xmlstarlet aapt libc++1 libc++abi1 libsparse-tools

check unzip aria2c 7z zip java zipalign python3 zstd bc xmlstarlet aapt

# Dọn dẹp môi trường trước khi build
rm -rf $work_dir/out
rm -rf $work_dir/build
mkdir -p $work_dir/out

python3 $work_dir/notify.py download "$repo_name" "$baserom" "$prefix_id" "$builder_name" "$builder_id"
source "$work_dir/bin/ddevice/getROM.sh" "$baserom"

# ==================== CHUẨN HÓA TÊN FILE ZIP ====================
if [[ ! -f "$baserom" ]]; then
    found_zip=$(ls -S $work_dir/*.zip 2>/dev/null | head -n 1)
    if [[ -n "$found_zip" && -f "$found_zip" ]]; then
        baserom="$found_zip"
    else
        clean_name=$(basename "${baserom%%\?*}")
        if [[ -f "$work_dir/$clean_name" ]]; then
            baserom="$work_dir/$clean_name"
        elif [[ -f "$clean_name" ]]; then
            baserom="$clean_name"
        fi
    fi
fi
# ================================================================

python3 $work_dir/notify.py unpack "$repo_name" "$baserom" "$prefix_id" "$builder_name" "$builder_id"
if unzip -l "${baserom}" | grep -q "payload.bin"; then
    baserom_type="payload"
    echo $baserom_type > $work_dir/bin/ddevice/romtype.txt
    unpack "Found payload.bin file"
    super_list="vendor mi_ext odm odm_dlkm system system_dlkm vendor_dlkm product product_dlkm system_ext"
    unpack "ROM validation passed."
elif unzip -l "${baserom}" | grep -q "br$"; then
    baserom_type="br"
    echo $baserom_type > $work_dir/bin/ddevice/romtype.txt
    super_list="system vendor product odm system_ext mi_ext"
    unpack "Found broli file"
    unpack "ROM validation passed."
elif unzip -l "${baserom}" | grep -q "super.img.*"; then
    unpack "Found super.img.* files"
    is_base_rom_eu=true
    unpack "ROM validation passed."
else
    error "Unpack failed"
    exit 1
fi

rm -rf app tmp config build/baserom/
find . -type d -name 'miui_*' | xargs rm -rf

unpack "Files cleaned up."
mkdir -p build/baserom/images/

# Extract partitions
if [[ ${baserom_type} == 'payload' ]]; then
    unpack "Extracting files payload.bin..."
    unzip "${baserom}" payload.bin -d build/baserom >/dev/null 2>&1 || error "Extracting payload.bin error"
    unpack "File payload.bin extracted."
elif [[ ${baserom_type} == 'br' ]]; then
    unpack "Extracting files *.new.dat.br"
    unzip "${baserom}" -d build/baserom >/dev/null 2>&1 || error "Extracting new.dat.br error"
    unpack "File new.dat.br extracted."
elif [[ ${is_base_rom_eu} == true ]]; then
    unpack "Extracting files from BASETROM [super.img]"
    unzip -q "${baserom}" '*super.img*' -d build/baserom/ || error "Extracting [super.img] error"
    
    super_dir=$(dirname $(find build/baserom -name "*super.img.0*" | head -n 1))
    if [ -z "$super_dir" ]; then
        super_dir="build/baserom/images"
    fi

    unpack "Merging super.img.* into super.img"
    SUPER_FILES=$(ls -v ${super_dir}/*super.img.*)
    if [ -x "/usr/bin/simg2img" ]; then
    	/usr/bin/simg2img $SUPER_FILES build/baserom/super.img
    else
    	simg2img $SUPER_FILES build/baserom/super.img
    fi

    if [[ ! -s build/baserom/super.img ]]; then
        error "Ghép super.img thất bại! File rỗng hoặc không tồn tại."
        exit 1
    fi

    rm -rf ${super_dir}/*super.img.*
    unpack "[super.img] extracted."

    cust_file=$(find build/baserom -name "cust.img.0" | head -n 1)
    if [[ -n "$cust_file" ]]; then
        cust_dir=$(dirname "$cust_file")
        /usr/bin/simg2img ${cust_dir}/cust.img.* build/baserom/images/cust.img 2>/dev/null || true
        rm -rf ${cust_dir}/cust.img.*
    fi
fi

if [[ ${baserom_type} == 'payload' ]]; then
    unpack "Unpacking payload.bin"
    payload-extract extract -o build/baserom/images/ build/baserom/payload.bin >/dev/null 2>&1 || error "Unpacking payload.bin failed"    
elif [[ ${baserom_type} == 'br' ]]; then
    super_list=$(cat build/baserom/dynamic_partitions_op_list | grep "add " | awk '{ print $2 }')
    unpack "Unpacking new.dat.br"
    for brotlipart in ${super_list}; do 
        brotli -d build/baserom/$brotlipart.new.dat.br >/dev/null 2>&1
        python3 $work_dir/bin/Linux/x86_64/sdat2img.py build/baserom/$brotlipart.transfer.list build/baserom/$brotlipart.new.dat build/baserom/images/$brotlipart.img >/dev/null 2>&1
        rm -rf build/baserom/$brotlipart.new.dat* build/baserom/$brotlipart.transfer.list build/baserom/$brotlipart.patch.*
    done
elif [[ ${is_base_rom_eu} == true ]]; then
    unpack "Unpacking BASEROM [super.img]"
    python3 bin/lpunpack.py build/baserom/super.img build/baserom/images/ >/dev/null 2>&1
    
    for i in build/baserom/images/*_a.img; do
        if [ -f "$i" ]; then
            mv "$i" "${i%_a.img}.img"
        fi
    done
    
    super_list="system system_ext product vendor odm mi_ext"
fi

for part in ${super_list}; do
    if [ -f "$work_dir/build/baserom/images/${part}.img" ]; then
        extract_partition $work_dir/build/baserom/images/${part}.img $work_dir/build/baserom/images
        PACK_TYPE=$(cat $work_dir/bin/ddevice/fstype.txt 2>/dev/null || echo "erofs")
    fi
done

# ==================== FIX TÊN CODENAME THIẾT BỊ ====================
detected_codename=""

if [ -f "$work_dir/build/baserom/images/product/etc/build.prop" ]; then
    detected_codename=$(grep -m1 "^ro.product.product.device=" "$work_dir/build/baserom/images/product/etc/build.prop" | cut -d= -f2 | tr '[:upper:]' '[:lower:]')
elif [ -f "$work_dir/build/baserom/images/vendor/build.prop" ]; then
    detected_codename=$(grep -m1 "^ro.product.vendor.device=" "$work_dir/build/baserom/images/vendor/build.prop" | cut -d= -f2 | tr '[:upper:]' '[:lower:]')
fi

if [[ -z "$detected_codename" ]] || ! echo "$detected_codename" | grep -qE "^(peridot|onyx|garnet|corot|duchamp|manet|houji|shennong)$"; then
    detected_codename=$(echo "$baserom" | grep -o -i -E "(peridot|onyx|garnet|corot|duchamp|manet|houji|shennong)" | head -n 1 | tr '[:upper:]' '[:lower:]')
fi

if [ -n "$detected_codename" ]; then
    device_f="$detected_codename"
fi

echo "$device_f" > $work_dir/bin/ddevice/device_f.txt
getvar=$(cat $work_dir/bin/ddevice/device_f.txt)
# ===================================================================

rm -rf config
if [ -f "$baserom" ]; then rm -rf "$baserom"; fi
rm -rf build/baserom/payload.bin build/baserom/super.img

# Kỹ thuật ép tên: Làm sạch hậu tố NT/INT và ép về tên thương hiệu riêng
MY_BRAND_NAME="BugOS"
echo "$MY_BRAND_NAME" > $work_dir/bin/ddevice/os_type.txt
echo "$MY_BRAND_NAME" > $work_dir/bin/ddevice/brand.txt

if [ ! -s "$work_dir/bin/ddevice/device_name.txt" ]; then 
    echo "Xiaomi Device" > $work_dir/bin/ddevice/device_name.txt 
fi

mods "Gathering Devices Infomations"
bash $work_dir/bin/ddevice/getname.sh $getvar
bash $work_dir/bin/ddevice/fetchINFO.sh

python3 $work_dir/notify.py build "$repo_name" "$baserom" "$prefix_id" "$builder_name" "$builder_id"

bash $work_dir/bin/ddevice/DEBLOAT/debloat.sh
info "Done"

bash $work_dir/bin/modfile/OS1/insmod.sh
bash $work_dir/bin/modfile/OS2/insmod.sh
bash $work_dir/bin/modfile/OS3/insmod.sh
bash $work_dir/bin/modfile/Universal/insfile.sh
bash $work_dir/bin/modfile/UpdateFile/insupdate.sh
bash $work_dir/bin/package/patchpackage.sh

# ----> ĐIỀU KIỆN ÁP DỤNG ĐỊNH DANH VÀ BẢN QUYỀN <----
# Đọc ưu tiên theo thứ tự các file định danh máy thật
CURRENT_CODENAME="$(cat $work_dir/bin/ddevice/device_code.txt 2>/dev/null)"
[ -z "$CURRENT_CODENAME" ] && CURRENT_CODENAME="$(cat $work_dir/bin/ddevice/device_model.txt 2>/dev/null)"
[ -z "$CURRENT_CODENAME" ] && CURRENT_CODENAME="$(cat $work_dir/bin/ddevice/device_f.txt 2>/dev/null)"

if [ -z "$CURRENT_CODENAME" ] || [ "$CURRENT_CODENAME" = "missi" ]; then
    for prop in \
        "$work_dir/build/baserom/images/product/etc/build.prop" \
        "$work_dir/build/baserom/images/vendor/build.prop" \
        "$work_dir/build/baserom/images/system/system/build.prop"; do
        if [ -f "$prop" ]; then
            val=$(grep -E "^(ro\.product\.product\.device|ro\.product\.vendor\.device|ro\.product\.device)=" "$prop" | head -n 1 | cut -d'=' -f2 | tr -d '\r\n ')
            if [ -n "$val" ] && [ "$val" != "missi" ]; then
                CURRENT_CODENAME="$val"
                break
            fi
        fi
    done
fi

CURRENT_CODENAME="$(echo "$CURRENT_CODENAME" | tr -d ' ' | tr '[:upper:]' '[:lower:]')"

if [[ "$CURRENT_CODENAME" =~ (pudding|pandora|popsicle|nezha) ]]; then
    info "Thiết bị thuộc Xiaomi 17 Series ($CURRENT_CODENAME): Giữ nguyên toàn bộ HyperOS/MIUI và version prop gốc để tránh lỗi camera."
else
    # ----> ĐÓNG DẤU BẢN QUYỀN BugOS (FIX HIỂN THỊ CHỮ DƯỚI LOGO) <----
    info "Đang thiết lập hiển thị BugOS 1.1..."

    find "$work_dir/build/baserom/images/" -type f -name "*.prop" -exec sed -i 's/MIUINT/MIUI/g' {} +
    find "$work_dir/build/baserom/images/" -type f -name "*.prop" -exec sed -i 's/HyperNT/HyperOS/g' {} +

    ORIGINAL_INC=""
    if [ -f "$work_dir/bin/ddevice/base_rom_code.txt" ]; then
        ORIGINAL_INC="$(head -n 1 "$work_dir/bin/ddevice/base_rom_code.txt" | tr -d '\r\n ')"
    fi
    
    if [ -z "$ORIGINAL_INC" ]; then
        for prop in \
            "$work_dir/build/baserom/images/system/system/build.prop" \
            "$work_dir/build/baserom/images/product/etc/build.prop"; do
            if [ -f "$prop" ]; then
                ORIGINAL_INC=$(grep -E "^ro\.build\.version\.incremental=" "$prop" | head -n 1 | cut -d'=' -f2 | tr -d '\r\n ')
                [ -n "$ORIGINAL_INC" ] && break
            fi
        done
    fi
    
    [ -z "$ORIGINAL_INC" ] && ORIGINAL_INC="OS3.0"

    find "$work_dir/build/baserom/images/" -type f -name "*.prop" | while read -r f; do
        sed -i "s/^ro\.build\.display\.id=.*/ro.build.display.id=BugOS 1.1 | $ORIGINAL_INC/g" "$f"
        sed -i "s/^ro\.system\.build\.display\.id=.*/ro.system.build.display.id=BugOS 1.1 | $ORIGINAL_INC/g" "$f"
    done
fi

# ----> FIX HIỂN THỊ ĐÚNG TÊN MÁY (MARKET NAME) <----
info "Đang đồng bộ tên hiển thị của thiết bị (Market Name)..."

DEVICE_MARKET_NAME="$(cat $work_dir/bin/ddevice/device_name.txt 2>/dev/null)"
[ -z "$DEVICE_MARKET_NAME" ] && DEVICE_MARKET_NAME="Xiaomi Device"

find "$work_dir/build/baserom/images/" -type f -name "*.prop" | while read -r f; do
    sed -i "s/^ro\.product\.model=.*/ro.product.model=$DEVICE_MARKET_NAME/g" "$f"
    sed -i "s/^ro\.product\.system\.model=.*/ro.product.system.model=$DEVICE_MARKET_NAME/g" "$f"
    sed -i "s/^ro\.product\.product\.model=.*/ro.product.product.model=$DEVICE_MARKET_NAME/g" "$f"
    sed -i "s/^ro\.product\.vendor\.model=.*/ro.product.vendor.model=$DEVICE_MARKET_NAME/g" "$f"
    
    sed -i "/^ro\.product\.marketname=/d" "$f"
    echo "ro.product.marketname=$DEVICE_MARKET_NAME" >> "$f"
    
    sed -i "/^ro\.market\.name=/d" "$f"
    echo "ro.market.name=$DEVICE_MARKET_NAME" >> "$f"
done

# ----> BYPASS VNEID E012 & BANKING APPS <----
info "Đang giả mạo prop để ẩn Custom ROM (Bypass VNeID/Banking)..."
find "$work_dir/build/baserom/images/" -type f -name "*.prop" | while read -r f; do
    sed -i 's/test-keys/release-keys/g' "$f"
    sed -i \
        -e '/^ro\.build\.type=/d' \
        -e '/^ro\.debuggable=/d' \
        -e '/^ro\.secure=/d' \
        -e '/^ro\.boot\.flash\.locked=/d' \
        -e '/^ro\.boot\.vbmeta\.device_state=/d' \
        -e '/^ro\.boot\.verifiedbootstate=/d' \
        -e '/^ro\.boot\.warranty_bit=/d' \
        -e '/^ro\.warranty_bit=/d' "$f"

    {
        echo "ro.build.type=user"
        echo "ro.debuggable=0"
        echo "ro.secure=1"
        echo "ro.boot.flash.locked=1"
        echo "ro.boot.vbmeta.device_state=locked"
        echo "ro.boot.verifiedbootstate=green"
        echo "ro.boot.warranty_bit=0"
        echo "ro.warranty_bit=0"
    } >> "$f"
done
info "Hoàn tất ẩn prop bypass VNeID!"

find "$work_dir/build/baserom/images/" -exec touch -t 200901010000.00 {} + 2> /dev/null || true
