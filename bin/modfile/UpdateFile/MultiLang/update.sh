Work_dir=$(pwd)
MAIN_FOLDER="$work_dir/build/baserom/images"
source $work_dir/functions.sh
deviceTYPE=$(cat $work_dir/bin/ddevice/device_type.txt)

if [[ $deviceTYPE == "China" ]];then
    mods "Adding MultiLanguage To ROM..."
    
    # 1. Chép các gói ZK Overlay vào phân vùng product (giữ nguyên code của bạn)
    cp -rf $work_dir/bin/modfile/UpdateFile/MultiLang/updatesource/* $MAIN_FOLDER/product/overlay/
    
    # 2. Xóa cấu hình ngôn ngữ China và kích hoạt Tiếng Việt mặc định trong build.prop
    mods "Configuring default locale for ZK Overlay..."
    for prop in "$MAIN_FOLDER/system/system/build.prop" "$MAIN_FOLDER/product/etc/build.prop"; do
        if [ -f "$prop" ]; then
            # Dọn sạch các biến ngôn ngữ/khu vực cũ tránh xung đột
            sed -i \
                -e '/^ro\.product\.locale=/d' \
                -e '/^persist\.sys\.locale=/d' \
                -e '/^ro\.miui\.region=/d' \
                -e '/^ro\.miui\.build\.region=/d' "$prop"
            
            # Ghi đè cấu hình Tiếng Việt (vi-VN)
            {
                echo "ro.product.locale=vi-VN"
                echo "persist.sys.locale=vi-VN"
                echo "ro.miui.region=VN"
                echo "ro.miui.build.region=global"
            } >> "$prop"
        fi
    done

    mods "Done!"
fi
