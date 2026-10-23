#!/bin/bash
WORK_DIR=$(pwd)
source "$WORK_DIR/functions.sh" 2>/dev/null || true
MAIN_FOLDER="$WORK_DIR/build/baserom/images"
rom_os=$(cat "$WORK_DIR/bin/ddevice/rom_os.txt" 2>/dev/null | tr -d '\r\n ')
regionTYPE=$(cat "$WORK_DIR/bin/ddevice/device_type.txt" 2>/dev/null | tr -d '\r\n ')
base_rom_code=$(cat "$WORK_DIR/bin/ddevice/base_rom_code.txt" 2>/dev/null | tr -d '\r\n ')
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
            -e '/^bugos\.simposcode=/d' \
            -e '/^ro\.bugos\.osversion=/d' "$p"

        [ -n "$(tail -c1 "$p")" ] && echo "" >> "$p"

        {
            echo "ro.bugos.version=BugOS 1.1 | ${base_rom_code%.*}"
            echo "ro.bugos.incremental=${card_incremental}"
            echo "ro.bugos.osversion=${build_date}"
        } >> "$p"
    fi
done

# Patch Settings.apk để hiển thị logo và thông tin bản build
isSettings=$(find "$MAIN_FOLDER" -type f -name "Settings.apk" 2>/dev/null | head -n 1)

LOGO_DIR="$WORK_DIR/bin/modfile/UpdateFile/Settings_ROMInformation"
LOGO_REF="logo_ref.json"
[ -f "$LOGO_DIR/logo_ref_bugos.json" ] && LOGO_REF="logo_ref_bugos.json"

if [ -n "$isSettings" ] && [ -f "$isSettings" ]; then
    isSettingsDIR=$(dirname "$isSettings")
    Settings_name=$(basename "$isSettings")
    KASHI_XZ="$LOGO_DIR/Settings_kashi.apk.xz"
    USE_KASHI="$(cfg_get USE_KASHI_SETTINGS false)"

    # ------------------------------------------------------------------
    # CHẾ ĐỘ A (mặc định): mod đè thẳng vào Settings.apk CỦA CHÍNH ROM.
    #   decompile -> patch smali -> build lại -> vá logo trên binary XML.
    #   Không cần file APK đóng gói sẵn 77 MB nằm trong git.
    # CHẾ ĐỘ B (USE_KASHI_SETTINGS=true): dùng APK Kashi đóng gói sẵn
    #   (có thêm card MyDevice + thanh dung lượng) nếu file tồn tại.
    # ------------------------------------------------------------------
    if [ "$USE_KASHI" == "true" ] && [ -f "$KASHI_XZ" ]; then
        mods "Applying pre-compiled Kashi MyDevice Cards & Storage Progress to Settings..."
        python3 -c "import lzma; open('$isSettings', 'wb').write(lzma.decompress(open('$KASHI_XZ', 'rb').read()))"

        # Vá vector logo (APK Kashi đóng gói sẵn có 5 file xiaomi_os_logo*.xml bị hỏng pathData)
        if [ -f "$LOGO_DIR/patch_logo.py" ]; then
            python3 "$LOGO_DIR/patch_logo.py" "$isSettings" --ref "$LOGO_REF" --force \
                || warn "patch_logo.py thất bại - logo Settings có thể vẫn bị vỡ."
        fi

        rm -rf "$isSettingsDIR"/oat "$isSettingsDIR"/*/oat "$isSettingsDIR"/*.odex "$isSettingsDIR"/*.vdex 2>/dev/null
        mods "Successfully applied Kashi MyDevice Settings.apk!"
    else
        mods "Patching Settings.apk của ROM trực tiếp (logo BugOS + thông tin bản dựng)..."
        rm -rf "$WORK_DIR/apk_temp"
        mkdir -p "$WORK_DIR/apk_temp/final"
        SET_OUT="$WORK_DIR/apk_temp/isSettings.apk.out"

        $APKEDITOR d -t raw -f -no-dex-debug -i "$isSettings" -o "$SET_OUT" >/dev/null 2>&1

        if [ -d "$SET_OUT" ]; then
            # 1. Patch smali: thông tin bản dựng hiển thị trong card
            p1=$(find "$SET_OUT" -type f -name "MiuiAboutPhoneUtils.smali" 2>/dev/null | head -n 1)
            if [ -n "$p1" ] && [ -f "$p1" ]; then
                for ini in getMiuiVersionInCard getRoXmsVersion getXmsVersion getSimpleOSVersion; do
                    ini_f="$LOGO_DIR/$ini.ini"
                    [ -f "$ini_f" ] && $repS "$ini_f" "$p1" >/dev/null 2>&1
                done
                mods "Đã patch MiuiAboutPhoneUtils.smali"
            else
                warn "Không thấy MiuiAboutPhoneUtils.smali - bỏ qua patch smali"
            fi

            # 2. Build lại APK
            $APKEDITOR b -f -i "$SET_OUT" -o "$WORK_DIR/apk_temp/final/$Settings_name" >/dev/null 2>&1

            if [ -f "$WORK_DIR/apk_temp/final/$Settings_name" ] && [ -s "$WORK_DIR/apk_temp/final/$Settings_name" ]; then
                # 3. Vá logo trên binary XML của APK vừa build (không cần sửa res trước khi build)
                if [ -f "$LOGO_DIR/patch_logo.py" ]; then
                    python3 "$LOGO_DIR/patch_logo.py" "$WORK_DIR/apk_temp/final/$Settings_name" \
                        --ref "$LOGO_REF" --force \
                        || warn "patch_logo.py thất bại - logo Settings có thể không đổi."
                fi

                cp -f "$WORK_DIR/apk_temp/final/$Settings_name" "$isSettings"
                rm -rf "$isSettingsDIR"/oat "$isSettingsDIR"/*/oat "$isSettingsDIR"/*.odex "$isSettingsDIR"/*.vdex 2>/dev/null
                mods "Đã đè Settings.apk của ROM: logo BugOS + thông tin bản dựng."
            else
                warn "Build lại Settings.apk thất bại - giữ nguyên bản gốc của ROM."
            fi
        else
            warn "Không decompile được Settings.apk - giữ nguyên bản gốc của ROM."
        fi

        rm -rf "$WORK_DIR/apk_temp"
    fi
fi

mods "BugOS ROM Information Integration Done!"
