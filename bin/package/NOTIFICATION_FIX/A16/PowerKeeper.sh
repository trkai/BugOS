#!/bin/bash
# BugOS - NOTIFICATION_FIX A16 - PowerKeeper
# Credit: hướng dẫn gốc của @MMETMAmods
work_dir=$(pwd)
source $work_dir/functions.sh
MAIN_FOLDER="$work_dir/build/baserom/images"
repS="python3 $work_dir/bin/strRep.py"
APKEDITOR="java -jar $work_dir/bin/apktool/apke.jar"
TMP="$work_dir/apk_temp"
tar1="$work_dir/bin/package/NOTIFICATION_FIX/A16/patch/gms.ini"

patch "Patching PowerKeeper"

# 1. Tìm PowerKeeper.apk (một số ROM, ví dụ annibale OS3, không có file này)
isPowerKeeper=$(find "$MAIN_FOLDER" -type f -name "PowerKeeper.apk" | head -n1)
if [[ -z $isPowerKeeper ]]; then
    patch "Không có PowerKeeper.apk, bỏ qua"
    exit 0
fi
isPowerKeeperDIR=$(dirname "$isPowerKeeper")

# 2. Decompile
rm -rf "$TMP"
mkdir -p "$TMP"
$APKEDITOR d -t raw -f -no-dex-debug -i "$isPowerKeeper" -o "$TMP/isPowerKeeper.apk.out" >/dev/null 2>&1
if [[ ! -d "$TMP/isPowerKeeper.apk.out" ]]; then
    patch "Fail: không decompile được PowerKeeper.apk"
    rm -rf "$TMP"
    exit 1
fi

Smali1=$(find "$TMP/isPowerKeeper.apk.out" -type f -name MilletConfig.smali | head -n1)
Smali2=$(find "$TMP/isPowerKeeper.apk.out" -type f -name GmsObserver.smali | head -n1)
patched=0

# 3. MilletConfig: IS_INTERNATIONAL_BUILD -> IS_MIUI (luôn true)
if [[ -n $Smali1 ]] && grep -q 'IS_INTERNATIONAL_BUILD:Z' "$Smali1"; then
    sed -i 's/Lmiui\/os\/Build;->IS_INTERNATIONAL_BUILD:Z/Lmiui\/os\/Build;->IS_MIUI:Z/g' "$Smali1"
    patched=1
else
    patch "Cảnh báo: không vá được MilletConfig"
fi

# 4. GmsObserver: isGmsControlEnabled()Z luôn trả về false (gms.ini)
if [[ -n $Smali2 ]]; then
    $repS "$tar1" "$Smali2"
    if grep -q 'const/4 p0, 0x0' "$Smali2"; then
        patched=1
    else
        patch "Cảnh báo: gms.ini không khớp GmsObserver.smali (isGmsControlEnabled chưa được vá)"
    fi
else
    patch "Cảnh báo: không thấy GmsObserver.smali"
fi

if [[ $patched -eq 0 ]]; then
    patch "Không vá được gì, giữ nguyên PowerKeeper.apk gốc"
    rm -rf "$TMP"
    exit 1
fi

# 5. Build lại và thay vào ROM
PowerKeeper=$(basename "$isPowerKeeper")
$APKEDITOR b -f -i "$TMP/isPowerKeeper.apk.out" -o "$TMP/final/$PowerKeeper" >/dev/null 2>&1

if [[ -f "$TMP/final/$PowerKeeper" && -n $isPowerKeeperDIR && $isPowerKeeperDIR == "$MAIN_FOLDER"/* ]]; then
    rm -rf "$isPowerKeeperDIR"/*
    cp -rf "$TMP/final/$PowerKeeper" "$isPowerKeeperDIR/"
    rm -rf "$TMP"
    patch "Done"
else
    patch "Fail: không build lại được PowerKeeper.apk, giữ nguyên bản gốc"
    rm -rf "$TMP"
    exit 1
fi