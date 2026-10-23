baserom="$1"
work_dir=$(pwd)
source $work_dir/functions.sh

regionTYPE=$(cat $work_dir/bin/ddevice/device_type.txt 2>/dev/null | tr -d '\r\n ')

# ---------------------------------------------------------------------------
# Android version / SDK: đọc từ nhiều build.prop, có fallback.
# Trước đây chỉ đọc đúng 1 key trong 1 file -> nếu HyperOS đổi tên key thì
# androidver.txt rỗng, và NOTIFICATION_FIX (cùng các mod khác) sẽ KHÔNG chạy
# nhánh nào cả mà không báo lỗi.
# ---------------------------------------------------------------------------
_prop_get() {
    local key="$1" f v
    for f in \
        "$work_dir/build/baserom/images/system/system/build.prop" \
        "$work_dir/build/baserom/images/product/etc/build.prop" \
        "$work_dir/build/baserom/images/system_ext/etc/build.prop" \
        "$work_dir/build/baserom/images/vendor/build.prop"; do
        [ -f "$f" ] || continue
        v=$(grep -m1 "^${key}=" "$f" 2>/dev/null | cut -d '=' -f 2 | tr -d '\r\n ')
        [ -n "$v" ] && { echo "$v"; return 0; }
    done
    return 1
}

AndroidVer=$(_prop_get ro.system.build.version.release)
[ -z "$AndroidVer" ] && AndroidVer=$(_prop_get ro.build.version.release)
sdkLevel=$(_prop_get ro.system.build.version.sdk)
[ -z "$sdkLevel" ] && sdkLevel=$(_prop_get ro.build.version.sdk)

if [ -z "$AndroidVer" ] && [ -n "$sdkLevel" ]; then
    case "$sdkLevel" in
        33) AndroidVer="13" ;; 34) AndroidVer="14" ;; 35) AndroidVer="15" ;;
        36) AndroidVer="16" ;; 37) AndroidVer="17" ;; *) AndroidVer="" ;;
    esac
fi

if [ -z "$AndroidVer" ]; then
    case "$(cat $work_dir/bin/ddevice/rom_os.txt 2>/dev/null | tr -d '\r\n ')" in
        OS1) AndroidVer="14" ;;
        OS2) AndroidVer="15" ;;
        OS3) AndroidVer="16" ;;
        OS4) AndroidVer="17" ;;
    esac
fi

if [ -z "$AndroidVer" ]; then
    warn "Không xác định được Android version (sdk='$sdkLevel') -> mặc định 16"
    AndroidVer="16"
fi
info "AndroidVer=$AndroidVer | sdkLevel=${sdkLevel:-?}"

device_code=$(cat $work_dir/bin/ddevice/device_code.txt 2>/dev/null | tr -d '\r\n')
[ -z "$device_code" ] && device_code=$(cat $work_dir/bin/ddevice/device_f.txt 2>/dev/null | tr -d '\r\n')
[ -z "$device_code" ] && device_code="YourDevice"

name=$(cat $work_dir/bin/ddevice/device_name.txt 2>/dev/null | tr -d '\r\n')
[ -z "$name" ] && name=$(cat $work_dir/bin/ddevice/name_devices.txt 2>/dev/null | tr -d '\r\n')
[ -z "$name" ] && name="Xiaomi Device"
base_rom_code=$(cat $work_dir/bin/ddevice/base_rom_code.txt)
rom_os=$(cat $work_dir/bin/ddevice/rom_os.txt)
starxVER=$(cat $work_dir/Version)
systemtype=$(cat $work_dir/bin/ddevice/fstype.txt)

if grep -q "ro.build.ab_update=true" build/baserom/images/vendor/build.prop; then
echo "VAB" > $work_dir/bin/script2flash/META-INF/Data/Structure
else
echo "Non-VAB" > $work_dir/bin/script2flash/META-INF/Data/Structure
fi

if [ -f $work_dir/build/baserom/images/vendor/etc/init/hw/init.qcom.rc ]; then
   echo "Snapdragon" > $work_dir/bin/script2flash/META-INF/Data/Chip
else
   echo "Mediatek" > $work_dir/bin/script2flash/META-INF/Data/Chip
fi 

echo "$os_type" > $work_dir/bin/ddevice/os_type.txt
echo "$AndroidVer" > $work_dir/bin/ddevice/androidver.txt
echo "$sdkLevel" > $work_dir/bin/ddevice/sdkLevel.txt
#Parse Data
echo "$AndroidVer" > $work_dir/bin/script2flash/META-INF/Data/AndroidVer
echo "$base_rom_code" > $work_dir/bin/script2flash/META-INF/Data/RomBased
echo "$starxVER" > $work_dir/bin/script2flash/META-INF/Data/Version
echo "$regionTYPE" > $work_dir/bin/script2flash/META-INF/Data/Region
echo "$name" > $work_dir/bin/script2flash/META-INF/Data/DeviceName
echo "$systemtype" > $work_dir/bin/script2flash/META-INF/Data/Types


echo "------------------ BugOS BuildInfo ---------------------"
echo "- Device Name: $name"
echo "- Codename: $device_code"
echo "- Xiaomi Version: $rom_os"  
echo "- BuildRegion: $regionTYPE"
echo "- Android: $AndroidVer"                                      
echo "- Base ROM Code: $base_rom_code"                                                                        
echo "- BuildTool Version: $starxVER"
echo "- OS Type: $systemtype"
echo "--------------------------------------------------------"
