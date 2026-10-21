#!/usr/bin/env python3
import os
import sys
import json
import time
import shutil
import tempfile
import subprocess
import requests

# Bật unbuffered output ngay lập tức để log hiển thị tức thì trên GitHub Actions
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(line_buffering=True)

def log(msg):
    print(msg, flush=True)

def get_best_server():
    try:
        r = requests.get("https://api.gofile.io/servers", timeout=15)
        if r.status_code == 200:
            data = r.json()
            if data.get("status") == "ok":
                servers = data.get("data", {}).get("servers", [])
                if servers:
                    return servers[0].get("name")
    except Exception as e:
        log(f"Không thể lấy danh sách server riêng ({e}), sử dụng endpoint tổng.")
    return None

def check_token(token):
    if not token:
        return None
    try:
        headers = {"Authorization": f"Bearer {token}"}
        r = requests.get("https://api.gofile.io/accounts/getid", headers=headers, timeout=10)
        if r.status_code == 200 and r.json().get("status") == "ok":
            log("✅ GOFILE_TOKEN xác thực thành công!")
            return token
        else:
            log(f"⚠️ CẢNH BÁO: GOFILE_TOKEN không hợp lệ hoặc đã hết hạn ({r.text.strip()}).")
            log("Tự động chuyển sang chế độ upload vãng lai (Guest Mode)...")
            return None
    except Exception as e:
        log(f"Lỗi khi kiểm tra token ({e}), sử dụng Guest Mode...")
        return None

def upload_file(file_path, token=None):
    if not os.path.isfile(file_path):
        log(f"❌ Không tìm thấy tệp để upload: {file_path}")
        return None

    file_size = os.path.getsize(file_path)
    file_mb = file_size / (1024 * 1024)
    file_name = os.path.basename(file_path)
    log("==================== UPLOAD ROM LÊN GOFILE ====================")
    log(f"Tệp: {file_name}")
    log(f"Dung lượng: {file_mb:.2f} MB ({file_size:,} bytes)")

    valid_token = check_token(token)

    server = get_best_server()
    endpoints = []
    if server:
        endpoints.append(f"https://{server}.gofile.io/contents/uploadfile")
        endpoints.append(f"https://{server}.gofile.io/uploadFile")
    endpoints.append("https://upload.gofile.io/uploadfile")

    curl_bin = shutil.which("curl")
    download_link = None

    for attempt, url in enumerate(endpoints, 1):
        log("------------------------------------------------------------")
        log(f"Lần thử {attempt}: Đang upload lên {url}...")
        start_time = time.time()
        res_json = None

        # 1. ƯU TIÊN SỬ DỤNG CURL STREAM TRỰC TIẾP TỪ Ổ ĐĨA:
        # - Tiêu thụ 0 MB RAM (không bao giờ bị lỗi tràn bộ nhớ OOM với file 7.5GB)
        # - Hiển thị tiến trình trực tiếp (progress bar) trên terminal
        # - Ghi kết quả phản hồi vào file tạm độc lập
        if curl_bin:
            temp_res_fd, temp_res_path = tempfile.mkstemp(suffix=".json")
            os.close(temp_res_fd)
            try:
                cmd = [curl_bin, "-#", "--max-time", "7200"]
                if valid_token:
                    cmd.extend(["-H", f"Authorization: Bearer {valid_token}"])
                    cmd.extend(["-F", f"token={valid_token}"])
                cmd.extend(["-F", f"file=@{file_path}"])
                cmd.append(url)
                cmd.extend(["-o", temp_res_path])

                # Chạy curl và để progress bar hiển thị trực tiếp lên console
                proc = subprocess.run(cmd)
                elapsed = time.time() - start_time
                log(f"\nUpload hoàn tất trong {elapsed:.1f} giây. Mã thoát curl: {proc.returncode}")

                if proc.returncode == 0 and os.path.isfile(temp_res_path) and os.path.getsize(temp_res_path) > 0:
                    with open(temp_res_path, "r", encoding="utf-8", errors="ignore") as rf:
                        raw_content = rf.read().strip()
                        try:
                            res_json = json.loads(raw_content)
                        except Exception:
                            idx = raw_content.rfind('{"status":')
                            if idx != -1:
                                try:
                                    res_json = json.loads(raw_content[idx:])
                                except Exception:
                                    pass
            except Exception as curl_err:
                log(f"Lỗi khi thực thi curl: {curl_err}")
            finally:
                if os.path.exists(temp_res_path):
                    try:
                        os.remove(temp_res_path)
                    except Exception:
                        pass

        # 2. Phân tích kết quả
        if res_json:
            log(f"Phản hồi từ Gofile: {json.dumps(res_json, ensure_ascii=False)}")
            if res_json.get("status") == "ok":
                d_data = res_json.get("data", {})
                link = d_data.get("downloadPage")
                if not link:
                    code = d_data.get("parentFolderCode") or d_data.get("code")
                    if code:
                        link = f"https://gofile.io/d/{code}"

                if link:
                    download_link = link
                    log(f"🎉 Upload thành công! Link tải: {download_link}")
                    break
        else:
            log(f"⚠️ Chưa lấy được link từ {url}, chuẩn bị thử tiếp...")

        time.sleep(5)

    return download_link

def main():
    work_dir = os.getcwd()

    # Xác định đường dẫn file zip ROM
    zip_path = None
    output_zip_file = os.path.join(work_dir, "bin/ddevice/output_zip.txt")
    if os.path.exists(output_zip_file):
        with open(output_zip_file, "r", encoding="utf-8") as f:
            zname = f.read().strip()
            if zname:
                cand = os.path.join(work_dir, "out", zname)
                if os.path.isfile(cand):
                    zip_path = cand

    if not zip_path:
        out_dir = os.path.join(work_dir, "out")
        if os.path.isdir(out_dir):
            for f in os.listdir(out_dir):
                if f.startswith("BugOS_") and f.endswith(".zip"):
                    zip_path = os.path.join(out_dir, f)
                    break

    if not zip_path:
        log("❌ Không tìm thấy tệp ROM zip nào trong thư mục out/!")
        sys.exit(0)

    token = os.environ.get("GOFILE_TOKEN", "").strip()

    link = upload_file(zip_path, token)

    if link:
        # Ghi vào file download_link.txt
        link_dir = os.path.join(work_dir, "bin/ddevice")
        os.makedirs(link_dir, exist_ok=True)
        link_path = os.path.join(link_dir, "download_link.txt")
        with open(link_path, "w", encoding="utf-8") as f:
            f.write(link + "\n")
        log(f"Đã lưu link vào {link_path}")

        # Ghi vào GITHUB_ENV
        gh_env = os.environ.get("GITHUB_ENV")
        if gh_env and os.path.exists(gh_env):
            with open(gh_env, "a", encoding="utf-8") as f:
                f.write(f"DOWNLOAD_LINK={link}\n")
            log("Đã xuất DOWNLOAD_LINK vào GITHUB_ENV.")
    else:
        log("❌ Toàn bộ các lượt upload đều thất bại. Không tạo được link tải.")

if __name__ == "__main__":
    main()
