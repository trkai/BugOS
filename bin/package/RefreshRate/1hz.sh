work_dir=$(pwd)
source $work_dir/functions.sh

# Chỉ ép Smart FPS / 1Hz khi config.env bật FORCE_SMART_FPS=true.
# Mặc định TẮT: ép smart_fps=120 trên panel không hỗ trợ LTPO khiến màn hình
# không bao giờ xuống tần số thấp -> máy nóng, tụt pin.
FORCE_SMART_FPS="$(cfg_get FORCE_SMART_FPS false)"

gfDir="$work_dir/build/baserom/images/product/etc/device_features"

if [ ! -d "$gfDir" ]; then
    mods "RefreshRate: không có device_features, bỏ qua."
    exit 0
fi

for gfFile in "$gfDir"/*.xml; do
    [ -f "$gfFile" ] || continue

    # 1) Chỉ bổ sung mốc quét vào DANH SÁCH tuỳ chọn (không ép tần số nào cả)
    grep -q '<item>120</item>' "$gfFile" || sed -i 's#<item>144</item>#<item>144</item>\n        <item>120</item>#' "$gfFile"
    grep -q '<item>90</item>'  "$gfFile" || sed -i 's#<item>120</item>#<item>120</item>\n        <item>90</item>#'  "$gfFile"
    mods "RefreshRate: đã bổ sung mốc 90/120Hz vào $(basename "$gfFile")"

    # 2) Smart FPS + 1Hz: tuỳ chọn, mặc định không bật
    if [ "$FORCE_SMART_FPS" == "true" ]; then
        grep -q '<item>1</item>' "$gfFile" || sed -i 's#<item>60</item>#<item>60</item>\n        <item>1</item>#' "$gfFile"
        grep -q 'support_smart_fps' "$gfFile" || sed -i 's#<integer name="defaultFps">60</integer>#<integer name="defaultFps">60</integer>\n    <bool name="support_smart_fps">true</bool>\n    <integer name="smart_fps_value">120</integer>#' "$gfFile"
        mods "RefreshRate: bật Smart FPS 120Hz + 1Hz (FORCE_SMART_FPS=true)"
    fi
done
