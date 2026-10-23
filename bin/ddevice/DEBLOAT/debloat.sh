WORK_DIR=$(pwd)
source $WORK_DIR/functions.sh

debloat_apps=()
while IFS= read -r line || [[ -n "$line" ]]; do
    line=$(printf '%s' "$line" | tr -d '\r')
    # Bỏ dòng trống và chú thích: một dòng trống sẽ thành pattern "**" và xoá sạch ROM
    [[ -z "${line// }" || "$line" == \#* ]] && continue
    debloat_apps+=("$line")
done < $WORK_DIR/bin/ddevice/DEBLOAT/APPLIST.txt

rm -rf $WORK_DIR/build/baserom/images/product/etc/auto-install*
rm -rf $WORK_DIR/build/baserom/images/product/app/Updater
rm -rf $WORK_DIR/build/baserom/images/product/etc/permissions/cn.google.services.xml

# Dọn dẹp các tệp log, cache, video hướng dẫn và firmware rác chiếm dung lượng
info "Purging system caches, demo videos & tracking dumps..."
for part in system product vendor system_ext odm; do
    pdir="$WORK_DIR/build/baserom/images/$part"
    if [ -d "$pdir" ]; then
        rm -rf "$pdir"/media/video/* 2>/dev/null
        rm -rf "$pdir"/media/theme_preview/* 2>/dev/null
        rm -rf "$pdir"/etc/recovery-resource.dat 2>/dev/null
        rm -rf "$pdir"/recovery-from-boot.p 2>/dev/null
        find "$pdir" -type f \( -name "*.log" -o -name "*.bak" -o -name "*_old" \) -delete 2>/dev/null
    fi
done

for debloat_app in "${debloat_apps[@]}"; do
    # Find the app directory in both system and product directories
    app_dirs=$(find build/baserom/images/system/ -type d -name "*$debloat_app*" 2>/dev/null)
    app_dirs2=$(find build/baserom/images/product/ -type d -name "*$debloat_app*" 2>/dev/null)
    app_dirs3=$(find build/baserom/images/mi_ext -type d -name "*$debloat_app*" 2>/dev/null)
    # Combine the directories into one list
    all_app_dirs=($app_dirs $app_dirs2 $app_dirs3)

    for app_dir in "${all_app_dirs[@]}"; do
        # Check if the directory exists before removing
        if [[ -d "$app_dir" ]]; then
            info "Removing directory: $app_dir"
            rm -rf "$app_dir"
        fi
    done
done
info "Debloat Done"

# ---------------------------------------------------------------------------
# Xoá theo TÊN GÓI (package thật trong AndroidManifest) - dùng cho các app mà
# tên thư mục không đoán được (vd com.miui.video có thể nằm ở MIUIVideo/MiVideo).
# ---------------------------------------------------------------------------
PKG_LIST="$WORK_DIR/bin/ddevice/DEBLOAT/APPLIST_PKGS.txt"
PKG_TOOL="$WORK_DIR/bin/ddevice/DEBLOAT/debloat_pkgs.py"
if [ -f "$PKG_LIST" ] && [ -f "$PKG_TOOL" ]; then
    info "Debloat theo package name..."
    python3 "$PKG_TOOL" "$WORK_DIR/build/baserom/images" "$PKG_LIST" || warn "Debloat theo package gặp lỗi (bỏ qua)."
fi
info "Debloat Done (package)"

