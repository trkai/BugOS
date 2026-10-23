work_dir=$(pwd)
source $work_dir/functions.sh
rom_os=$(cat $work_dir/bin/ddevice/rom_os.txt 2>/dev/null | tr -d '\r\n ')
androidVER=$(cat $work_dir/bin/ddevice/androidver.txt 2>/dev/null | tr -d '\r\n ')
regionTYPE=$(cat $work_dir/bin/ddevice/device_type.txt 2>/dev/null | tr -d '\r\n ')
base_rom_code=$(cat $work_dir/bin/ddevice/base_rom_code.txt 2>/dev/null | tr -d '\r\n ')
MAIN_FOLDER="$work_dir/build/baserom/images"

# Region rỗng hoặc dính CRLF -> tự suy ra từ mã ROM, tránh bỏ qua GMS trong im lặng
if [ -z "$regionTYPE" ]; then
  if echo "$base_rom_code" | grep -qiE 'CNXM|_CN|CN$'; then
    regionTYPE="China"
  else
    regionTYPE="Global"
  fi
  mods "Region trống -> tự nhận diện: $regionTYPE (theo $base_rom_code)"
fi

if [ "$(cfg_get GMS_DEFAULT true)" != "true" ]; then
  mods "GMS_DEFAULT=false trong config.env -> bỏ qua bước thêm GMS."
elif [[ $regionTYPE == "China" ]]; then
  mods "Adding GMS & Enabling Google Services by default..."
  cp -rf $work_dir/bin/modfile/Universal/gmsservices/product/* $work_dir/build/baserom/images/product/
  cp -rf $work_dir/bin/modfile/Universal/gmsservices/system_ext/* $work_dir/build/baserom/images/system_ext/
  
  # Xóa toàn bộ các tệp cấu hình hạn chế GMS của China ROM
  find "$MAIN_FOLDER" -type f \( \
      -name "cn.google.services.xml" -o \
      -name "services.cn.google.xml" -o \
      -name "cn_feature.xml" \
  \) -exec rm -f {} + 2>/dev/null

  # Kích hoạt sẵn Dịch vụ Google trong toàn bộ build.prop
  for prop in "$MAIN_FOLDER/system/system/build.prop" "$MAIN_FOLDER/product/etc/build.prop" "$MAIN_FOLDER/system_ext/etc/build.prop"; do
    if [ -f "$prop" ]; then
      sed -i \
          -e '/^ro\.miui\.has_gmscore=/d' \
          -e '/^persist\.sys\.miui\.google\.services=/d' \
          -e '/^persist\.sys\.google\.enable=/d' \
          -e '/^ro\.com\.google\.clientidbase=/d' \
          -e '/^ro\.opa\.eligible_device=/d' "$prop"

      [ -n "$(tail -c1 "$prop")" ] && echo "" >> "$prop"

      {
          echo "ro.miui.has_gmscore=1"
          echo "persist.sys.miui.google.services=1"
          echo "persist.sys.google.enable=1"
          echo "ro.com.google.clientidbase=android-xiaomi"
          echo "ro.opa.eligible_device=true"
      } >> "$prop"
    fi
  done

  if [[ $androidVER == "13" ]]; then 
    cp -rf $work_dir/bin/modfile/Universal/gmsservices/maps/A13/framework $work_dir/build/baserom/images/product/
  elif [[ $androidVER == "14" ]]; then
    cp -rf $work_dir/bin/modfile/Universal/gmsservices/maps/A14/framework $work_dir/build/baserom/images/product/
  else
    cp -rf $work_dir/bin/modfile/Universal/gmsservices/maps/A15/framework $work_dir/build/baserom/images/product/
  fi

  # ---------------------------------------------------------------------------
  # Bật Dịch vụ Google MỘT LẦN sau khi flash.
  # build.prop chỉ được init áp dụng khi /data/property/persist.* CHƯA có giá trị,
  # nên flash đè (không factory reset) sẽ giữ giá trị 0 cũ -> toggle vẫn tắt và
  # người dùng phải bật tay. Script dưới đây chạy ở post-fs-data, chỉ set prop
  # đúng 1 lần (đánh dấu bằng file), sau đó người dùng tắt được bình thường.
  # ---------------------------------------------------------------------------
  INIT_DIR="$MAIN_FOLDER/system/system/etc/init"
  SYSBIN_DIR="$MAIN_FOLDER/system/system/bin"
  if [ -d "$INIT_DIR" ] && [ -d "$SYSBIN_DIR" ]; then
      cat > "$SYSBIN_DIR/bugos_gms_once.sh" << 'EOS'
#!/system/bin/sh
# BugOS: bật Dịch vụ Google mặc định đúng 1 lần sau khi flash
MARK=/data/system/bugos_gms_once.done
[ -f "$MARK" ] && exit 0
setprop persist.sys.miui.google.services 1 || exit 0
setprop persist.sys.google.enable 1
mkdir -p /data/system 2>/dev/null
touch "$MARK" 2>/dev/null
# Dấu hiệu để kiểm tra: getprop persist.sys.bugos.gms_init  ->  1
setprop persist.sys.bugos.gms_init 1
exit 0
EOS
      chmod 755 "$SYSBIN_DIR/bugos_gms_once.sh"

      cat > "$INIT_DIR/bugos_gms.rc" << 'EOR'
# BugOS - bật Dịch vụ Google mặc định sau khi flash (kể cả flash đè)
on post-fs-data
    exec -- /system/bin/sh /system/bin/bugos_gms_once.sh
EOR
      chmod 644 "$INIT_DIR/bugos_gms.rc"
      mods "Đã thêm bugos_gms.rc + bugos_gms_once.sh (bật Google services 1 lần)"
  else
      warn "Không thấy $INIT_DIR hoặc $SYSBIN_DIR -> bỏ qua script bật GMS."
  fi

  mods "Added GMS Done"
else
  mods "Detected Xiaomi Global ROM! Skipped Added GMS."
fi
