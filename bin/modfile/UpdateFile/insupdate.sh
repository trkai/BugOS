work_dir=$(pwd)
source $work_dir/functions.sh

mods "Starting Update File..."
TARGET_DIR="$work_dir/bin/modfile/UpdateFile"

# ---------------------------------------------------------------------------
# THỨ TỰ CHẠY LÀ BẮT BUỘC, KHÔNG ĐƯỢC ĐỔI:
#   4 mod dưới đây đều giải nén rồi đóng gói lại Settings.apk:
#     Settings_ROMInformation  -> THAY toàn bộ APK bằng bản Kashi đóng gói sẵn
#     Settings_GoogleShowUpCN  -> patch smali MiuiSettings (hiện menu Google)
#     Settings_GlobalFixTheme  -> patch smali theme
#     Settings_AdvancedTexture -> patch smali blur/texture
#   Trước đây vòng lặp dùng `find` (thứ tự không xác định) nên nếu
#   Settings_ROMInformation chạy SAU thì nó ghi đè và xoá sạch mọi patch smali
#   vừa làm -> menu Google không xuất hiện dù đã patch.
# ---------------------------------------------------------------------------
PRIORITY=( "Settings_ROMInformation" )

scripts=()
for d in "${PRIORITY[@]}"; do
    [ -f "$TARGET_DIR/$d/update.sh" ] && scripts+=( "$TARGET_DIR/$d/update.sh" )
done

while IFS= read -r s; do
    skip=false
    [ "$s" == "$TARGET_DIR/insupdate.sh" ] && skip=true
    for d in "${PRIORITY[@]}"; do
        [ "$s" == "$TARGET_DIR/$d/update.sh" ] && skip=true
    done
    [ "$skip" == false ] && scripts+=( "$s" )
done < <(find "$TARGET_DIR" -type f -name "*.sh" | sort)

for script in "${scripts[@]}"; do
    mods "Run: $(basename "$(dirname "$script")")"
    bash "$script"
done
