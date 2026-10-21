#!/usr/bin/env python3
import os
import sys
import json
import time
import shutil
import subprocess
import requests

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
        print(f"Không thể lấy danh sách server riêng ({e}), sử dụng endpoint tổng.")
    return None

def check_token(token):
    if not token:
        return None
    try:
        headers = {"Authorization": f"Bearer {token}"}
        r = requests.get("https://api.gofile.io/accounts/getid", headers=headers, timeout=10)
        if r.status_code == 200 and r.json().get("status") == "ok":
            print("✅ GOFILE_TOKEN xác thực thành công!")
            return token
        else:
            print(f"⚠️ CẢNH BÁO: GOFILE_TOKEN không hợp lệ hoặc đã hết hạn ({r.text.strip()}).")
            print("Tự động chuyển sang chế độ upload vãng lai (Guest Mode)...")
            return None
    except Exception as e:
        print(f"Lỗi khi kiểm tra token ({e}), sử dụng Guest Mode...")
        return None

def upload_file(file_path, token=None):
    if not os.path.isfile(file_path):
        print(f"❌ Không tìm thấy tệp để upload: {file_path}")
        return None

    file_size = os.path.getsize(file_path)
    file_mb = file_size / (1024 * 1024)
    file_name = os.path.basename(file_path)
    print("==================== UPLOAD ROM LÊN GOFILE ====================")
    print(f"Tệp: {file_name}")
    print(f"Dung lượng: {file_mb:.2f} MB ({file_size:,} bytes)")

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
        print("------------------------------------------------------------")
        print(f"Lần thử {attempt}: Đang upload lên {url}...")
        start_time = time.time()
        res_json = None

        # 1. Ưu tiên dùng curl trực tiếp để stream đĩa (không tốn RAM, an toàn tuyệt đối cho file lớn > 7GB)
        if curl_bin:
            try:
                cmd = [curl_bin, "-sS", "--max-time", "7200"]
                if valid_token:
                    cmd.extend(["-H", f"Authorization: Bearer {valid_token}"])
                    cmd.extend(["-F", f"token={valid_token}"])
                cmd.extend(["-F", f"file=@{file_path}"])
                cmd.append(url)

                proc = subprocess.run(cmd, capture_output=True, text=True, timeout=7200)
                elapsed = time.time() - start_time
                print(f"Upload hoàn tất trong {elapsed:.1f} giây. Mã thoát curl: {proc.returncode}")

                if proc.returncode == 0 and proc.stdout:
                    raw_out = proc.stdout.strip()
                    try:
                        res_json = json.loads(raw_out)
                    except Exception:
                        idx = raw_out.rfind('{"status":')
                        if idx != -1:
                            try:
                                res_json = json.loads(raw_out[idx:])
                            except Exception:
                                pass
                else:
                    if proc.stderr:
                        print(f"curl thông báo: {proc.stderr[:300]}")
            except Exception as curl_err:
                print(f"Lỗi khi gọi curl: {curl_err}")

        # 2. Fallback bằng requests nếu curl không khả dụng hoặc chưa parse được JSON
        if not res_json:
            try:
                print("Thử upload qua thư viện requests...")
                headers = {}
                if valid_token:
                    headers["Authorization"] = f"Bearer {valid_token}"
                with open(file_path, "rb") as f:
                    files = {"file": (file_name, f)}
                    data = {"token": valid_token} if valid_token else {}
                    resp = requests.post(url, headers=headers, files=files, data=data, timeout=7200)
                    if resp.status_code == 200:
                        res_json = resp.json()
            except Exception as req_err:
                print(f"Lỗi khi dùng requests: {req_err}")

        # 3. Phân tích kết quả JSON
        if res_json:
            print(f"Phản hồi từ Gofile: {json.dumps(res_json, ensure_ascii=False)}")
            if res_json.get("status") == "ok":
                d_data = res_json.get("data", {})
                link = d_data.get("downloadPage")
                if not link:
                    code = d_data.get("parentFolderCode") or d_data.get("code")
                    if code:
                        link = f"https://gofile.io/d/{code}"

                if link:
                    download_link = link
                    print(f"🎉 Upload thành công! Link tải: {download_link}")
                    break
        else:
            print(f"⚠️ Chưa lấy được link từ {url}, chuẩn bị thử tiếp...")

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
        print("❌ Không tìm thấy tệp ROM zip nào trong thư mục out/!")
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
        print(f"Đã lưu link vào {link_path}")

        # Ghi vào GITHUB_ENV
        gh_env = os.environ.get("GITHUB_ENV")
        if gh_env and os.path.exists(gh_env):
            with open(gh_env, "a", encoding="utf-8") as f:
                f.write(f"DOWNLOAD_LINK={link}\n")
            print("Đã xuất DOWNLOAD_LINK vào GITHUB_ENV.")
    else:
        print("❌ Toàn bộ các lượt upload đều thất bại. Không tạo được link tải.")

if __name__ == "__main__":
    main()
