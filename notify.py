import os
import sys
import json
import requests
import random
import string
from datetime import datetime, timezone, timedelta

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

def is_available(value):
    if not value:
        return False
    val_lower = str(value).strip().lower()
    if val_lower in ["", "chưa rõ", "unknown", "đang xác định...", "⏳ đang quét..."]:
        return False
    return True

def get_prop_value(prop_path, key, default=""):
    if not os.path.exists(prop_path):
        return default
    try:
        with open(prop_path, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                line = line.strip()
                if line.startswith(f"{key}="):
                    val = line.split("=", 1)[1].strip()
                    return val if val else default
    except Exception:
        pass
    return default

def html_esc(text):
    if text is None:
        return ""
    return (str(text)
            .replace("&", "&amp;")
            .replace("<", "&lt;")
            .replace(">", "&gt;")
            .replace('"', "&quot;"))

def bar_for(pct):
    try:
        pct = int(pct)
    except Exception:
        pct = 0
    n = (pct + 5) // 10
    n = max(0, min(10, n))
    return "▬" * n + "▭" * (10 - n)

def get_time_vn():
    vn_tz = timezone(timedelta(hours=7))
    return datetime.now(vn_tz).strftime("%H:%M · %d/%m/%Y")

STATUS_MAP = {
    "start":    (8,   "⏳", "Khởi động pipeline",  "Dọn môi trường, cài toolchain…"),
    "download": (20,  "⬇️", "Đang tải ROM gốc",      "Downloading base ROM…"),
    "unpack":   (35,  "📂", "Đang giải nén ROM",    "Unpacking partitions…"),
    "build":    (55,  "🔨", "Đang biên dịch ROM",   "Đang chạy build.sh"),
    "pack":     (78,  "📦", "Đang đóng gói",        "Đang chạy packROM.sh"),
    "upload":   (94,  "☁️", "Đang tải lên Gofile",   "Upload file ROM…"),
    "success":  (100, "✅", "Hoàn tất",              "ROM đã sẵn sàng để tải về."),
    "fail":     (0,   "❌", "Build thất bại",       "Pipeline dừng. Mở log để xem lỗi."),
}

def build_message(status, rom_link, build_id, builder_name, run_url=""):
    status_l = status.lower()
    pct, icon, title, hint = STATUS_MAP.get(status_l, (0, "ℹ️", status, ""))

    system_prop = "build/baserom/images/system/system/build.prop"

    # ----- 1. Codename & Tên máy (Device Name) -----
    DUMMY_CODENAMES = {"", "YOURDEVICE", "DEVICECODE", "UNKNOWN", "MISSI", "MIPRODUCT", "MIVENDOR", "GENERIC", "MAINLINE", "QSSI", "QTI"}

    codename = read_file_if_exists("bin/ddevice/device_code.txt").upper()
    if codename in DUMMY_CODENAMES:
        codename = read_file_if_exists("bin/ddevice/device_f.txt").upper()
    if codename in DUMMY_CODENAMES:
        codename = read_file_if_exists("bin/ddevice/device_model.txt").upper()
    if codename in DUMMY_CODENAMES:
        codename = get_prop_value(system_prop, "ro.product.device", "").upper()
    if codename in DUMMY_CODENAMES:
        codename = get_prop_value("build/baserom/images/product/etc/build.prop", "ro.product.product.name", "").upper()
    if codename in DUMMY_CODENAMES:
        codename = get_prop_value("build/baserom/images/odm/etc/build.prop", "ro.product.odm.device", "").upper()
    if codename in DUMMY_CODENAMES:
        codename = ""

    device_name = read_file_if_exists("bin/ddevice/device_name.txt")
    if not device_name or device_name in ["Không tìm thấy key", "Xiaomi Device"]:
        device_name = read_file_if_exists("bin/ddevice/name_devices.txt")
    if not device_name or device_name in ["Không tìm thấy key", "Xiaomi Device"]:
        device_name = get_prop_value("build/baserom/images/product/etc/build.prop", "ro.product.marketname", "")
    if not device_name or device_name in ["Không tìm thấy key", "Xiaomi Device"]:
        device_name = get_prop_value("build/baserom/images/system/system/build.prop", "ro.product.marketname", "")
    if device_name in ["Không tìm thấy key", "Xiaomi Device"]:
        device_name = ""

    if not codename:
        device_dir = "bin/device"
        if os.path.exists(device_dir):
            for file in os.listdir(device_dir):
                if file.endswith(".txt"):
                    lines_ = [l.strip() for l in read_file_if_exists(os.path.join(device_dir, file)).split("\n") if l.strip()]
                    if len(lines_) >= 2:
                        codename = lines_[1].upper()
                    break

    # ----- 2. Phiên bản hệ điều hành (OS Version) -----
    rom_os = read_file_if_exists("bin/ddevice/rom_os.txt", "")
    base_rom_code = read_file_if_exists("bin/ddevice/base_rom_code.txt", "")

    if rom_os and base_rom_code:
        xiaomi_version = base_rom_code if rom_os in base_rom_code else f"{rom_os} ({base_rom_code})"
    elif base_rom_code:
        xiaomi_version = base_rom_code
    elif rom_os:
        xiaomi_version = rom_os
    else:
        display_id = get_prop_value(system_prop, "ro.build.display.id", "")
        os_name = get_prop_value(system_prop, "ro.mi.os.version.name", "")
        ver_inc = get_prop_value(system_prop, "ro.mi.os.version.incremental", "")
        xiaomi_version = display_id or (f"{os_name} ({ver_inc})" if os_name and ver_inc else os_name or ver_inc)

    if not xiaomi_version:
        device_dir = "bin/device"
        if os.path.exists(device_dir):
            for file in os.listdir(device_dir):
                if file.endswith(".txt"):
                    lines_ = [l.strip() for l in read_file_if_exists(os.path.join(device_dir, file)).split("\n") if l.strip()]
                    if len(lines_) >= 3:
                        xiaomi_version = lines_[2]
                    break

    version_tool = "BugOS 1.1"

    # ----- Khối Codename & OS Version -----
    if not codename and not xiaomi_version:
        device_block = "Đang nhận diện bản dựng…"
    else:
        codename_show = codename or "UNKNOWN"
        os_ver_show = xiaomi_version or "Đang đọc bản dựng…"
        if device_name and device_name.upper() != codename_show:
            device_block = f"<code>{html_esc(codename_show)}</code> ({html_esc(device_name)})  ·  {html_esc(os_ver_show)}"
        else:
            device_block = f"<code>{html_esc(codename_show)}</code>  ·  {html_esc(os_ver_show)}"

    progress_block = "" if status_l == "fail" else f"<code>{bar_for(pct)}  {pct}%</code>\n"

    # ----- Link nguồn ROM -----
    links = []
    if is_available(rom_link):
        links.append(f"🔗 <a href='{html_esc(rom_link)}'>Nguồn ROM</a>")
    links_block = "  ·  ".join(links)

    # ----- ID & Thông tin dung lượng -----
    build_id_show = str(build_id).split("_")[-1]
    info_items = [f"🆔 <code>{html_esc(build_id_show)}</code>"]

    size_info = read_file_if_exists("bin/ddevice/rom_size.txt")
    if not size_info:
        size_info = read_file_if_exists("bin/ddevice/super_size_human.txt")
    if size_info:
        info_items.append(f"📦 Dung lượng: <code>{html_esc(size_info)}</code>")

    info_items.append(f"🕐 {get_time_vn()}")

    # ----- THÔNG BÁO HOÀN TẤT THÀNH CÔNG (ĐÚNG FORMAT USER YÊU CẦU) -----
    if status_l == "success":
        c_show = codename.upper() if codename else "DEVICE"
        v_show = base_rom_code if base_rom_code else (rom_os if rom_os else xiaomi_version)
        if not v_show:
            v_show = "HyperOS"

        s_show = size_info if size_info else "10720 MB"

        res = [
            f"<blockquote>{html_esc(c_show)}\n{html_esc(v_show)}</blockquote>",
            f"📦 Dung lượng: {html_esc(s_show)}",
            f"🕐 {get_time_vn()}",
        ]
        if is_available(rom_link):
            res.append(f"🔗 <a href='{html_esc(rom_link)}'>Nguồn ROM</a>")

        # Đọc Changelog từ file hoặc sử dụng danh mục tính năng mặc định của BugOS
        changelog_content = read_file_if_exists("bin/ddevice/changelog.txt")
        if not changelog_content:
            changelog_content = (
                "• Việt hóa giao diện HyperOS tiếng Việt (Tory Overlay)\n"
                "• Bộ font MiSans Latin VF tiếng Việt chuẩn không lỗi hiển thị\n"
                "• Tích hợp Mi Dialer ghi âm cuộc gọi 2 chiều tự động không thông báo\n"
                "• Mở khóa Theme Manager (hỗ trợ áp dụng theme bên thứ ba .mtz)\n"
                "• Bật Làm mờ nâng cao (Gaussian Blur & Advanced Textures)\n"
                "• Tích hợp CorePatch (cho phép cài đè, hạ cấp ứng dụng)\n"
                "• Vô hiệu hóa xác minh khởi động an toàn (Disable AVB)\n"
                "• Vá lỗi trễ thông báo trên nền tảng ROM China\n"
                "• Mở khóa tần số quét màn hình (1Hz LTPO / High FPS)\n"
                "• Tối ưu hóa hiệu năng và gỡ bỏ ứng dụng rác hệ thống"
            )

        cl_lines = ["📝 <b>Changelog:</b>"]
        for cl_line in changelog_content.strip().split("\n"):
            cl_line = cl_line.strip()
            if cl_line:
                if not cl_line.startswith("•") and not cl_line.startswith("-") and not cl_line.startswith("*"):
                    cl_lines.append(f"• {html_esc(cl_line)}")
                else:
                    cl_lines.append(f"{html_esc(cl_line)}")

        cl_block = "\n".join(cl_lines)
        res.append("")
        res.append(f"<blockquote expandable>{cl_block}</blockquote>")

        return "\n".join(res)

    lines = [
        "<b>BugOS</b> · ROM Builder",
        f"{html_esc(version_tool)}",
        "",
        f"<blockquote>{device_block}</blockquote>",
        "",
        f"{icon} <b>{title}</b>",
        f"{progress_block}<i>{html_esc(hint)}</i>",
        "",
    ] + info_items

    if links_block:
        lines.append(links_block)

    return "\n".join(lines)


def send_notification(status, repo_name, rom_link, channel_id, bot_token, msg_id=None,
                      build_id="Unknown", builder_name="", builder_id="", download_link=""):
    is_success = status.lower() == 'success'

    run_url = ""
    if os.environ.get("GITHUB_SERVER_URL") and os.environ.get("GITHUB_REPOSITORY") and os.environ.get("GITHUB_RUN_ID"):
        run_url = f"{os.environ['GITHUB_SERVER_URL']}/{os.environ['GITHUB_REPOSITORY']}/actions/runs/{os.environ['GITHUB_RUN_ID']}"

    message = build_message(status, rom_link, build_id, builder_name, run_url)

    payload = {
        "text": message,
        "parse_mode": "HTML",
        "disable_web_page_preview": True
    }

    # ----- CHỈ GIỮ NÚT TẢI ROM (NẾU THÀNH CÔNG) VÀ NÚT LOG (NẾU LỖI) -----
    buttons = []
    if is_success:
        if is_available(download_link):
            buttons.append([{"text": "⬇️ Tải ROM", "url": download_link}])
        elif is_available(run_url):
            buttons.append([{"text": "Mở trang bản dựng (Actions)", "url": run_url}])
    elif status.lower() == "fail":
        if is_available(run_url):
            buttons.append([{"text": "Mở log GitHub Actions", "url": run_url}])
            
    if len(buttons) > 0:
        payload["reply_markup"] = json.dumps({"inline_keyboard": buttons})

    target_chat_id = builder_id if is_available(builder_id) else channel_id
    use_msg_id = None if is_success else msg_id

    if not is_available(target_chat_id):
        print("Lỗi: Không tìm thấy ID chat để gửi báo cáo.")
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

    download_link = sys.argv[7] if len(sys.argv) > 7 and sys.argv[7] else os.environ.get("DOWNLOAD_LINK", "")
    if not is_available(download_link):
        download_link = read_file_if_exists("bin/ddevice/download_link.txt")
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

    send_notification(status, repo_name, rom_link, channel_id, bot_token, msg_id, build_id, builder_name, builder_id, download_link)
