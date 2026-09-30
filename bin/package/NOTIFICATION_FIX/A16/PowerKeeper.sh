#!/bin/bash
# BugOS - NOTIFICATION_FIX A16 - PowerKeeper
# Credit: hướng dẫn gốc của @MMETMAmods

work_dir=$(pwd)
[ -f "$work_dir/functions.sh" ] && source "$work_dir/functions.sh"

MAIN_FOLDER="$work_dir/build/baserom/images"
repS="python3 $work_dir/bin/strRep.py"
APKEDITOR="java -jar $work_dir/bin/apktool/apke.jar"
TMP="$work_dir/apk_temp"
tar1="$work_dir/bin/package/NOTIFICATION_FIX/A16/patch/gms.ini"

# Hỗ trợ bắt log an toàn (Dùng được cả lệnh patch, mods hoặc info tùy functions.sh)
log_msg() {
    if type patch &>/dev/null; then patch "$1"
    elif type mods &>/dev/null; then mods "$1"
    elif type info &>/dev/null; then info "$1"
    else echo "[PowerKeeper] $1"; fi
}

log_msg "Bắt đầu Patching PowerKeeper (Fix Thông Báo)..."

# 1. Tìm PowerKeeper.apk (một số ROM không có file này)
isPowerKeeper=$(find "$MAIN_FOLDER" -type f -name "PowerKeeper.apk" | head -n1)
if [[ -z "$isPowerKeeper" ]]; then
    log_msg "Không có PowerKeeper.apk trong ROM này, bỏ qua!"
    exit 0
fi
isPowerKeeperDIR=$(dirname "$isPowerKeeper")

# 2. Decompile
rm -rf "$TMP"
mkdir -p "$TMP"
$APKEDITOR d -t raw -f -no-dex-debug -i "$isPowerKeeper" -o "$TMP/isPowerKeeper.apk.out" >/dev/null 2>&1
if [[ ! -d "$TMP/isPowerKeeper.apk.out" ]]; then
    log_msg "Fail: Không decompile được PowerKeeper.apk, giữ nguyên bản gốc!"
    rm -rf "$TMP"
    exit 0
fi

Smali1=$(find "$TMP/isPowerKeeper.apk.out" -type f -name "MilletConfig.smali" | head -n1)
Smali2=$(find "$TMP/isPowerKeeper.apk.out" -type f -name "GmsObserver.smali" | head -n1)
patched=0

# 3. MilletConfig: IS_INTERNATIONAL_BUILD -> IS_MIUI (luôn true)
if [[ -n "$Smali1" ]] && grep -q 'IS_INTERNATIONAL_BUILD:Z' "$Smali1"; then
    sed -i 's/Lmiui\/os\/Build;->IS_INTERNATIONAL_BUILD:Z/Lmiui\/os\/Build;->IS_MIUI:Z/g' "$Smali1"
    patched=1
    log_msg "Đã vá thành công MilletConfig"
else
    log_msg "Cảnh báo: không vá được MilletConfig"
fi

# 4. GmsObserver: isGmsControlEnabled()Z luôn trả về false (qua gms.ini)
if [[ -n "$Smali2" ]]; then
    if [[ -f "$tar1" ]]; then
        $repS "$tar1" "$Smali2"
        # Bắt cả v0 hoặc p0 đề phòng smaliv2 đổi tên thanh ghi
        if grep -E -q 'const/4 [pv]0, 0x0' "$Smali2"; then
            patched=1
            log_msg "Đã vá thành công GmsObserver (Thả rông GMS)"
        else
            log_msg "Cảnh báo: gms.ini không khớp GmsObserver.smali"
        fi
    else
        log_msg "Cảnh báo: Không tìm thấy file $tar1 để vá GMS!"
    fi
else
    log_msg "Cảnh báo: không thấy GmsObserver.smali"
fi

if [[ $patched -eq 0 ]]; then
    log_msg "Không vá được gì, giữ nguyên PowerKeeper.apk gốc!"
    rm -rf "$TMP"
    exit 0
fi

# 5. Build lại và thay vào ROM
PowerKeeper=$(basename "$isPowerKeeper")
$APKEDITOR b -f -i "$TMP/isPowerKeeper.apk.out" -o "$TMP/final/$PowerKeeper" >/dev/null 2>&1

if [[ -f "$TMP/final/$PowerKeeper" && -n "$isPowerKeeperDIR" && "$isPowerKeeperDIR" == "$MAIN_FOLDER"/* ]]; then
    # Xóa thư mục gốc để dọn luôn cả odex/vdex cũ tránh treo logo
    rm -rf "$isPowerKeeperDIR"/*
    cp -rf "$TMP/final/$PowerKeeper" "$isPowerKeeperDIR/"
    rm -rf "$TMP"
    log_msg "Hoàn tất vá PowerKeeper.apk!"
else
    log_msg "Fail: không build lại được PowerKeeper.apk, giữ nguyên bản gốc!"
    rm -rf "$TMP"
    exit 0
fi
