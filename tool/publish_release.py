import os
import sys
import subprocess
import json
import urllib.request
import urllib.error

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')
if hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8')

REPO = "dienmoc86/nguyendutool"
TAG = "v1.5.1"
NAME = "NguyenDu Tool v1.5.1 - Official Release"

BODY = """## 🌟 NguyenDu Tool v1.5.1 (Official Release)

Bộ công cụ máy tính đa năng dành cho giáo viên, nhà trường và văn phòng giáo dục. Hoạt động ngoại tuyến 100% (**Local-First**) trên Windows 10/11 x64.

### 🚀 Tính năng nổi bật:
1. **Chuyển đổi tài liệu & OCR tiếng Việt:**
   - Trích xuất chữ trực tiếp và OCR offline tiếng Việt (WinRT OCR).
   - Tự động nhận diện bảng biểu (`TableDetector`).
   - Xuất Microsoft Word (`.docx`) và Excel (`.xlsx`) thuần OpenXML không cần cài Microsoft Office.
2. **Số hóa tài liệu & Searchable PDF:**
   - Kết nối máy scan qua chuẩn Windows WIA 2.0.
   - Xử lý ảnh: Tự căn thẳng (deskew ±10°), sửa méo góc (perspective warp), khử bóng đổ.
   - Xuất Searchable PDF (ISO 32000) với lớp text ẩn `3 Tr` tra cứu và copy chữ trực tiếp.
3. **Giọng đọc AI & Phụ đề (TTS):**
   - Giọng đọc Windows SAPI & WinRT OneCore ngoại tuyến.
   - Chuẩn hóa văn bản tiếng Việt bảo thủ (ngày tháng, số đo, tiền tệ, từ viết tắt).
   - Xuất âm thanh WAV PCM và MP3, tự động sinh phụ đề đồng bộ `.srt` và `.vtt`.
4. **Xưởng dựng Video bài giảng (Video Studio):**
   - Động cơ FFmpeg & FFprobe 8.0.1 tích hợp.
   - Dựng clip bài giảng, thuyết minh TTS tự khớp thời lượng, phụ đề chữ cứng, nhạc nền với Audio Ducking.
5. **Tự động Cập nhật (In-App Auto-Update):**
   - Ứng dụng tự động thông báo khi có bản cập nhật mới trên GitHub Releases.
   - Tải về có thanh tiến trình trực quan, xác thực mã băm SHA-256 an toàn.
   - Tự động nâng cấp ngầm (Silent Upgrade) và khởi động lại phiên bản mới mượt mà.

---

### 📦 Tệp cài đặt & Tải về:
* **Bộ cài đặt (Setup):** `NguyenDuTool_Setup_1.5.1.exe` (Khuyên dùng - Cài đặt tự động, không cần quyền Admin).
* **Bản chạy ngay (Portable):** `NguyenDuTool_Portable_1.5.1.zip` (Giải nén chạy ngay, thích hợp copy USB).
* **Kiểm tra mã băm:** `SHA256SUMS.txt`.
"""

def get_git_token():
    p = subprocess.Popen(['git', 'credential', 'fill'], stdin=subprocess.PIPE, stdout=subprocess.PIPE)
    out, _ = p.communicate(b'protocol=https\nhost=github.com\n\n')
    token = None
    for line in out.decode('utf-8', errors='ignore').splitlines():
        if line.startswith('password='):
            token = line.split('password=', 1)[1].strip()
            break
    return token

def main():
    print("1. Lấy thông tin xác thực từ Git Credential Manager...")
    token = get_git_token()
    if not token:
        print("LỖI: Không tìm thấy GitHub token từ Git Credential Manager.")
        sys.exit(1)
    print("-> Đã lấy được GitHub token thành công.")

    print(f"2. Tạo Git tag {TAG} và đẩy lên GitHub...")
    subprocess.run(['git', 'tag', '-f', TAG, '-m', f'Release {TAG}'], check=True)
    subprocess.run(['git', 'push', '-f', 'origin', TAG], check=True)
    print("-> Đã đẩy Git tag lên GitHub.")

    print("3. Kiểm tra xem Release đã tồn tại trên GitHub chưa...")
    check_url = f"https://api.github.com/repos/{REPO}/releases/tags/{TAG}"
    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github.v3+json",
        "User-Agent": "NguyenDuTool-ReleaseScript"
    }

    req = urllib.request.Request(check_url, headers=headers)
    release = None
    try:
        with urllib.request.urlopen(req) as resp:
            release = json.loads(resp.read().decode('utf-8'))
            print(f"-> Release {TAG} đã tồn tại (ID: {release['id']}). Sẽ cập nhật tệp tài sản (assets).")
    except urllib.error.HTTPError as e:
        if e.code == 404:
            print(f"-> Release {TAG} chưa có, tiến hành tạo mới...")
        else:
            print(f"Lỗi kiểm tra release: {e}")
            sys.exit(1)

    if not release:
        create_url = f"https://api.github.com/repos/{REPO}/releases"
        payload = json.dumps({
            "tag_name": TAG,
            "name": NAME,
            "body": BODY,
            "draft": False,
            "prerelease": False
        }).encode('utf-8')
        req = urllib.request.Request(create_url, data=payload, headers=headers, method="POST")
        with urllib.request.urlopen(req) as resp:
            release = json.loads(resp.read().decode('utf-8'))
            print(f"-> Tạo Release mới thành công! (ID: {release['id']})")

    upload_url_template = release.get("upload_url", "")
    upload_url_base = upload_url_template.split("{")[0]

    files_to_upload = [
        ("release/1.5.1/NguyenDuTool_Setup_1.5.1.exe", "NguyenDuTool_Setup_1.5.1.exe", "application/octet-stream"),
        ("release/1.5.1/NguyenDuTool_Portable_1.5.1.zip", "NguyenDuTool_Portable_1.5.1.zip", "application/zip"),
        ("release/1.5.1/SHA256SUMS.txt", "SHA256SUMS.txt", "text/plain"),
        ("RELEASE_MANIFEST.json", "RELEASE_MANIFEST.json", "application/json")
    ]

    existing_assets = {a['name']: a['id'] for a in release.get('assets', [])}

    for local_path, asset_name, content_type in files_to_upload:
        if not os.path.exists(local_path):
            print(f"CẢNH BÁO: Tệp {local_path} không tồn tại, bỏ qua.")
            continue

        file_size = os.path.getsize(local_path)
        print(f"-> Đang chuẩn bị tệp: {asset_name} ({round(file_size / (1024*1024), 2)} MB)...")

        # Delete existing asset if present
        if asset_name in existing_assets:
            del_id = existing_assets[asset_name]
            print(f"   Xóa asset cũ ID {del_id}...")
            del_url = f"https://api.github.com/repos/{REPO}/releases/assets/{del_id}"
            del_req = urllib.request.Request(del_url, headers=headers, method="DELETE")
            try:
                with urllib.request.urlopen(del_req) as del_resp:
                    pass
            except Exception as e:
                print(f"   Lỗi xóa asset cũ: {e}")

        # Upload asset
        upload_url = f"{upload_url_base}?name={asset_name}"
        upload_headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": content_type,
            "Content-Length": str(file_size),
            "User-Agent": "NguyenDuTool-ReleaseScript"
        }

        print(f"   Đang tải lên GitHub...")
        with open(local_path, "rb") as f:
            file_data = f.read()

        up_req = urllib.request.Request(upload_url, data=file_data, headers=upload_headers, method="POST")
        try:
            with urllib.request.urlopen(up_req) as up_resp:
                print(f"   ✅ Đã tải lên thành công: {asset_name}!")
        except Exception as e:
            print(f"   ❌ Lỗi khi tải lên {asset_name}: {e}")

    print("\n🎉 HOÀN TẤT PHÁT HÀNH!")
    print(f"👉 Xem bản phát hành trực tiếp tại: {release['html_url']}")

if __name__ == "__main__":
    main()
