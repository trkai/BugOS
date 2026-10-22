#!/bin/bash
# BugOS - NOTIFICATION_FIX A16 - services.jar (Dynamic FCM Wake Filter 0x20)
# Ported from HyperOS FCM Notification Fix (biplobsd)
work_dir=$(pwd)
source $work_dir/functions.sh 2>/dev/null || true
MAIN_FOLDER="$work_dir/build/baserom/images"
JAR_NAME="services.jar"
JAR_SRC="$MAIN_FOLDER/system/system/framework/$JAR_NAME"
if [[ ! -f "$JAR_SRC" ]]; then
    JAR_SRC=$(find "$MAIN_FOLDER" -type f -name "$JAR_NAME" 2>/dev/null | head -n1)
fi
JAR_TMP="$work_dir/jar_temp_services"
JAR_OUT="$JAR_TMP/$JAR_NAME.out"
bak="java -jar $work_dir/bin/apktool/baksmaliv2.jar d --api 36"
sma="java -jar $work_dir/bin/apktool/smaliv2.jar a --api 36"
FCM_FILTER_SRC="$work_dir/bin/package/NOTIFICATION_FIX/A16/patch/FcmWakeFilter.smali"
PATCH_PY="$work_dir/bin/package/NOTIFICATION_FIX/patch_fcm_surgical.py"

decompile_jar() {
    patch "$JAR_NAME"
    mkdir -p "$JAR_TMP"
    sudo cp -f "$JAR_SRC" "$JAR_TMP/"
    sudo chown "$(whoami)" "$JAR_TMP/$JAR_NAME" 2>/dev/null || true
    rm -rf "$JAR_OUT"
    unzip -o "$JAR_TMP/$JAR_NAME" -d "$JAR_OUT" >/dev/null 2>&1
    [[ -d $JAR_OUT ]] || return 1
    rm -f "$JAR_TMP/$JAR_NAME"
    local dex
    for dex in "$JAR_OUT"/*.dex; do
        [[ -f $dex ]] || continue
        $bak "$dex" -o "$dex.out"
        [[ -d "$dex.out" ]] && rm -f "$dex"
    done
    compgen -G "$JAR_OUT/*.dex.out" >/dev/null
}

recompile_jar() {
    cd "$JAR_OUT" || return 1
    local fld out
    for fld in ./*.out; do
        [[ -d $fld ]] || continue
        out="${fld%.out}"
        $sma "$fld" -o "$out"
        [[ -f $out ]] && rm -rf "$fld"
    done
    if compgen -G "$JAR_OUT/*.out" >/dev/null; then
        cd "$work_dir"
        return 1
    fi
    rm -f "$JAR_TMP/${JAR_NAME}_notal" "$JAR_TMP/$JAR_NAME"
    7za a -tzip -mx=0 "$JAR_TMP/${JAR_NAME}_notal" "$JAR_OUT/." >/dev/null 2>&1
    zipalign 4 "$JAR_TMP/${JAR_NAME}_notal" "$JAR_TMP/$JAR_NAME"
    cd "$work_dir"
    [[ -f "$JAR_TMP/$JAR_NAME" ]] || return 1
    sudo cp -rf "$JAR_TMP/$JAR_NAME" "$JAR_SRC"
    rm -rf "$JAR_OUT" "$JAR_TMP"
}

mkdir -p "$JAR_TMP"

if [[ ! -f $JAR_SRC ]]; then
    patch "Không thấy $JAR_NAME, bỏ qua"
    exit 0
fi

if ! decompile_jar; then
    patch "Fail: không decompile được $JAR_NAME"
    rm -rf "$JAR_OUT" "$JAR_TMP"
    exit 0
fi

# 1. Tiêm FcmWakeFilter.smali vào cây smali
target_carrier=$(find "$JAR_OUT" -type d -path "*/com/android/server/am" | head -n1)
if [[ -z "$target_carrier" ]]; then
    first_dex=$(find "$JAR_OUT" -maxdepth 1 -type d -name "*.dex.out" | head -n1)
    target_carrier="$first_dex/com/android/server/am"
    mkdir -p "$target_carrier"
fi
if [[ -f "$FCM_FILTER_SRC" && -d "$target_carrier" ]]; then
    cp -f "$FCM_FILTER_SRC" "$target_carrier/FcmWakeFilter.smali"
    patch "Đã tiêm FcmWakeFilter.smali vào services.jar"
fi

# 2. Gọi python patcher để tiêm hook applyFlags vào broadcastIntentLockedTraced
python3 "$PATCH_PY" services "$JAR_OUT"

if recompile_jar; then
    patch "Vá services.jar (FCM Wake Filter) thành công!"
else
    patch "Fail: không build lại được $JAR_NAME, giữ nguyên bản gốc"
    rm -rf "$JAR_TMP"
fi
