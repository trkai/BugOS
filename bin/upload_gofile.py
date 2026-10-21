#!/usr/bin/env python3
import os
import sys
import json
import time
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

    headers = {}
    if valid_token:
        headers["Authorization"] = f"Bearer {valid_token}"

    download_link = None

    for attempt, url in enumerate(endpoints, 1):
        print("------------------------------------------------------------")
        print(f"Lần thử {attempt}: Đang upload lên {url}...")
        try:
            with open(file_path, "rb") as f:
                files = {"file": (file_name, f)}
                data = {}
                if valid_token:
                    data["token"] = valid_token

                # Upload với timeout lớn cho file dung lượng cao (lên tới 2 tiếng)
                start_time = time.time()
                resp = requests.post(url, headers=headers, files=files, data=data, timeout=7200)
                elapsed = time.time() - start_time
                print(f"Upload hoàn tất trong {elapsed:.1f} giây. HTTP Status: {resp.status_code}")

                if resp.status_code == 200:
                    try:
                        res_json = resp.json()
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
                    except Exception as parse_err:
                        print(f"Lỗi parse JSON phản hồi: {parse_err}. Nội dung thô: {resp.text[:300]}")
                else:
                    print(f"Máy chủ trả về mã lỗi HTTP {resp.status_code}: {resp.text[:300]}")

        except Exception as up_err:
            print(f"Lỗi trong quá trình upload lên {url}: {up_err}")

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
