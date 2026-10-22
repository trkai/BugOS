work_dir=$(pwd)
source $work_dir/functions.sh
rom_os=$(cat $WORK_DIR/bin/ddevice/rom_os.txt)
regionTYPE=$(cat $work_dir/bin/ddevice/device_type.txt)
androidVER=$(cat $WORK_DIR/bin/ddevice/androidver.txt)
BuildProp1="$work_dir/build/baserom/images/system/system/build.prop"
BuildProp2="$work_dir/build/baserom/images/product/etc/build.prop"
BuildProp3="$work_dir/build/baserom/images/system_ext/etc/build.prop"
BuildProp4="$work_dir/build/baserom/images/vendor/build.prop"


disable_memory_extenstion() {
    mods "Disable Memory Ext"
    BuildProp1="$work_dir/build/baserom/images/system/system/build.prop"
	BuildProp2="$work_dir/build/baserom/images/product/etc/build.prop"
	BuildProp3="$work_dir/build/baserom/images/system_ext/etc/build.prop"
	BuildProp4="$work_dir/build/baserom/images/vendor/build.prop"
    sed -i "s/persist.miui.extm.enable=1/persist.miui.extm.enable=0/g" $BuildProp1
	sed -i "s/persist.miui.extm.enable=1/persist.miui.extm.enable=0/g" $BuildProp2
	sed -i "s/persist.miui.extm.enable=1/persist.miui.extm.enable=0/g" $BuildProp3
	sed -i "s/persist.miui.extm.enable=1/persist.miui.extm.enable=0/g" $BuildProp4
}

disable_privapp_control_enforce () {
    mods "Disable priv-app control enforce"
    BuildProp1="$work_dir/build/baserom/images/system/system/build.prop"
	BuildProp2="$work_dir/build/baserom/images/product/etc/build.prop"
	BuildProp3="$work_dir/build/baserom/images/system_ext/etc/build.prop"
	BuildProp4="$work_dir/build/baserom/images/vendor/build.prop"
	sed -i "s/ro.control_privapp_permissions=enforce/ro.control_privapp_permissions=/g" $BuildProp1
	sed -i "s/ro.control_privapp_permissions=enforce/ro.control_privapp_permissions=/g" $BuildProp2
	sed -i "s/ro.control_privapp_permissions=enforce/ro.control_privapp_permissions=/g" $BuildProp3
    sed -i "s/ro.control_privapp_permissions=enforce/ro.control_privapp_permissions=/g" $BuildProp4
}

disable_privapp_control_disable () {
    mods "Disable priv-app control disable"
    BuildProp1="$work_dir/build/baserom/images/system/system/build.prop"
	BuildProp2="$work_dir/build/baserom/images/product/etc/build.prop"
	BuildProp3="$work_dir/build/baserom/images/system_ext/etc/build.prop"
	BuildProp4="$work_dir/build/baserom/images/vendor/build.prop"
	sed -i "s/ro.control_privapp_permissions=disable/ro.control_privapp_permissions=/g" $BuildProp1
	sed -i "s/ro.control_privapp_permissions=disable/ro.control_privapp_permissions=/g" $BuildProp2
	sed -i "s/ro.control_privapp_permissions=disable/ro.control_privapp_permissions=/g" $BuildProp3
    sed -i "s/ro.control_privapp_permissions=disable/ro.control_privapp_permissions=/g" $BuildProp4
}

# Remove over volume alert
echo "audio.safemedia.bypass=true" >> build/baserom/images/product/etc/build.prop
echo "audio.safemedia.force=false" >> build/baserom/images/product/etc/build.prop
echo "audio.safemedia.csd.force=false" >> build/baserom/images/product/etc/build.prop

recoveryimg="$work_dir/build/baserom/images/recovery.img"
if [ -f $recoveryimg ]; then
 rm -rf $recoveryimg
else
 mods "No Found recovery.img!Skipping..."
fi

fix_themereset() {
    InitRC1=$(find $work_dir/build/baserom/images -type f -name "init.rc")
    mods "Fix theme reset"
    sed -i '/on boot/a\'$'\n''    chmod 0731 \/data\/system\/theme' $InitRC1
    mods "Done"
}

# Optimize RAM, ZRAM, LMK & Compaction
optimize_ram() {
    mods "Optimizing RAM, ZRAM & LMK parameters..."
    for p in "$BuildProp1" "$BuildProp2" "$BuildProp3" "$BuildProp4"; do
        if [ -f "$p" ]; then
            sed -i \
                -e '/^ro\.vendor\.qti\.sys\.fw\.bg_apps_limit=/d' \
                -e '/^ro\.vendor\.qti\.sys\.fw\.bservice_enable=/d' \
                -e '/^ro\.vendor\.qti\.sys\.fw\.bservice_limit=/d' \
                -e '/^ro\.vendor\.qti\.sys\.fw\.bservice_age=/d' \
                -e '/^ro\.config\.max_starting_bg=/d' \
                -e '/^persist\.sys\.zram_enabled=/d' \
                -e '/^ro\.zram\.mark_idle_delay_mins=/d' \
                -e '/^ro\.zram\.first_wb_delay_mins=/d' \
                -e '/^ro\.zram\.periodic_wb_delay_hours=/d' \
                -e '/^persist\.sys\.stability\.check_idle=/d' "$p"

            [ -n "$(tail -c1 "$p")" ] && echo "" >> "$p"

            {
                echo "ro.vendor.qti.sys.fw.bg_apps_limit=64"
                echo "ro.vendor.qti.sys.fw.bservice_enable=true"
                echo "ro.vendor.qti.sys.fw.bservice_limit=16"
                echo "ro.vendor.qti.sys.fw.bservice_age=5000"
                echo "ro.config.max_starting_bg=8"
                echo "persist.sys.zram_enabled=1"
                echo "ro.zram.mark_idle_delay_mins=30"
                echo "ro.zram.first_wb_delay_mins=120"
                echo "ro.zram.periodic_wb_delay_hours=24"
                echo "persist.sys.stability.check_idle=true"
            } >> "$p"
        fi
    done
}

disable_memory_extenstion
disable_privapp_control_enforce
disable_privapp_control_disable
optimize_ram
fix_themereset