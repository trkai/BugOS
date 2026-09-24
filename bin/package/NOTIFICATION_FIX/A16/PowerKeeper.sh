work_dir=$(pwd)
source $work_dir/functions.sh
MAIN_FOLDER="$work_dir/build/baserom/images"
repS="python3 $work_dir/bin/strRep.py"
deviceTYPE=$(cat $work_dir/bin/ddevice/device_type.txt)
APKEDITOR="java -jar $work_dir/bin/apktool/apke.jar"

patch "Patching PowerKeeper"

#ready for patch
mkdir -p $work_dir/apk_temp

isPowerKeeperDIR=$(find "$MAIN_FOLDER" -type d -name "PowerKeeper")
isPowerKeeper=$(find "$MAIN_FOLDER" -type f -name "PowerKeeper.apk")

if [ -z "$isPowerKeeper" ]; then
    warn "PowerKeeper.apk not found in this ROM, skipping PowerKeeper patch."
    rm -rf $work_dir/apk_temp
    patch "Done"
    exit 0
fi

$APKEDITOR d -t raw -f -no-dex-debug -i $isPowerKeeper -o $work_dir/apk_temp/isPowerKeeper.apk.out >/dev/null 2>&1

if [ ! -d "$work_dir/apk_temp/isPowerKeeper.apk.out" ]; then
    warn "Failed to decompile PowerKeeper.apk, skipping patch."
    rm -rf $work_dir/apk_temp
    patch "Done"
    exit 0
fi

Smali1=$(find "$work_dir/apk_temp/isPowerKeeper.apk.out" -type f -name MilletConfig.smali)
Smali2=$(find "$work_dir/apk_temp/isPowerKeeper.apk.out" -type f -name GmsObserver.smali)
tar1="$work_dir/bin/package/NOTIFICATION_FIX/A16/patch/gms.ini"

patched_any=false

if [ -n "$Smali1" ]; then
    if grep -q "IS_INTERNATIONAL_BUILD:Z" "$Smali1"; then
        sed -i 's/Lmiui\/os\/Build;->IS_INTERNATIONAL_BUILD:Z/Lmiui\/os\/Build;->IS_MIUI:Z/g' "$Smali1"
        info "Patched MilletConfig.smali"
        patched_any=true
    else
        warn "MilletConfig.smali found but no matching string, skipping this sub-patch."
    fi
else
    warn "MilletConfig.smali not found in PowerKeeper.apk, skipping this sub-patch."
fi

if [ -n "$Smali2" ]; then
    if [ -f "$tar1" ]; then
        $repS "$tar1" "$Smali2"
        info "Patched GmsObserver.smali"
        patched_any=true
    else
        warn "gms.ini patch file not found at $tar1, skipping GmsObserver patch."
    fi
else
    warn "GmsObserver.smali not found in PowerKeeper.apk, skipping this sub-patch."
fi

if [ "$patched_any" = false ]; then
    warn "No sub-patch applied to PowerKeeper.apk, aborting rebuild to avoid unnecessary changes."
    rm -rf $work_dir/apk_temp
    patch "Done"
    exit 0
fi

#Finishing
PowerKeeper=$(basename $isPowerKeeper)
mkdir -p $work_dir/apk_temp/final
$APKEDITOR b -f -i $work_dir/apk_temp/isPowerKeeper.apk.out -o $work_dir/apk_temp/final/$PowerKeeper >/dev/null 2>&1

if [ -f "$work_dir/apk_temp/final/$PowerKeeper" ]; then
    rm -rf $isPowerKeeperDIR/*
    cp -rf $work_dir/apk_temp/final/$PowerKeeper $isPowerKeeperDIR
    info "PowerKeeper.apk rebuilt and replaced successfully."
else
    error "Failed to rebuild PowerKeeper.apk! Keeping original APK, no changes applied."
fi

rm -rf $work_dir/apk_temp
patch "Done"
