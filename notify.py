import os
import sys
import json
import requests
import random
import string

# Đảm bảo mã hóa UTF-8 cho stdout và stderr
if hasattr(sys.stdout, 'reconfigure'):
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass
if hasattr(sys.stderr, 'reconfigure'):
    try:
        sys.stderr.reconfigure(encoding='utf-8')
    except Exception:
        pass

def read_file_if_exists(path, default=""):
    if os.path.exists(path):
        try:
            with open(path, "r", encoding="utf-8") as f:
                val = f.read().strip()
                return val if val else default
        except Exception:
            return default
    return default

def get_progress_text(status):
    status = status.lower()
    percent_map = {
        'start': 5,
        'download': 20,
        'unpack': 35,
        'build': 55,
        'pack': 75,
        'upload': 95,
    }
    if status == 'success':
        return "✅ Hoàn tất [ 100% ]"
    if status == 'fail':
        return "❌ Thất bại"
    if status in percent_map:
        return f"[ {percent_map[status]}% ]"
    return status.upper()

def is_available(value):
    if not value:
        return False
    val_lower = str(value).strip().lower()
    if val_lower in ["", "chưa rõ", "unknown", "đang xác định...", "⏳ đang quét..."]:
        return False
    return True

def upload_to_archive(file_path, build_id):
    """Upload file ROM lên archive.org."""
    if not file_path or not os.path.exists(file_path):
        print(f"Lỗi: Không tìm thấy file để upload lên archive.org: {file_path}")
        return None

    access_key = os.environ.get("ARCHIVE_ACCESS_KEY")
    secret_key = os.environ.get("ARCHIVE_SECRET_KEY")

    if not access_key or not secret_key:
        print("Lỗi: Thiếu API Keys của Archive.org (ARCHIVE_ACCESS_KEY và ARCHIVE_SECRET_KEY)")
        return None

    try:
        import internetarchive
    except ImportError:
        print("Lỗi: Thư viện 'internetarchive' chưa cài đặt. Hãy thêm vào build.yml")
        return None

    try:
        file_name = os.path.basename(file_path)
        # Tạo định danh duy nhất cho file tải lên (chỉ dùng chữ thường, số, dấu gạch dưới)
        identifier = f"bugos_rom_{build_id}".lower()
        
        print(f"Đang upload {file_name} lên archive.org với định danh: {identifier}...")
        
        # Đẩy file lên Archive.org
        internetarchive.upload(
            identifier,
            files=[file_path],
            access_key=access_key,
            secret_key=secret_key,
            metadata={'title': f'BugOS ROM Build {build_id}', 'mediatype': 'software'},
            retries=3
        )
        
        # Trích xuất link tải trực tiếp
        download_link = f"https://archive.org/download/{identifier}/{file_name}"
        print(f"Upload thành công! Link tải: {download_link}")
        return download_link

    except Exception as e:
        print(f"Lỗi khi upload lên archive.org: {e}")
        return None

def build_message(status, rom_link, build_id, builder_name):
    progress_text = get_progress_text(status)
    
    device_name = read_file_if_exists("bin/ddevice/device_name.txt", "Thiết bị Xiaomi")
    
    codename = read_file_if_exists("bin/ddevice/device_code.txt").upper()
    if not codename:
        codename = read_file_if_exists("bin/ddevice/device_model.txt").upper()

    xiaomi_version = read_file_if_exists("bin/ddevice/rom_version.txt", "Không rõ bản dựng")
    version_tool = read_file_if_exists("Version", "1.1")
    builder_text = builder_name if builder_name else "iabi"

    lines = [
        "👾 TIẾN TRÌNH BUILD ROM",
        "━━━━━━━━━━━━━━━━━━",
        f"👤 Người thực hiện: {builder_text}",
        f"🛠 Phiên bản: BugOS {version_tool}",
        f"📱 Device: {device_name}",
        f"📍 Codename: {codename}",
        f"💿 Hệ điều hành: {xiaomi_version}",
        "━━━━━━━━━━━━━━━━━━",
        f"📈 Tiến trình: {progress_text}",
        f"🆔 Build ID: {build_id}",
        f"🔗 Base ROM (Nguồn): <a href='{rom_link}'>Link</a>"
    ]

    return "\n".join(lines)

def send_notification(status, repo_name, rom_link, channel_id, bot_token, msg_id=None,
                       build_id="Unknown", builder_name="", builder_id="", archive_link=""):
    is_success = status.lower() == 'success'
    message = build_message(status, rom_link, build_id, builder_name)

    payload = {
        "text": message,
        "parse_mode": "HTML",
        "disable_web_page_preview": True
    }

    # Nếu thành công, thêm nút duyệt (Approve) và nút tải ROM (nếu có).
    if is_success:
        buttons = []
        if is_available(archive_link):
             buttons.append([{"text": "⬇️ Tải ROM", "url": archive_link}])
        # Thêm nút bấm Duyệt (Approve).
        # callback_data chứa thông tin định tuyến để gửi vào channel
        buttons.append([{"text": "✅ Duyệt & Gửi vào Nhóm", "callback_data": f"approve_rom_{build_id}"}])
        
        payload["reply_markup"] = json.dumps({"inline_keyboard": buttons})
    else:
         # Nếu đang trong tiến trình thì không có nút
         pass

    # Luôn gửi/cập nhật tin nhắn cho cá nhân (builder_id), không gửi trực tiếp lên channel.
    target_chat_id = builder_id
    use_msg_id = msg_id

    if not is_available(target_chat_id):
        print("Lỗi: Không tìm thấy builder_id (TELEGRAM_OWNER_ID) để gửi báo cáo.")
        return

    payload["chat_id"] = target_chat_id

    if use_msg_id:
        url = f"https://api.telegram.org/bot{bot_token}/editMessageText"
        payload["message_id"] = use_msg_id
    else:
        url = f"https://api.telegram.org/bot{bot_token}/sendMessage"

    try:
        response = requests.post(url, json=payload)
        response.raise_for_status()
        res_data = response.json()
        new_msg_id = res_data.get('result', {}).get('message_id')

        # Cập nhật ID tin nhắn cho các tiến trình cập nhật tiếp theo (trừ khi là tin nhắn duyệt)
        if not is_success and not use_msg_id and new_msg_id and "GITHUB_ENV" in os.environ:
            with open(os.environ["GITHUB_ENV"], "a", encoding="utf-8") as f:
                f.write(f"TELEGRAM_MSG_ID={new_msg_id}\n")

    except Exception as e:
        print(f"Lỗi khi gửi thông báo: {e}")

if __name__ == "__main__":
    if len(sys.argv) < 4:
        sys.exit(1)

    status = sys.argv[1]
    repo_name = sys.argv[2]
    rom_link = sys.argv[3]
    prefix = sys.argv[4] if len(sys.argv) > 4 else "build"
    builder_name = sys.argv[5] if len(sys.argv) > 5 else ""
    builder_id = sys.argv[6] if len(sys.argv) > 6 else ""
    
    archive_link = sys.argv[7] if len(sys.argv) > 7 and sys.argv[7] else os.environ.get("ARCHIVE_LINK", "")
    rom_zip_path = sys.argv[8] if len(sys.argv) > 8 and sys.argv[8] else os.environ.get("ROM_ZIP_PATH", "")

    bot_token = os.environ.get("TELEGRAM_BOT_TOKEN")
    channel_id = os.environ.get("TELEGRAM_CHANNEL_ID")
    msg_id = os.environ.get("TELEGRAM_MSG_ID")
    build_id = os.environ.get("TELEGRAM_BUILD_ID")

    if not build_id:
        random_digits = ''.join(random.choices(string.digits, k=8))
        build_id = f"{prefix}_{random_digits}"
        if "GITHUB_ENV" in os.environ:
            with open(os.environ["GITHUB_ENV"], "a", encoding="utf-8") as f:
                f.write(f"TELEGRAM_BUILD_ID={build_id}\n")

    if not bot_token:
        sys.exit(1)

    # Đã sửa lại tên biến thành uploaded_link
    if status.lower() == 'success' and not is_available(archive_link) and rom_zip_path:
        uploaded_link = upload_to_archive(rom_zip_path, build_id)
        if uploaded_link:
            archive_link = uploaded_link
            if "GITHUB_ENV" in os.environ:
                with open(os.environ["GITHUB_ENV"], "a", encoding="utf-8") as f:
                    f.write(f"ARCHIVE_LINK={uploaded_link}\n")

    send_notification(status, repo_name, rom_link, channel_id, bot_token, msg_id, build_id, builder_name, builder_id, archive_link)
    
