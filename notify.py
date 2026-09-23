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

def get_status_line(status):
    status = status.lower()
    mapping = {
        'start':    ("⏳", "ĐANG KHỞI TẠO"),
        'download': ("📥", "ĐANG TẢI VỀ"),
        'unpack':   ("🔓", "ĐANG GIẢI NÉN"),
        'build':    ("🛠️", "ĐANG BUILD"),
        'pack':     ("📦", "ĐANG ĐÓNG GÓI"),
        'upload':   ("📤", "ĐANG TẢI LÊN"),
        'success':  ("✅", "THÀNH CÔNG"),
        'fail':     ("❌", "THẤT BẠI"),
    }
    icon, label = mapping.get(status, ("ℹ️", status.upper()))
    return icon, label

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

def send_notification(status, repo_name, rom_link, channel_id, bot_token, msg_id=None,
                       build_id="Unknown", builder_name="", builder_id="", gofile_link=""):
    icon, status_label = get_status_line(status)

    # Lấy GITHUB_RUN_ID để tạo link trỏ tới log của Action
    run_id = os.environ.get("GITHUB_RUN_ID", "")
    if run_id:
        action_url = f"https://github.com/{repo_name}/actions/runs/{run_id}"
    else:
        action_url = f"https://github.com/{repo_name}/actions"

    # Đọc thông tin thiết bị chi tiết từ các file của BuildTool
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
    output_zip = read_file_if_exists("bin/ddevice/output_zip.txt")

    builder_text = builder_name if builder_name else "🤖 Hệ thống"

    message_lines = [
        "🐧 *TIẾN TRÌNH BUILD ROM*",
        "━━━━━━━━━━━━━━━━━━",
        f"👤 *Người thực hiện:* {builder_text}",
    ]

    if is_available(version_tool):
        message_lines.append(f"🏷️ *Phiên bản:* `BugOS {version_tool}`")
    if is_available(device_name):
        message_lines.append(f"📱 *Device:* `{device_name}`")
    if is_available(codename):
        message_lines.append(f"🔑 *Codename:* `{codename}`")

    os_parts = [p for p in [rom_os, version_rom] if is_available(p)]
    if os_parts:
        message_lines.append(f"💿 *Hệ điều hành:* `{'.'.join(os_parts)}`")

    android_parts = []
    if is_available(android_ver):
        android_parts.append(f"Android {android_ver}")
    if is_available(sdk_level):
        android_parts.append(f"SDK {sdk_level}")
    if android_parts:
        message_lines.append(f"🤖 *Android:* `{' | '.join(android_parts)}`")

    message_lines.append("━━━━━━━━━━━━━━━━━━")
    message_lines.append(f"📶 *Tiến trình:* {status_label} {icon}")
    if status.lower() == 'success' and is_available(output_zip):
        message_lines.append(f"📦 *Tên file zip:* `{output_zip}`")
    message_lines.append(f"🆔 *Build ID:* `{build_id}`")
    message_lines.append(f"🔗 *Base ROM (Nguồn):* [Link]({rom_link})")
    message_lines.append(f"📜 *Log build:* [Xem tại đây]({action_url})")

    message = "\n".join(message_lines)

    # Nút bấm inline: chỉ hiện nút tải ROM khi đã có link gofile.io (sau khi upload xong)
    reply_markup = None
    if is_available(gofile_link):
        reply_markup = json.dumps({
            "inline_keyboard": [[
                {"text": "⬇️ Tải ROM", "url": gofile_link}
            ]]
        })

    if msg_id:
        # Nếu đã có msg_id, ta sẽ Edit tin nhắn cũ
        url = f"https://api.telegram.org/bot{bot_token}/editMessageText"
        payload = {
            "chat_id": channel_id,
            "message_id": msg_id,
            "text": message,
            "parse_mode": "Markdown",
            "disable_web_page_preview": True
        }
    else:
        # Nếu chưa có, gửi tin nhắn mới
        url = f"https://api.telegram.org/bot{bot_token}/sendMessage"
        payload = {
            "chat_id": channel_id,
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

        # Lấy message_id của tin nhắn vừa gửi
        new_msg_id = res_data.get('result', {}).get('message_id')

        # Ghi message_id vào biến môi trường của GitHub Actions để các step sau tái sử dụng
        if not msg_id and new_msg_id and "GITHUB_ENV" in os.environ:
            with open(os.environ["GITHUB_ENV"], "a", encoding="utf-8") as f:
                f.write(f"TELEGRAM_MSG_ID={new_msg_id}\n")
            print(f"Đã lưu TELEGRAM_MSG_ID={new_msg_id} vào GITHUB_ENV để tự động update tin nhắn.")

        print("Đã gửi/cập nhật thông báo lên kênh thành công!")
        # Gửi tin nhắn riêng (PM) cho người build nếu trạng thái là success hoặc fail
        if status.lower() in ['success', 'fail'] and builder_id:
            pm_url = f"https://api.telegram.org/bot{bot_token}/sendMessage"

            if status.lower() == 'success':
                pm_text = (
                    f"🎉 *YÊU CẦU BUILD ROM ĐÃ HOÀN TẤT!*\n\n"
                    f"{message}\n"
                )
            else:
                pm_text = (
                    f"⚠️ *YÊU CẦU BUILD ROM ĐÃ THẤT BẠI!*\n\n"
                    f"{message}\n"
                    f"💡 *Gợi ý:* Hãy bấm vào link Log build ở trên để xem chi tiết lỗi nhé."
                )

            pm_payload = {
                "chat_id": builder_id,
                "text": pm_text,
                "parse_mode": "Markdown",
                "disable_web_page_preview": True
            }
            if reply_markup:
                pm_payload["reply_markup"] = reply_markup
            try:
                requests.post(pm_url, json=pm_payload)
                print(f"Đã gửi tin nhắn riêng (PM) cho user {builder_id}")
            except Exception as e:
                print(f"Lỗi gửi tin nhắn riêng: {e}")

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

        # Lưu vào GITHUB_ENV để dùng cho các step sau
        if "GITHUB_ENV" in os.environ:
            with open(os.environ["GITHUB_ENV"], "a", encoding="utf-8") as f:
                f.write(f"TELEGRAM_BUILD_ID={build_id}\n")

    if not bot_token or not channel_id:
        print("Lỗi: Thiếu TELEGRAM_BOT_TOKEN hoặc TELEGRAM_CHANNEL_ID trong biến môi trường.")
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
