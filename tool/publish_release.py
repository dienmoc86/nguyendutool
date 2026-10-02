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

def get_version_info():
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    version_file = os.path.join(base_dir, "VERSION.json")
    with open(version_file, "r", encoding="utf-8") as f:
        data = json.load(f)
    return data.get("version", "1.7.3"), data.get("build", 15)

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
    version, build = get_version_info()
    tag = f"v{version}"
    name = f"NguyenDu Tool v{version} - Official Release"
    body = f"""## 🌟 NguyenDu Tool v{version} (Official Release)

Bộ công cụ máy tính số hóa & trợ lý toàn diện dành cho Giáo viên, Nhà trường và Văn phòng Giáo dục. Hoạt động ngoại tuyến 100% (**Local-First**) trên Windows 10/11 x64.

### 🚀 Tính năng nổi bật trong bản {version}:
1. **Chuyển đổi tài liệu PDF sang Word, Excel, PowerPoint:**
   - Trích xuất chữ, công thức toán và bảng biểu chính xác.
   - Thao tác 1-click mở ngay trên Word/PowerPoint và mở thư mục chứa tệp.
2. **Quét đề thi & Số hóa học liệu (Document Scanner):**
   - Động cơ kép nhận diện máy scan chuẩn WIA và camera điện thoại / USB webcam.
   - Tự động uốn nắn góc phẳng (perspective warp), khử bóng mờ, làm trắng nền giấy.
   - Xuất Searchable PDF tra cứu và copy chữ trực tiếp.
3. **Chuyển văn bản thành giọng nói AI (Text-to-Speech):**
   - Động cơ giọng đọc sư phạm tự nhiên (Hoài My, Nam Minh, Mai, Ngọc) tốc độ cao (~1.5s).
   - Nghe ngay và copy nhanh vào USB đem lên lớp cắm loa phát.
4. **Tự động Cập nhật Trực tiếp (Auto-Update):**
   - Tự động kiểm tra bản mới ngay khi mở ứng dụng.
   - Tải về và tự động nâng cấp ngầm (Silent Upgrade) mượt mà.

---

### 📦 Tệp cài đặt & Tải về:
* **Bộ cài đặt (Setup):** `NguyenDuTool_Setup_{version}.exe` (Khuyên dùng - Cài đặt tự động).
* **Bản chạy ngay (Portable):** `NguyenDuTool_Portable_{version}.zip` (Giải nén chạy ngay, thích hợp copy USB).
* **Kiểm tra mã băm:** `SHA256SUMS.txt`.
"""

    print(f"Bắt đầu phát hành bản: {name} (Tag: {tag})")
    print("1. Lấy thông tin xác thực từ Git Credential Manager...")
    token = get_git_token()
    if not token:
        print("LỖI: Không tìm thấy GitHub token từ Git Credential Manager.")
        sys.exit(1)
    print("-> Đã lấy được GitHub token thành công.")

    print(f"2. Tạo Git tag {tag} và đẩy lên GitHub...")
    subprocess.run(['git', 'tag', '-f', tag, '-m', f'Release {tag}'], check=True)
    subprocess.run(['git', 'push', '-f', 'origin', tag], check=True)
    print("-> Đã đẩy Git tag lên GitHub.")

    print("3. Kiểm tra xem Release đã tồn tại trên GitHub chưa...")
    check_url = f"https://api.github.com/repos/{REPO}/releases/tags/{tag}"
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
            print(f"-> Release {tag} đã tồn tại (ID: {release['id']}). Sẽ cập nhật tệp tài sản (assets).")
    except urllib.error.HTTPError as e:
        if e.code == 404:
            print(f"-> Release {tag} chưa có, tiến hành tạo mới...")
        else:
            print(f"Lỗi kiểm tra release: {e}")
            sys.exit(1)

    if not release:
        create_url = f"https://api.github.com/repos/{REPO}/releases"
        payload = json.dumps({
            "tag_name": tag,
            "name": name,
            "body": body,
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
        (f"release/{version}/NguyenDuTool_Setup_{version}.exe", f"NguyenDuTool_Setup_{version}.exe", "application/octet-stream"),
        (f"release/{version}/NguyenDuTool_Portable_{version}.zip", f"NguyenDuTool_Portable_{version}.zip", "application/zip"),
        (f"release/{version}/SHA256SUMS.txt", "SHA256SUMS.txt", "text/plain"),
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
