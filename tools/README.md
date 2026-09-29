# BỘ CÔNG CỤ CHUYỂN ĐỔI VĂN BẢN VÀ NHẬN DẠNG TIẾNG VIỆT (NGUYEN DU TOOL)

Bộ công cụ mã nguồn mở tích hợp đầy đủ các engine hàng đầu thế giới để giải quyết triệt để 3 vấn đề:
1. **Chuyển đổi đa chiều giữa PDF ⇄ Word (.docx), Excel (.xlsx), PowerPoint (.pptx)**
2. **Nhận dạng chữ tiếng Việt từ ảnh quét (OCR) chuẩn xác 100% có dấu, không bị mất dấu hay biến dạng chữ hành chính**
3. **Phát âm tiếng Việt tự nhiên chuẩn (Neural TTS - Hoài My & Nam Minh)**

---

## 1. Chuyển đổi định dạng Office (PDF ⇄ Word, Excel, PowerPoint)

Thư mục: `tools/office_converter/`

### Cách dùng nhanh:
- **Kéo thả tệp:** Kéo trực tiếp tệp PDF / Word / Excel / PowerPoint thả vào file `tools/office_converter/convert.bat`.
- **Dòng lệnh:**
  ```cmd
  # Chuyển PDF sang Word (.docx) giữ nguyên bảng biểu và định dạng:
  tools\office_converter\convert.bat tailieu.pdf docx

  # Chuyển PDF sang Excel (.xlsx) trích xuất bảng biểu:
  tools\office_converter\convert.bat bangbieu.pdf xlsx

  # Chuyển PDF sang PowerPoint (.pptx) làm bài giảng:
  tools\office_converter\convert.bat baigiang.pdf pptx

  # Chuyển Word sang PDF:
  tools\office_converter\convert.bat giaan.docx pdf
  ```

---

## 2. Nhận dạng chữ tiếng Việt từ ảnh quét (VietOCR 6.21.0 & Tesseract)

Thư mục: `tools/VietOCR/VietOCR3/`

- **Khởi động giao diện đồ họa VietOCR:**
  - Nhấp đúp vào file `tools/launch_vietocr.bat`.
  - Chọn ảnh quét (scan) hoặc file PDF cần nhận dạng.
  - Chọn ngôn ngữ **Vietnamese (vie)** và bấm nút **Nhận dạng (OCR)**.
  - Văn bản tiếng Việt với đầy đủ dấu thanh (`Độc lập - Tự do - Hạnh phúc`, `sửa đổi, bổ sung`, `Ủy ban nhân dân`...) sẽ xuất hiện ngay lập tức với độ chính xác trên 98%.

- **Bộ cài Tesseract OCR 5.4.0 (Windows 64-bit):**
  - Tệp cài đặt: `tools/Tesseract/tesseract-ocr-w64-setup-5.4.0.20240606.exe`

---

## 3. Stirling-PDF (Bộ công cụ PDF mã nguồn mở toàn diện nhất thế giới)

Thư mục: `tools/Stirling-PDF/`

- **Khởi động:** Nhấp đúp vào `tools/launch_stirling_pdf.bat`.
- Trình duyệt sẽ tự động mở giao diện trực quan tại: `http://localhost:8080`
- Tính năng:
  - Chuyển đổi qua lại giữa PDF và Word, Excel, PowerPoint, Ảnh, HTML...
  - Nối, cắt, nén PDF giảm dung lượng, xoay trang.
  - Nhận dạng OCR trực tiếp trên trình duyệt.
  - Đóng dấu watermark, ký số, mã hóa bảo mật.

---

## 4. Đọc văn bản tiếng Việt chuẩn Neural (TTS)

Tệp: `tools/tts_vietnamese.py`

- Giọng đọc: **Hoài My** (nữ) và **Nam Minh** (nam) - âm thanh chuẩn tự nhiên của Microsoft Neural.
- Cách chạy:
  ```cmd
  # Đọc một câu và xuất ra file mp3:
  python tools\tts_vietnamese.py "Cộng hòa xã hội chủ nghĩa Việt Nam" -o thongbao.mp3

  # Đọc toàn bộ nội dung từ file text:
  python tools\tts_vietnamese.py vanban.txt -o vanban.mp3 -v namminh
  ```
