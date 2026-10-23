work_dir=$(pwd)
[ -f "$work_dir/functions.sh" ] && source "$work_dir/functions.sh"

# Hồ sơ hiệu năng cao chỉ bật khi config.env ghi PERF_TURBO=true
PERF_TURBO="$(cfg_get PERF_TURBO false)"
mods "Xiaomi_NoLowEnd: PERF_TURBO=$PERF_TURBO"

# ---> SỬA LỖI LẤY NHẦM 'MISSI' <---
DEVICE_CODENAME=""

# 1. Đọc từ file định danh của tool trước (chuẩn nhất)
if [ -f "$work_dir/bin/ddevice/device_code.txt" ]; then
    DEVICE_CODENAME="$(cat "$work_dir/bin/ddevice/device_code.txt" | tr -d '\r\n ')"
elif [ -f "$work_dir/bin/ddevice/device_model.txt" ]; then
    DEVICE_CODENAME="$(cat "$work_dir/bin/ddevice/device_model.txt" | tr -d '\r\n ')"
fi

# 2. Nếu trống hoặc dính 'missi', đọc từ file prop cụ thể (tránh quét lung tung bằng find)
if [ -z "$DEVICE_CODENAME" ] || [ "$DEVICE_CODENAME" = "missi" ]; then
    for prop in \
        "$work_dir/build/baserom/images/product/etc/build.prop" \
        "$work_dir/build/baserom/images/vendor/build.prop" \
        "$work_dir/build/baserom/images/system/system/build.prop"; do
        if [ -f "$prop" ]; then
            val=$(grep -E "^(ro\.product\.product\.device|ro\.product\.vendor\.device|ro\.product\.device)=" "$prop" | head -n 1 | cut -d'=' -f2 | tr -d '\r\n ')
            if [ -n "$val" ] && [ "$val" != "missi" ]; then
                DEVICE_CODENAME="$val"
                break
            fi
        fi
    done
fi

[ -z "$DEVICE_CODENAME" ] && DEVICE_CODENAME="unknown"
[ "$DEVICE_CODENAME" = "missi" ] && DEVICE_CODENAME="unknown"
# ---> KẾT THÚC SỬA LỖI <---

echo "Current device codename: $DEVICE_CODENAME"

# Vòng lặp quét từng file, bọc trong nháy kép để chấp nhận mọi khoảng trắng
find . -type f -name "*.prop" | while read -r f; do
    [ -f "$f" ] || continue
    if [ "$DEVICE_CODENAME" = "onyx" ]; then
        sed -i \
            -e '/^persist\.sys\.computility\./d' \
            -e '/^persist\.sys\.advanced_visual_release=/d' \
            -e '/^ro\.config\.low_ram/d' \
            -e '/^vendor\.perf\.framepacing\.enable=/d' \
            -e '/^persist\.sys\.sf_charge_anim_supported=/d' \
            -e '/^ro\.miui\.has_handy_mode_sf=/d' \
            -e '/^persist\.sys\.power\.default\.powermode=/d' \
            -e '/^ro\.miui\.support_miui_ime_bottom=/d' \
            -e '/^persist\.vendor\.power\.dfps\.enable=/d' \
            -e '/^persist\.sys\.perf\.topapp\.sched=/d' \
            -e '/^ro\.vendor\.perf\.scroll_opt=/d' \
            -e '/^persist\.sys\.thermal\.run-control=/d' "$f"
    else
        # 1) Luôn áp dụng: bỏ ngưỡng "máy yếu" để không bị hạ cấp giao diện
        sed -i \
            -e 's/^ro\.config\.low_ram\.threshold_gb\s*=.*/ro.config.low_ram.threshold_gb=0/' \
            -e 's/^ro\.config\.low_ram\.middle\.threshold_gb\s*=.*/ro.config.low_ram.middle.threshold_gb=0/' \
            "$f"

        # 2) Hồ sơ hiệu năng cao: CHỈ bật khi config.env có PERF_TURBO=true.
        #    Trước đây khối này chạy vô điều kiện -> ép CPU/GPU level 4, tắt
        #    Dynamic FPS, powermode=0 => máy rất nóng và tụt pin sau khi flash.
        if [ "$PERF_TURBO" == "true" ]; then
            sed -i \
                -e 's/^persist\.sys\.computility\.gpulevel\s*=.*/persist.sys.computility.gpulevel=4/' \
                -e 's/^persist\.sys\.computility\.cpulevel\s*=.*/persist.sys.computility.cpulevel=4/' \
                -e 's/^vendor\.perf\.framepacing\.enable\s*=.*/vendor.perf.framepacing.enable=true/' \
                -e 's/^persist\.sys\.sf_charge_anim_supported\s*=.*/persist.sys.sf_charge_anim_supported=true/' \
                -e 's/^ro\.miui\.has_handy_mode_sf\s*=.*/ro.miui.has_handy_mode_sf=1/' \
                -e 's/^persist\.sys\.advanced_visual_release\s*=.*/persist.sys.advanced_visual_release=3/' \
                -e 's/^persist\.sys\.power\.default\.powermode\s*=.*/persist.sys.power.default.powermode=0/' \
                -e 's/^ro\.miui\.support_miui_ime_bottom\s*=.*/ro.miui.support_miui_ime_bottom=1/' \
                -e '/^persist\.vendor\.power\.dfps\.enable=/d' "$f"

            grep -q "^persist\.sys\.perf\.topapp\.sched=" "$f" || echo "persist.sys.perf.topapp.sched=false" >> "$f"
            grep -q "^ro\.vendor\.perf\.scroll_opt=" "$f" || echo "ro.vendor.perf.scroll_opt=true" >> "$f"
            grep -q "^persist\.sys\.thermal\.run-control=" "$f" || echo "persist.sys.thermal.run-control=1" >> "$f"
        fi
    fi
done
