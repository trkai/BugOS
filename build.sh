trap 'rc=$?; echo "[TRAP] build.sh kết thúc tại dòng $LINENO, mã thoát $rc"' EXIT

baserom="$1"
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
sudo apt-get install -y xmlstarlet aapt libc++1 libc++abi1 libsparse-tools erofs-utils

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

if [[ ! -f "$baserom" ]]; then
    error "Không tìm thấy file ROM sau khi tải: $baserom"
    exit 1
fi

rom_download_size=$(stat -c%s "$baserom" 2>/dev/null || du -sb "$baserom" 2>/dev/null | awk '{print $1}')
echo "$rom_download_size" > "$work_dir/bin/ddevice/rom_download_size.txt"
unpack "File ROM tải về: $(basename "$baserom") ($((rom_download_size / 1024 / 1024)) MB)"
free_disk_mb=$(df -m "$work_dir" | awk 'NR==2 {print $4}')
unpack "Dung lượng ổ đĩa khả dụng của hệ thống: ${free_disk_mb} MB"
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
    unpack "Unpacking payload.bin"
    df -h "$work_dir"

    # Lấy payload.bin ra khỏi file zip (nếu chưa có)
    if [[ ! -f build/baserom/payload.bin ]]; then
        unzip -o "${baserom}" payload.bin -d build/baserom/ || { error "Không giải nén được payload.bin từ zip"; exit 1; }
    fi

    payload-extract extract -o build/baserom/images/ build/baserom/payload.bin || { error "Unpacking payload.bin failed"; exit 1; }

    # Giải phóng dung lượng ngay: zip gốc và payload.bin không cần nữa
    rm -f build/baserom/payload.bin
    rm -f "${baserom}"

    echo "===== Sau khi payload-extract ====="
    ls -la build/baserom/images/
    df -h "$work_dir"

    # ---> FIX LỖI MẤT PHÂN VÙNG TRÊN PAYLOAD.BIN (A/B DEVICE) <---
    for i in build/baserom/images/*_a.img; do
        if [ -f "$i" ]; then
            mv "$i" "${i%_a.img}.img"
        fi
    done
    for i in build/baserom/images/*_b.img; do
        if [ -f "$i" ]; then
            rm -f "$i"
        fi
    done

elif [[ ${baserom_type} == 'br' ]]; then
    super_list=$(cat build/baserom/dynamic_partitions_op_list | grep "add " | awk '{ print $2 }')
    unpack "Unpacking new.dat.br"
    for brotlipart in ${super_list}; do
        brotli -d build/baserom/$brotlipart.new.dat.br >/dev/null 2>&1
        python3 $work_dir/bin/Linux/x86_64/sdat2img.py build/baserom/$brotlipart.transfer.list build/baserom/$brotlipart.new.dat build/baserom/images/$brotlipart.img >/dev/null 2>&1
        rm -rf build/baserom/$brotlipart.new.dat* build/baserom/$brotlipart.transfer.list build/baserom/$brotlipart.patch.*
    done
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

    orig_super_size=$(stat -c%s build/baserom/super.img 2>/dev/null)
    if [ -n "$orig_super_size" ] && [ "$orig_super_size" -gt 0 ] 2>/dev/null; then
        echo "$orig_super_size" > "$work_dir/bin/ddevice/superSize.txt"
        unpack "Phát hiện kích thước super.img gốc: $orig_super_size bytes"
    fi

    rm -rf ${super_dir}/*super.img.*
    unpack "[super.img] extracted."

    cust_file=$(find build/baserom -name "cust.img.0" | head -n 1)
    if [[ -n "$cust_file" ]]; then
        cust_dir=$(dirname "$cust_file")
        /usr/bin/simg2img ${cust_dir}/cust.img.* build/baserom/images/cust.img 2>/dev/null || true
        rm -rf ${cust_dir}/cust.img.*
    fi

    unpack "Unpacking BASEROM [super.img]"
    python3 bin/lpunpack.py build/baserom/super.img build/baserom/images/ >/dev/null 2>&1

    for i in build/baserom/images/*_a.img; do
        if [ -f "$i" ]; then
            mv "$i" "${i%_a.img}.img"
        fi
    done

    super_list="system system_ext product vendor odm mi_ext"
fi

# ==================== ĐO DUNG LƯỢNG PHÂN VÙNG GỐC TỪ ROM ====================
unpack "Tự động phân tích dung lượng các phân vùng gốc..."
stock_total_size=0
for part in ${super_list}; do
    part_img="$work_dir/build/baserom/images/${part}.img"
    if [ -f "$part_img" ]; then
        p_size=$(stat -c%s "$part_img" 2>/dev/null || echo 0)
        echo "$p_size" > "$work_dir/bin/ddevice/orig_size_${part}.txt"
        stock_total_size=$((stock_total_size + p_size))
        unpack "  [GỐC] Phân vùng ${part}: $p_size bytes ($((p_size / 1024 / 1024)) MB)"
    fi
done
if [ "$stock_total_size" -gt 0 ]; then
    echo "$stock_total_size" > "$work_dir/bin/ddevice/stock_partitions_total.txt"
    unpack "  ===> Tổng dung lượng phân vùng gốc: $stock_total_size bytes ($((stock_total_size / 1024 / 1024)) MB)"
fi
# ============================================================================

for part in ${super_list}; do
    if [ -f "$work_dir/build/baserom/images/${part}.img" ]; then
        echo ">>> extract ${part}"
        extract_partition $work_dir/build/baserom/images/${part}.img $work_dir/build/baserom/images || echo "!!! extract ${part} THẤT BẠI"
        PACK_TYPE=$(cat $work_dir/bin/ddevice/fstype.txt 2>/dev/null || echo "erofs")
    else
        echo "-> Phân vùng ${part}.img không có trong ROM này (bỏ qua bình thường)"
    fi
done

echo "===== Sau khi extract các partition ====="
ls -la $work_dir/build/baserom/images/
df -h "$work_dir"

# Bắt buộc phải có các partition chính, nếu không thì dừng luôn (không "giả thành công")
for must in vendor system product; do
    if [ ! -d "$work_dir/build/baserom/images/$must" ] || [ -z "$(ls -A $work_dir/build/baserom/images/$must 2>/dev/null)" ]; then
        error "Thiếu hoặc rỗng partition bắt buộc: $must (giải nén thất bại, xem log phía trên)"
        exit 1
    fi
done

# ==================== FIX TÊN CODENAME THIẾT BỊ ====================
detected_codename=""

# 1. Ưu tiên kiểm tra device_f hoặc device_code đã được trích xuất từ tên gói ROM (chuẩn xác nhất)
curr_df=$(cat "$work_dir/bin/ddevice/device_f.txt" 2>/dev/null | tr -d '\r\n ' | tr '[:upper:]' '[:lower:]')
if ! is_dummy_codename "$curr_df"; then
    detected_codename="$curr_df"
fi

if [ -z "$detected_codename" ]; then
    curr_dc=$(cat "$work_dir/bin/ddevice/device_code.txt" 2>/dev/null | tr -d '\r\n ' | tr '[:upper:]' '[:lower:]')
    if ! is_dummy_codename "$curr_dc"; then
        detected_codename="$curr_dc"
    fi
fi

# 2. Nếu chưa có, đối soát tên file ROM với danh sách thiết bị
if [ -z "$detected_codename" ] && [ -n "$baserom" ]; then
    clean_rom_name=$(basename "$baserom" | tr '[:upper:]' '[:lower:]')
    if [ -f "$work_dir/bin/ddevice/data/devices_data.txt" ]; then
        while read -r code; do
            code_clean=$(echo "$code" | tr '[:upper:]' '[:lower:]' | tr -d '\r\n ')
            if [ -n "$code_clean" ] && [[ "$clean_rom_name" =~ (^|[^a-z0-9])${code_clean}([^a-z0-9]|$) ]]; then
                detected_codename="$code_clean"
                break
            fi
        done < "$work_dir/bin/ddevice/data/devices_data.txt"
    fi
    if [ -z "$detected_codename" ]; then
        cand=$(basename "$baserom" | cut -d'-' -f1 | cut -d'_' -f2 | tr '[:upper:]' '[:lower:]' | tr -d '\r\n ')
        if ! is_dummy_codename "$cand"; then
            detected_codename="$cand"
        fi
    fi
fi

# 3. Fallback: Quét tìm codename trong các file build.prop thực tế (loại bỏ tuyệt đối các tag phân vùng miproduct, mivendor, missi...)
if [ -z "$detected_codename" ]; then
    for prop in \
        "$work_dir/build/baserom/images/product/etc/build.prop" \
        "$work_dir/build/baserom/images/odm/etc/build.prop" \
        "$work_dir/build/baserom/images/system/system/build.prop" \
        "$work_dir/build/baserom/images/vendor/build.prop"; do
        if [ -f "$prop" ]; then
            for prop_key in ro.product.product.name ro.product.odm.device ro.product.name ro.build.product ro.product.device ro.product.mod_device; do
                val=$(grep -E "^${prop_key}=" "$prop" 2>/dev/null | head -n 1 | cut -d'=' -f2 | tr -d '\r\n ' | tr '[:upper:]' '[:lower:]')
                if ! is_dummy_codename "$val"; then
                    detected_codename="$val"
                    break 2
                fi
            done
        fi
    done
fi

if [ -n "$detected_codename" ]; then
    device_f="$detected_codename"
fi

if is_dummy_codename "$device_f"; then
    device_f=$(cat "$work_dir/bin/ddevice/device_code.txt" 2>/dev/null | tr -d '\r\n ' | tr '[:upper:]' '[:lower:]')
fi

# Fallback trích xuất trực tiếp từ tên file zip (ví dụ: annibale-ota_full-...)
if is_dummy_codename "$device_f" && [ -n "$baserom" ]; then
    device_f=$(basename "$baserom" | cut -d'-' -f1 | cut -d'_' -f2 | tr '[:upper:]' '[:lower:]' | tr -d '\r\n ')
fi

if ! is_dummy_codename "$device_f"; then
    echo "$device_f" > "$work_dir/bin/ddevice/device_f.txt"
    curr_dc=$(cat "$work_dir/bin/ddevice/device_code.txt" 2>/dev/null)
    if is_dummy_codename "$curr_dc"; then
        echo "$(echo "$device_f" | tr '[:lower:]' '[:upper:]')" > "$work_dir/bin/ddevice/device_code.txt"
    fi
fi

getvar=$(cat "$work_dir/bin/ddevice/device_f.txt" 2>/dev/null)
[ -z "$getvar" ] && getvar="$device_f"
# ===================================================================

rm -rf config
rm -rf build/baserom/payload.bin build/baserom/super.img

# Kỹ thuật ép tên: Làm sạch hậu tố NT/INT và ép về tên thương hiệu riêng
MY_BRAND_NAME="BugOS"
echo "$MY_BRAND_NAME" > $work_dir/bin/ddevice/os_type.txt
echo "$MY_BRAND_NAME" > $work_dir/bin/ddevice/brand.txt

mods "Gathering Devices Infomations"
bash $work_dir/bin/ddevice/getname.sh "$getvar"
bash $work_dir/bin/ddevice/fetchINFO.sh

python3 $work_dir/notify.py build "$repo_name" "$baserom" "$prefix_id" "$builder_name" "$builder_id"

bash $work_dir/bin/ddevice/DEBLOAT/debloat.sh
info "Done"

bash $work_dir/bin/modfile/OS1/insmod.sh
bash $work_dir/bin/modfile/OS2/insmod.sh
bash $work_dir/bin/modfile/OS3/insmod.sh
bash $work_dir/bin/modfile/OS4/insmod.sh
bash $work_dir/bin/modfile/Universal/insfile.sh
bash $work_dir/bin/modfile/UpdateFile/insupdate.sh
bash $work_dir/bin/package/patchpackage.sh

# ----> ĐIỀU KIỆN ÁP DỤNG ĐỊNH DANH VÀ BẢN QUYỀN <----
CURRENT_CODENAME="$(cat $work_dir/bin/ddevice/device_code.txt 2>/dev/null)"
[ -z "$CURRENT_CODENAME" ] && CURRENT_CODENAME="$(cat $work_dir/bin/ddevice/device_model.txt 2>/dev/null)"
[ -z "$CURRENT_CODENAME" ] && CURRENT_CODENAME="$(cat $work_dir/bin/ddevice/device_f.txt 2>/dev/null)"

if is_dummy_codename "$CURRENT_CODENAME"; then
    for prop in \
        "$work_dir/build/baserom/images/product/etc/build.prop" \
        "$work_dir/build/baserom/images/odm/etc/build.prop" \
        "$work_dir/build/baserom/images/system/system/build.prop" \
        "$work_dir/build/baserom/images/vendor/build.prop"; do
        if [ -f "$prop" ]; then
            for prop_key in ro.product.product.name ro.product.odm.device ro.product.name ro.build.product ro.product.device; do
                val=$(grep -E "^${prop_key}=" "$prop" 2>/dev/null | head -n 1 | cut -d'=' -f2 | tr -d '\r\n ')
                if ! is_dummy_codename "$val"; then
                    CURRENT_CODENAME="$val"
                    break 2
                fi
            done
        fi
    done
fi

CURRENT_CODENAME="$(echo "$CURRENT_CODENAME" | tr -d ' ' | tr '[:upper:]' '[:lower:]')"

if [[ "$CURRENT_CODENAME" =~ (pudding|pandora|popsicle|nezha) ]]; then
    info "Thiết bị thuộc Xiaomi 17 Series ($CURRENT_CODENAME): Giữ nguyên toàn bộ HyperOS/MIUI và version prop gốc."
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

    if [ -z "$ORIGINAL_INC" ]; then
        rom_os_val=$(cat "$work_dir/bin/ddevice/rom_os.txt" 2>/dev/null | tr -d '\r\n')
        [ -n "$rom_os_val" ] && ORIGINAL_INC="${rom_os_val}.0" || ORIGINAL_INC="OS4.0"
    fi

    find "$work_dir/build/baserom/images/" -type f -name "*.prop" | while read -r f; do
        sed -i "s/^ro\.build\.display\.id=.*/ro.build.display.id=BugOS 1.1 | $ORIGINAL_INC/g" "$f"
        sed -i "s/^ro\.system\.build\.display\.id=.*/ro.system.build.display.id=BugOS 1.1 | $ORIGINAL_INC/g" "$f"
    done
fi

# ----> FIX HIỂN THỊ ĐÚNG TÊN MÁY (MARKET NAME) <----
info "Đang đồng bộ tên hiển thị của thiết bị (Market Name)..."

DEVICE_MARKET_NAME="$(cat $work_dir/bin/ddevice/device_name.txt 2>/dev/null)"
[ -z "$DEVICE_MARKET_NAME" ] && DEVICE_MARKET_NAME="$(cat $work_dir/bin/ddevice/name_devices.txt 2>/dev/null)"

# Nếu vẫn chưa có hoặc là giá trị mặc định, trích xuất trực tiếp từ các prop gốc của ROM
if [ -z "$DEVICE_MARKET_NAME" ] || [ "$DEVICE_MARKET_NAME" = "Xiaomi Device" ] || [ "$DEVICE_MARKET_NAME" = "Không tìm thấy key" ]; then
    for prop in \
        "$work_dir/build/baserom/images/product/etc/build.prop" \
        "$work_dir/build/baserom/images/system/system/build.prop" \
        "$work_dir/build/baserom/images/vendor/build.prop" \
        "$work_dir/build/baserom/images/odm/etc/build.prop"; do
        if [ -f "$prop" ]; then
            val=$(grep -E "^(ro\.product\.marketname|ro\.product\.product\.marketname|ro\.product\.model)=" "$prop" 2>/dev/null | head -n 1 | cut -d'=' -f2 | tr -d '\r\n')
            if [ -n "$val" ] && [ "$val" != "Xiaomi Device" ] && ! is_dummy_codename "$val"; then
                DEVICE_MARKET_NAME="$val"
                break
            fi
        fi
    done
fi

[ -z "$DEVICE_MARKET_NAME" ] && DEVICE_MARKET_NAME="Xiaomi Device"

# Cập nhật đồng bộ vào cả 2 file
echo "$DEVICE_MARKET_NAME" > "$work_dir/bin/ddevice/device_name.txt"
echo "$DEVICE_MARKET_NAME" > "$work_dir/bin/ddevice/name_devices.txt"

find "$work_dir/build/baserom/images/" -type f -name "*.prop" | while read -r f; do
    sed -i "s#^ro\.product\.model=.*#ro.product.model=$DEVICE_MARKET_NAME#g" "$f"
    sed -i "s#^ro\.product\.system\.model=.*#ro.product.system.model=$DEVICE_MARKET_NAME#g" "$f"
    sed -i "s#^ro\.product\.product\.model=.*#ro.product.product.model=$DEVICE_MARKET_NAME#g" "$f"
    sed -i "s#^ro\.product\.vendor\.model=.*#ro.product.vendor.model=$DEVICE_MARKET_NAME#g" "$f"

    sed -i "/^ro\.product\.marketname=/d" "$f"
    echo "ro.product.marketname=$DEVICE_MARKET_NAME" >> "$f"

    sed -i "/^ro\.market\.name=/d" "$f"
    echo "ro.market.name=$DEVICE_MARKET_NAME" >> "$f"
done

# ----> FIX LỖI ĐÓNG GÓI REPACK (NHẬN DIỆN A/B DEVICE CHO HYPEROS 3) <----
info "Đang đồng bộ lại prop để Pack ROM không bị lỗi..."

# vendor đã được kiểm tra tồn tại ở trên, chỉ cần đảm bảo có build.prop và cờ A/B
if [ ! -f "$work_dir/build/baserom/images/vendor/build.prop" ]; then
    if [ -f "$work_dir/build/baserom/images/vendor/etc/build.prop" ]; then
        cp "$work_dir/build/baserom/images/vendor/etc/build.prop" "$work_dir/build/baserom/images/vendor/build.prop"
    else
        echo "ro.build.ab_update=true" > "$work_dir/build/baserom/images/vendor/build.prop"
    fi
fi

if ! grep -q "ro.build.ab_update=true" "$work_dir/build/baserom/images/vendor/build.prop"; then
    echo "ro.build.ab_update=true" >> "$work_dir/build/baserom/images/vendor/build.prop"
fi

# ----> THÊM PROP TÙY CHỈNH <----
info "Đang thêm prop persist.sys.zk.multi=1..."
for f in \
    "$work_dir/build/baserom/images/system/system/build.prop" \
    "$work_dir/build/baserom/images/product/etc/build.prop"; do
    if [ -f "$f" ]; then
        sed -i '/^persist\.sys\.zk\.multi=/d' "$f"
        # đảm bảo file kết thúc bằng xuống dòng trước khi thêm
        [ -n "$(tail -c1 "$f")" ] && echo "" >> "$f"
        echo "persist.sys.zk.multi=1" >> "$f"
    fi
done

find "$work_dir/build/baserom/images/" -exec touch -t 200901010000.00 {} + 2> /dev/null || true
