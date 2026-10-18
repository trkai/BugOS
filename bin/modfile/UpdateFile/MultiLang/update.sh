work_dir=${work_dir:-$(pwd)}
MAIN_FOLDER="$work_dir/build/baserom/images"
source $work_dir/functions.sh
deviceTYPE=$(cat $work_dir/bin/ddevice/device_type.txt 2>/dev/null)
rom_os=$(cat $work_dir/bin/ddevice/rom_os.txt 2>/dev/null | tr -d '\r\n ')

if [[ $deviceTYPE == "China" ]]; then
    mods "Adding MultiLanguage / Vietnamese To ROM..."

    mkdir -p $MAIN_FOLDER/product/overlay/

    # 1. Chọn gói Overlay tương thích theo phiên bản HyperOS
    if [[ "$rom_os" == "OS4" ]] || [[ "$rom_os" =~ ^OS[4-9] ]]; then
        mods "Detected HyperOS 4+! Applying Tory Vietnamese Overlays (OS4)..."
        cp -rf $work_dir/bin/modfile/UpdateFile/MultiLang/updatesource_os4/* $MAIN_FOLDER/product/overlay/
    else
        mods "Applying HyperOS/MIUI MultiLanguage Overlays (ZK Multi)..."
        cp -rf $work_dir/bin/modfile/UpdateFile/MultiLang/updatesource/* $MAIN_FOLDER/product/overlay/
    fi

    # 2. Thiết lập cấu hình vùng Việt Nam (cust.prop) cho First-Boot OOBE
    if [ -d "$MAIN_FOLDER/system_ext" ] && [ -f "$work_dir/bin/modfile/UpdateFile/MultiLang/cust.prop" ]; then
        mkdir -p "$MAIN_FOLDER/system_ext/cust/vn"
        cp -rf "$work_dir/bin/modfile/UpdateFile/MultiLang/cust.prop" "$MAIN_FOLDER/system_ext/cust/vn/cust.prop"
        mods "Configured system_ext/cust/vn/cust.prop"
    fi

    # 3. Xóa cấu hình ngôn ngữ China và kích hoạt Tiếng Việt mặc định trong build.prop
    mods "Configuring default locale for Vietnamese..."
    for prop in "$MAIN_FOLDER/system/system/build.prop" "$MAIN_FOLDER/product/etc/build.prop"; do
        if [ -f "$prop" ]; then
            # Dọn sạch các biến ngôn ngữ/khu vực cũ tránh xung đột
            sed -i \
                -e '/^ro\.product\.locale=/d' \
                -e '/^persist\.sys\.locale=/d' \
                -e '/^ro\.product\.locale\.language=/d' \
                -e '/^ro\.product\.locale\.region=/d' \
                -e '/^persist\.sys\.timezone=/d' \
                -e '/^ro\.miui\.region=/d' \
                -e '/^ro\.miui\.build\.region=/d' \
                -e '/^ro\.miui\.cust_variant=/d' \
                -e '/^ro\.vendor\.audio\.spk\.clean=/d' \
                -e '/^persist\.sys\.zk\.multi=/d' "$prop"

            # Đảm bảo file kết thúc bằng xuống dòng trước khi thêm
            [ -n "$(tail -c1 "$prop")" ] && echo "" >> "$prop"

            # Ghi đè cấu hình Tiếng Việt (vi-VN)
            {
                echo "ro.product.locale=vi-VN"
                echo "persist.sys.locale=vi-VN"
                echo "ro.product.locale.language=vi"
                echo "ro.product.locale.region=VN"
                echo "persist.sys.timezone=Asia/Ho_Chi_Minh"
                echo "ro.miui.region=VN"
                echo "ro.miui.build.region=global"
                echo "ro.miui.cust_variant=vn"
                echo "ro.vendor.audio.spk.clean=true"
                echo "persist.sys.zk.multi=1"
            } >> "$prop"
        fi
    done

    mods "Done!"
fi
