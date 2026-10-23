WORK_DIR=$(pwd)
source $WORK_DIR/functions.sh
AndroidVER=$(cat $WORK_DIR/bin/ddevice/androidver.txt 2>/dev/null | tr -d '\r\n ')
regionTYPE=$(cat $WORK_DIR/bin/ddevice/device_type.txt 2>/dev/null | tr -d '\r\n ')

# ---------------------------------------------------------------------------
# Xác định Android version CÓ FALLBACK.
# Trước đây androidver.txt rỗng (key build.prop không khớp) làm KHÔNG nhánh nào
# chạy -> máy vẫn trễ thông báo mà log build không báo lỗi gì.
# ---------------------------------------------------------------------------
if ! [[ "$AndroidVER" =~ ^[0-9]+$ ]]; then
    sdk=$(cat "$WORK_DIR/bin/ddevice/sdkLevel.txt" 2>/dev/null | tr -d '\r\n ')
    case "$sdk" in
        33) AndroidVER=13 ;; 34) AndroidVER=14 ;; 35) AndroidVER=15 ;;
        36) AndroidVER=16 ;; 37) AndroidVER=17 ;; *) AndroidVER="" ;;
    esac
fi
if ! [[ "$AndroidVER" =~ ^[0-9]+$ ]]; then
    case "$(cat "$WORK_DIR/bin/ddevice/rom_os.txt" 2>/dev/null | tr -d '\r\n ')" in
        OS1) AndroidVER=14 ;;
        OS2) AndroidVER=15 ;;
        OS3) AndroidVER=16 ;;
        OS4) AndroidVER=17 ;;
    esac
fi
if ! [[ "$AndroidVER" =~ ^[0-9]+$ ]]; then
    warn "Không đọc được Android version -> mặc định 16"
    AndroidVER=16
fi

if [[ $regionTYPE == *"Global"* ]]; then
warn "No Support Global ROM!Skipping..."
echo "SKIP (Global ROM)" > "$WORK_DIR/bin/ddevice/notification_fix.txt"
else

mods "Bắt đầu Patch Notification Fix... (Android $AndroidVER)"

if [ "$AndroidVER" -le 13 ]; then
    [ -d "$WORK_DIR/bin/package/NOTIFICATION_FIX/A13" ] && bash $WORK_DIR/bin/package/NOTIFICATION_FIX/A13/RUN.SH
elif [ "$AndroidVER" -eq 14 ];then
    bash $WORK_DIR/bin/package/NOTIFICATION_FIX/A14/RUN.SH
elif [ "$AndroidVER" -eq 15 ];then
    bash $WORK_DIR/bin/package/NOTIFICATION_FIX/A15/RUN.SH
    bash $WORK_DIR/bin/package/NOTIFICATION_FIX/A16/patchServices.sh
else
    # Android 16, 17 trở lên
    bash $WORK_DIR/bin/package/NOTIFICATION_FIX/A16/RUN.SH
fi

# ==================== CẤU HÌNH HỆ THỐNG CHỐNG KILL TIẾN TRÌNH NỀN ====================
MAIN_FOLDER="$WORK_DIR/build/baserom/images"
for prop in "$MAIN_FOLDER/system/system/build.prop" "$MAIN_FOLDER/product/etc/build.prop"; do
    if [ -f "$prop" ]; then
        sed -i \
            -e '/^persist\.sys\.fcm\.push\.whitelist=/d' \
            -e '/^persist\.sys\.gz\.enable=/d' \
            -e '/^persist\.sys\.powmillet\.enable=/d' \
            -e '/^persist\.sys\.millet\.handshake=/d' \
            -e '/^persist\.sys\.millet\.newversion=/d' \
            -e '/^persist\.sys\.mms\.kill_fas_cached_idle=/d' \
            -e '/^persist\.sys\.smartpower\.intercept\.enable=/d' \
            -e '/^persist\.sys\.spc\.pressure\.enable=/d' \
            -e '/^persist\.sys\.spc\.proc_restart_enable=/d' "$prop"

        [ -n "$(tail -c1 "$prop")" ] && echo "" >> "$prop"

        {
            echo "persist.sys.fcm.push.whitelist=1"
            echo "persist.sys.gz.enable=false"
            echo "persist.sys.powmillet.enable=false"
            echo "persist.sys.millet.handshake=false"
            echo "persist.sys.millet.newversion=false"
            echo "persist.sys.mms.kill_fas_cached_idle=false"
            echo "persist.sys.smartpower.intercept.enable=false"
            echo "persist.sys.spc.pressure.enable=false"
            echo "persist.sys.spc.proc_restart_enable=true"
        } >> "$prop"
    fi
done

# Tạo file cấu hình fcm_wake.conf mặc định cho FcmWakeFilter
for fcm_conf_dir in "$MAIN_FOLDER/system/system/etc" "$MAIN_FOLDER/product/etc"; do
    if [ -d "$fcm_conf_dir" ]; then
        cat << 'EOF' > "$fcm_conf_dir/fcm_wake.conf"
# HyperOS FCM Dynamic Wake Filter Configuration
MODE=ALL
EOF
    fi
done

# Ép lại prop MỖI LẦN BOOT.
# build.prop chỉ được init áp dụng khi /data/property/persist.* chưa tồn tại,
# nên flash đè (dirty flash) sẽ giữ nguyên giá trị cũ -> fix không có tác dụng.
INIT_DIR="$MAIN_FOLDER/system/system/etc/init"
if [ -d "$INIT_DIR" ]; then
    cat << 'EOF' > "$INIT_DIR/bugos_notify.rc"
# BugOS - ép cấu hình chống trễ thông báo sau mỗi lần boot
on boot
    setprop persist.sys.fcm.push.whitelist 1
    setprop persist.sys.gz.enable false
    setprop persist.sys.powmillet.enable false
    setprop persist.sys.millet.handshake false
    setprop persist.sys.millet.newversion false
    setprop persist.sys.mms.kill_fas_cached_idle false
    setprop persist.sys.smartpower.intercept.enable false
    setprop persist.sys.spc.pressure.enable false
    setprop persist.sys.spc.proc_restart_enable true
EOF
    mods "Đã thêm bugos_notify.rc (ép prop thông báo mỗi lần boot)"
else
    warn "Không thấy $INIT_DIR, bỏ qua init script ép prop."
fi

# ==================== KIỂM CHỨNG SAU KHI VÁ ====================
# Trước đây nếu decompile/smali lỗi thì chỉ in 1 dòng Fail, build vẫn "xanh"
# và ROM xuất xưởng vẫn trễ thông báo. Giờ ghi trạng thái ra file để soi lại.
NF_STATUS=""
svc_jar=$(find "$MAIN_FOLDER" -type f -name "services.jar" 2>/dev/null | head -n1)
if [ -n "$svc_jar" ] && grep -aq "FcmWakeFilter" "$svc_jar"; then
    NF_STATUS="${NF_STATUS}services.jar=OK "
else
    NF_STATUS="${NF_STATUS}services.jar=FAIL "
fi

miui_jar=$(find "$MAIN_FOLDER" -type f -name "miui-services.jar" 2>/dev/null | head -n1)
if [ -n "$miui_jar" ] && grep -aq "FcmWakeFilter" "$miui_jar"; then
    NF_STATUS="${NF_STATUS}miui-services.jar=OK "
else
    NF_STATUS="${NF_STATUS}miui-services.jar=FAIL "
fi

pk=$(find "$MAIN_FOLDER" -type f -name "PowerKeeper.apk" 2>/dev/null | head -n1)
if [ -n "$pk" ]; then
    NF_STATUS="${NF_STATUS}PowerKeeper=co "
else
    NF_STATUS="${NF_STATUS}PowerKeeper=khong-co "
fi

echo "$NF_STATUS" > "$WORK_DIR/bin/ddevice/notification_fix.txt"
mods "Notification Fix: $NF_STATUS"
if [[ $NF_STATUS == *FAIL* ]]; then
    warn "Có bước patch thất bại -> thông báo có thể VẪN trễ. Xem log decompile/smali phía trên."
fi

mods "Notification Fix hoàn tất!"

fi
