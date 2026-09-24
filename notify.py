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
        return "✅ Hoàn tất"
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

def upload_to_gofile(file_path, token=""):
    """Upload file ROM lên gofile.io."""
    if not file_path or not os.path.exists(file_path):
        print(f"Lỗi: Không tìm thấy file để upload lên gofile.io: {file_path}")
        return None

    try:
        print("Đang lấy server upload tốt nhất từ gofile.io...")
        servers_res = requests.get("https://api.gofile.io/servers", timeout=15)
        servers_res.raise_for_status()
        servers = servers_res.json().get("data", {}).get("servers", [])
        if not servers:
            return None
        server = servers[0].get("name")

        print(f"Đang upload {file_path} lên server {server}...")
        upload_url = f"https://{server}.gofile.io/contents/uploadfile"
        
        with open(file_path, "rb") as f:
            files = {"file": (os.path.basename(file_path), f)}
            data = {"token": token} if token else {}
            res = requests.post(upload_url, data=data, files=files, timeout=None)
            
        res.raise_for_status()
        res_json = res.json()

        if res_json.get("status") != "ok":
            return None

        download_page = res_json.get("data", {}).get("downloadPage")
        print(f"Upload thành công! Link tải: {download_page}")
        return download_page

    except Exception as e:
        print(f"Lỗi khi upload lên gofile.io: {e}")
        return None

def build_message(status, rom_link, build_id, builder_name):
    progress_text = get_progress_text(status)
    
    # Lấy thông tin theo đúng yêu cầu
    device_name = read_file_if_exists("bin/ddevice/device_name.txt", "Thiết bị Xiaomi")
    
    codename = read_file_if_exists("bin/ddevice/device_code.txt").upper()
    if not codename:
        codename = read_file_if_exists("bin/ddevice/device_model.txt").upper()

    xiaomi_version = read_file_if_exists("bin/ddevice/rom_version.txt", "Không rõ bản dựng")
    version_tool = read_file_if_exists("Version", "1.1")
    builder_text = builder_name if builder_name else "iabi"

    # Định dạng hiển thị dọc giống nguyên bản yêu cầu
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
                       build_id="Unknown", builder_name="", builder_id="", gofile_link=""):
    is_success = status.lower() == 'success'
    message = build_message(status, rom_link, build_id, builder_name)

    payload = {
        "text": message,
        "parse_mode": "HTML",
        "disable_web_page_preview": True
    }

    # Nút bấm Tải ROM khi có link Gofile
    if is_available(gofile_link):
        payload["reply_markup"] = json.dumps({
            "inline_keyboard": [[
                {"text": "⬇️ Tải ROM", "url": gofile_link}
            ]]
        })

    if is_success:
        target_chat_id = channel_id
        use_msg_id = None 
    else:
        target_chat_id = builder_id
        use_msg_id = msg_id

    if not is_available(target_chat_id):
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
    
    gofile_link = sys.argv[7] if len(sys.argv) > 7 and sys.argv[7] else os.environ.get("GOFILE_LINK", "")
    rom_zip_path = sys.argv[8] if len(sys.argv) > 8 and sys.argv[8] else os.environ.get("ROM_ZIP_PATH", "")
    gofile_token = os.environ.get("GOFILE_TOKEN", "")

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

    if status.lower() == 'success' and not is_available(gofile_link) and rom_zip_path:
        uploaded_link = upload_to_gofile(rom_zip_path, gofile_token)
        if uploaded_link:
            gofile_link = uploaded_link
            if "GITHUB_ENV" in os.environ:
                with op
