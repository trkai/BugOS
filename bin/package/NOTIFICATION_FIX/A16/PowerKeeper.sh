work_dir=$(pwd)
source $work_dir/functions.sh
MAIN_FOLDER="$work_dir/build/baserom/images"
repS="python3 $work_dir/bin/strRep.py"
deviceTYPE=$(cat $work_dir/bin/ddevice/device_type.txt)
APKEDITOR="java -jar $work_dir/bin/apktool/apke.jar"
repS="python3 $work_dir/bin/strRep.py"


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

if [ -n "$Smali1" ]; then
    sed -i 's/Lmiui\/os\/Build;->IS_INTERNATIONAL_BUILD:Z/Lmiui\/os\/Build;->IS_MIUI:Z/g' $Smali1
else
    warn "MilletConfig.smali not found in PowerKeeper.apk, skipping this sub-patch."
fi

if [ -n "$Smali2" ]; then
    $repS $tar1 $Smali2
else
    warn "GmsObserver.smali not found in PowerKeeper.apk, skipping this sub-patch."
fi

#Finishing
PowerKeeper=$(basename $isPowerKeeper)
$APKEDITOR b -f -i $work_dir/apk_temp/isPowerKeeper.apk.out -o $work_dir/apk_temp/final/$PowerKeeper >/dev/null 2>&1

if [ -f "$work_dir/apk_temp/final/$PowerKeeper" ]; then
    rm -rf $isPowerKeeperDIR/*
    cp -rf $work_dir/apk_temp/final/$PowerKeeper $isPowerKeeperDIR
fi

rm -rf $work_dir/apk_temp
patch "Done"
