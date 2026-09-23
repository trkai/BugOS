import os
import sys
import json
import requests
import random
import string

# Đảm bảo mã hóa UTF-8 cho stdout và stderr để tránh crash trên terminal Windows/không hỗ trợ tiếng Việt
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
    val_lower = value.strip().lower()
    if val_lower in ["", "chưa rõ", "unknown", "đang xác định...", "⏳ đang quét..."]:
        return False
    return True

def upload_to_gofile(file_path, token=""):
    """Upload file ROM lên gofile.io. Trả về link downloadPage nếu thành công, None nếu lỗi."""
    if not file_path or not os.path.exists(file_path):
        print(f"Lỗi: Không tìm thấy file để upload lên gofile.io: {file_path}")
        return None

    try:
        print("Đang lấy server upload tốt nhất từ gofile.io...")
        servers_res = requests.get("https://api.gofile.io/servers", timeout=15)
        servers_res.raise_for_status()
        servers = servers_res.json().get("data", {}).get("servers", [])
        if not servers:
            print("Lỗi: Không lấy được server upload từ gofile.io")
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
            print(f"Lỗi upload gofile.io: {res_json}")
            return None

        download_page = res_json.get("data", {}).get("downloadPage")
        print(f"Upload thành công! Link tải: {download_page}")
        return download_page

    except Exception as e:
        print(f"Lỗi khi upload lên gofile.io: {e}")
        return None

def build_message(status, rom_link, build_id, builder_name):
    progress_text = get_progress_text(status)

    device_name = read_file_if_exists("bin/ddevice/device_name.txt")
    if not device_name:
        device_name = read_file_if_exists("bin/ddevice/name_devices.txt")

    codename = read_file_if_exists("bin/ddevice/device_code.txt")
    if not codename:
        codename = read_file_if_exists("bin/ddevice/device_model.txt")

    rom_os = read_file_if_exists("bin/ddevice/rom_os.txt")
    if not rom_os:
        rom_os = read_file_if_exists("bin/ddevice/brand_os.txt")
    if not rom_os:
        rom_os = read_file_if_exists("bin/ddevice/brand.txt")
    if rom_os in ["OS1", "OS2", "OS3"]:
        rom_os = "HyperOS"

    version_rom = read_file_if_exists("bin/ddevice/rom_version.txt")
    if not version_rom:
        version_rom = read_file_if_exists("bin/ddevice/base_rom_code.txt")
    if not version_rom:
        version_rom = read_file_if_exists("bin/ddevice/base_build_id.txt")

    android_ver = read_file_if_exists("bin/ddevice/androidver.txt")
    sdk_level = read_file_if_exists("bin/ddevice/sdkLevel.txt")
    version_tool = read_file_if_exists("Version")

    builder_text = builder_name if builder_name else "🤖 Hệ thống"

    lines = [
        "🐧 *TIẾN TRÌNH BUILD ROM*",
        "━━━━━━━━━━━━━━━━━━",
        f"👤 *Người thực hiện:* {builder_text}",
    ]

    if is_available(device_name):
        lines.append(f"📱 *Device:* `{device_name}`")
    if is_available(version_tool):
        lines.append(f"🛠️ *Phiên bản:* `BugOS {version_tool}`")
    if is_available(codename):
        lines.append(f"🔑 *Codename:* `{codename}`")

    os_parts = [p for p in [rom_os, version_rom] if is_available(p)]
    if os_parts:
        lines.append(f"💿 *Hệ điều hành:* `{'.'.join(os_parts)}`")

    android_parts = []
    if is_available(android_ver):
        android_parts.append(f"Android {android_ver}")
    if is_available(sdk_level):
        android_parts.append(f"SDK {sdk_level}")
    if android_parts:
        lines.append(f"🤖 *Android:* `{' | '.join(android_parts)}`")

    lines.append("━━━━━━━━━━━━━━━━━━")
    lines.append(f"📈 *Tiến trình:* {progress_text}")
    lines.append(f"🆔 *Build ID:* `{build_id}`")
    lines.append(f"🔗 *Base ROM (Nguồn):* [Link]({rom_link})")

    return "\n".join(lines)

def send_notification(status, repo_name, rom_link, channel_id, bot_token, msg_id=None,
                       build_id="Unknown", builder_name="", builder_id="", gofile_link=""):
    is_success = status.lower() == 'success'

    message = build_message(status, rom_link, build_id, builder_name)

    # Nút bấm inline: chỉ hiện nút tải ROM khi đã có link gofile.io (thường chỉ có ở trạng thái success)
    reply_markup = None
    if is_available(gofile_link):
        reply_markup = json.dumps({
            "inline_keyboard": [[
                {"text": "⬇️ Tải ROM", "url": gofile_link}
            ]]
        })

    # Thành công -> chỉ gửi lên nhóm/kênh chat (tin nhắn mới, kèm nút tải nếu có).
    # Các trạng thái khác (start/download/unpack/build/pack/upload/fail) -> chỉ gửi/PM riêng cho builder_id,
    # và được edit lại trên cùng 1 tin nhắn để theo dõi tiến trình.
    if is_success:
        target_chat_id = channel_id
        use_msg_id = None  # luôn gửi tin nhắn mới lên nhóm khi thành công
    else:
        target_chat_id = builder_id
        use_msg_id = msg_id

    if not is_available(target_chat_id):
        print(f"Lỗi: Không có chat đích để gửi thông báo cho trạng thái '{status}' (thiếu channel_id hoặc builder_id).")
        return

    if use_msg_id:
        url = f"https://api.telegram.org/bot{bot_token}/editMessageText"
        payload = {
            "chat_id": target_chat_id,
            "message_id": use_msg_id,
            "text": message,
            "parse_mode": "Markdown",
            "disable_web_page_preview": True
        }
    else:
        url = f"https://api.telegram.org/bot{bot_token}/sendMessage"
        payload = {
            "chat_id": target_chat_id,
            "text": message,
            "parse_mode": "Markdown",
            "disable_web_page_preview": True
        }

    if reply_markup:
        payload["reply_markup"] = reply_markup

    try:
        response = requests.post(url, json=payload)
        response.raise_for_status()
        res_data = response.json()

        new_msg_id = res_data.get('result', {}).get('message_id')

        # Chỉ lưu lại msg_id để edit tiếp cho các bước tiến trình gửi cho builder (không áp dụng cho tin thành công lên nhóm)
        if not is_success and not use_msg_id and new_msg_id and "GITHUB_ENV" in os.environ:
            with open(os.environ["GITHUB_ENV"], "a", encoding="utf-8") as f:
                f.write(f"TELEGRAM_MSG_ID={new_msg_id}\n")
            print(f"Đã lưu TELEGRAM_MSG_ID={new_msg_id} vào GITHUB_ENV để tự động update tin nhắn.")

        print(f"Đã gửi/cập nhật thông báo tới chat {target_chat_id} thành công!")

    except Exception as e:
        print(f"Lỗi khi gửi thông báo: {e}")
        if 'response' in locals():
            print(response.text)

if __name__ == "__main__":
    if len(sys.argv) < 4:
        print("Sử dụng: python notify.py <status> <repo_name> <rom_link> [prefix_id] [builder_name] [builder_id] [gofile_link] [rom_zip_path]")
        sys.exit(1)

    status = sys.argv[1]
    repo_name = sys.argv[2]
    rom_link = sys.argv[3]

    # Prefix cho build id (ví dụ: xiaomi, xst, oplus)
    prefix = sys.argv[4] if len(sys.argv) > 4 else "build"

    # Thông tin người build
    builder_name = sys.argv[5] if len(sys.argv) > 5 else ""
    builder_id = sys.argv[6] if len(sys.argv) > 6 else ""

    # Link tải ROM trên gofile.io, nếu đã có sẵn (ví dụ upload ở step khác rồi truyền vào)
    gofile_link = sys.argv[7] if len(sys.argv) > 7 else os.environ.get("GOFILE_LINK", "")

    # Đường dẫn tới file zip ROM cần upload lên gofile.io (nếu status=success và chưa có gofile_link)
    rom_zip_path = sys.argv[8] if len(sys.argv) > 8 else os.environ.get("ROM_ZIP_PATH", "")

    # Token tài khoản gofile.io (không bắt buộc, để upload dạng guest thì bỏ trống)
    gofile_token = os.environ.get("GOFILE_TOKEN", "")

    # Lấy token, channel ID, message ID và Build ID từ biến môi trường
    bot_token = os.environ.get("TELEGRAM_BOT_TOKEN")
    channel_id = os.environ.get("TELEGRAM_CHANNEL_ID")
    msg_id = os.environ.get("TELEGRAM_MSG_ID")
    build_id = os.environ.get("TELEGRAM_BUILD_ID")

    # Tạo Build ID mới nếu chưa có
    if not build_id:
        random_digits = ''.join(random.choices(string.digits, k=8))
        build_id = f"{prefix}_{random_digits}"

        if "GITHUB_ENV" in os.environ:
            with open(os.environ["GITHUB_ENV"], "a", encoding="utf-8") as f:
                f.write(f"TELEGRAM_BUILD_ID={build_id}\n")

    if not bot_token:
        print("Lỗi: Thiếu TELEGRAM_BOT_TOKEN trong biến môi trường.")
        sys.exit(1)

    # Nếu build thành công, chưa có sẵn gofile_link, nhưng có đường dẫn file zip -> tự upload lên gofile.io
    if status.lower() == 'success' and not is_available(gofile_link) and rom_zip_path:
        uploaded_link = upload_to_gofile(rom_zip_path, gofile_token)
        if uploaded_link:
            gofile_link = uploaded_link
            if "GITHUB_ENV" in os.environ:
                with open(os.environ["GITHUB_ENV"], "a", encoding="utf-8") as f:
                    f.write(f"GOFILE_LINK={uploaded_link}\n")

    send_notification(status, repo_name, rom_link, channel_id, bot_token, msg_id,
                       build_id, builder_name, builder_id, gofile_link)
