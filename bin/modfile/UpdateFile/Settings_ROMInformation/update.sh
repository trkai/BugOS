#!/bin/bash
WORK_DIR=$(pwd)
source $WORK_DIR/functions.sh
MAIN_FOLDER="$WORK_DIR/build/baserom/images"
rom_os=$(cat $WORK_DIR/bin/ddevice/rom_os.txt 2>/dev/null | tr -d '\r\n ')
regionTYPE=$(cat $WORK_DIR/bin/ddevice/device_type.txt 2>/dev/null | tr -d '\r\n ')
base_rom_code=$(cat $WORK_DIR/bin/ddevice/base_rom_code.txt 2>/dev/null | tr -d '\r\n ')
build_date=$(TZ=Asia/Ho_Chi_Minh date +"%y%m%d")

APKEDITOR="java -jar $WORK_DIR/bin/apktool/apke.jar"
repS="python3 $WORK_DIR/bin/strRep.py"

# Xác định mã vùng hiển thị trên thẻ (như CN260710 trong ảnh mẫu)
region_tag="CN"
if [[ "$regionTYPE" == *"Global"* ]]; then
    region_tag="GLOBAL"
fi
card_incremental="${region_tag}${build_date}"

# Ghi đè vào build.prop của hệ thống
my_props=(
    "$MAIN_FOLDER/system/system/build.prop"
    "$MAIN_FOLDER/product/etc/build.prop"
)

for p in "${my_props[@]}"; do
    if [ -f "$p" ]; then
        sed -i \
            -e '/^ro\.bugos\.version=/d' \
            -e '/^ro\.bugos\.incremental=/d' \
            -e '/^ro\.bugos\.simposcode=/d' \
            -e '/^ro\.bugos\.osversion=/d' "$p"

        [ -n "$(tail -c1 "$p")" ] && echo "" >> "$p"

        {
            echo "ro.bugos.version=BugOS 1.1 | ${base_rom_code%.*}"
            echo "ro.bugos.incremental=${card_incremental}"
            echo "ro.bugos.simposcode=BugOS"
            echo "ro.bugos.osversion=${build_date}"
        } >> "$p"
    fi
done

# Patch Settings.apk để hiển thị logo và thông tin bản build
isSettings=$(find "$MAIN_FOLDER" -type f -name "Settings.apk" | head -n 1)

if [ -n "$isSettings" ] && [ -f "$isSettings" ]; then
    isSettingsDIR=$(dirname "$isSettings")
    mods "Patching Settings: Customizing BugOS Branding & Logo..."

    mkdir -p "$WORK_DIR/apk_temp"
    $APKEDITOR d -i "$isSettings" -o "$WORK_DIR/apk_temp/isSettings.apk.out" >/dev/null 2>&1

    if [ -d "$WORK_DIR/apk_temp/isSettings.apk.out" ]; then
        # 1. Thay thế vector/drawable logo HyperOS bằng Logo BugOS
        LOGO_SRC="$WORK_DIR/bin/modfile/UpdateFile/Settings_ROMInformation/ic_hyper_os.xml"
        if [ -f "$LOGO_SRC" ]; then
            find "$WORK_DIR/apk_temp/isSettings.apk.out/res" -type f \( \
                -name "ic_hyper_os.xml" -o \
                -name "ic_hyper_os_logo.xml" -o \
                -name "ic_os_logo.xml" -o \
                -name "my_device_os_logo.xml" -o \
                -name "hyper_os_logo.xml" \
            \) | while read -r logo_target; do
                cp -f "$LOGO_SRC" "$logo_target"
                mods "Replaced logo asset: $(basename "$logo_target")"
            done
        fi

        # 2. Patch các phương thức smali trong MiuiAboutPhoneUtils
        p1=$(find "$WORK_DIR/apk_temp/isSettings.apk.out" -type f -name "MiuiAboutPhoneUtils.smali" | head -n 1)
        if [ -n "$p1" ] && [ -f "$p1" ]; then
            tar1="$WORK_DIR/bin/modfile/UpdateFile/Settings_ROMInformation/getMiuiVersionInCard.ini"
            tar2="$WORK_DIR/bin/modfile/UpdateFile/Settings_ROMInformation/getRoXmsVersion.ini"
            tar3="$WORK_DIR/bin/modfile/UpdateFile/Settings_ROMInformation/getXmsVersion.ini"
            tar4="$WORK_DIR/bin/modfile/UpdateFile/Settings_ROMInformation/getSimpleOSVersion.ini"

            [ -f "$tar1" ] && $repS "$tar1" "$p1" >/dev/null 2>&1
            [ -f "$tar2" ] && $repS "$tar2" "$p1" >/dev/null 2>&1
            [ -f "$tar3" ] && $repS "$tar3" "$p1" >/dev/null 2>&1
            [ -f "$tar4" ] && $repS "$tar4" "$p1" >/dev/null 2>&1
            mods "Patched MiuiAboutPhoneUtils smali methods."
        fi

        # 3. Đóng gói lại Settings.apk
        Settings_name=$(basename "$isSettings")
        $APKEDITOR b -f -i "$WORK_DIR/apk_temp/isSettings.apk.out" -o "$WORK_DIR/apk_temp/final/$Settings_name" >/dev/null 2>&1

        # Chỉ ghi đè khi build lại thành công (an toàn tuyệt đối, tránh bootloop)
        if [ -f "$WORK_DIR/apk_temp/final/$Settings_name" ] && [ -s "$WORK_DIR/apk_temp/final/$Settings_name" ]; then
            cp -f "$WORK_DIR/apk_temp/final/$Settings_name" "$isSettingsDIR/$Settings_name"
            mods "Successfully applied BugOS branded Settings.apk!"
        else
            mods "Settings rebuild skipped; build.prop brandings applied."
        fi
    fi

    rm -rf "$WORK_DIR/apk_temp"
fi

mods "BugOS ROM Information Integration Done!"
