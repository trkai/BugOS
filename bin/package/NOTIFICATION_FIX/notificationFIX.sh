WORK_DIR=$(pwd)
source $WORK_DIR/functions.sh
AndroidVER=$(cat $WORK_DIR/bin/ddevice/androidver.txt 2>/dev/null | tr -d '\r\n ')
regionTYPE=$(cat $WORK_DIR/bin/ddevice/device_type.txt 2>/dev/null | tr -d '\r\n ')

if [[ $regionTYPE == *"Global"* ]]; then
warn "No Support Global ROM!Skipping..."
else

mods "Bắt đầu Patch Notification Fix..."

if [[ $AndroidVER == "12" ]];then
    bash $WORK_DIR/bin/package/NOTIFICATION_FIX/A12/RUN.SH
elif [[ $AndroidVER == "13" ]];then
    bash $WORK_DIR/bin/package/NOTIFICATION_FIX/A13/RUN.SH
elif [[ $AndroidVER == "14" ]];then
    bash $WORK_DIR/bin/package/NOTIFICATION_FIX/A14/RUN.SH
elif [[ $AndroidVER == "15" ]];then
    bash $WORK_DIR/bin/package/NOTIFICATION_FIX/A15/RUN.SH
elif [[ $AndroidVER -ge "16" ]];then
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

mods "Notification Fix hoàn tất!"

fi
