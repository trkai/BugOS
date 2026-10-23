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
  mods "Added GMS Done"
else
  mods "Detected Xiaomi Global ROM! Skipped Added GMS."
fi
