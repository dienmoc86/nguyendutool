import 'dart:io';
import 'package:path/path.dart' as p;

void main() async {
  final fixturesDir = Directory(p.join(Directory.current.path, 'test', 'fixtures'));
  if (!fixturesDir.existsSync()) {
    fixturesDir.createSync(recursive: true);
  }

  // 1. Text Vietnamese PDF
  await File(p.join(fixturesDir.path, '01_text_vietnamese.pdf')).writeAsString('''
%PDF-1.4
1 0 obj
<< /Type /Catalog /Pages 2 0 R >>
endobj
2 0 obj
<< /Type /Pages /Kids [3 0 R] /Count 1 >>
endobj
3 0 obj
<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>
endobj
4 0 obj
<< /Length 260 >>
stream
BT
/F1 14 Tf
50 780 Td
(CONG HOA XA HOI CHU NGHIA VIET NAM) Tj
0 -24 Td
(Doc lap - Tu do - Hanh phuc) Tj
0 -36 Td
(TRUONG THCS NGUYEN DU) Tj
0 -24 Td
(Giao an bai giang mon Ngu Van lop 9 ky 1 nam hoc 2026-2027) Tj
0 -24 Td
(Noi dung bai giang chu thich ve Truyen Kieu cua dai thi hao Nguyen Du.) Tj
ET
endstream
endobj
5 0 obj
<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>
endobj
xref
0 6
0000000000 65535 f
0000000009 00000 n
0000000058 00000 n
0000000115 00000 n
0000000244 00000 n
0000000557 00000 n
trailer
<< /Size 6 /Root 1 0 R >>
startxref
634
%%EOF
'''.trim());

  // 2. Scan Vietnamese PDF (Image XObject, zero text stream)
  await File(p.join(fixturesDir.path, '02_scan_vietnamese.pdf')).writeAsString('''
%PDF-1.4
1 0 obj
<< /Type /Catalog /Pages 2 0 R >>
endobj
2 0 obj
<< /Type /Pages /Kids [3 0 R] /Count 1 >>
endobj
3 0 obj
<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Contents 4 0 R /Resources << /XObject << /Im1 5 0 R >> >> >>
endobj
4 0 obj
<< /Length 45 >>
stream
q
500 0 0 700 50 50 cm
/Im1 Do
Q
endstream
endobj
5 0 obj
<< /Type /XObject /Subtype /Image /Width 100 /Height 100 /ColorSpace /DeviceRGB /BitsPerComponent 8 /Length 10 >>
stream
0123456789
endstream
endobj
xref
0 6
0000000000 65535 f
0000000009 00000 n
0000000058 00000 n
0000000115 00000 n
0000000242 00000 n
0000000340 00000 n
trailer
<< /Size 6 /Root 1 0 R >>
startxref
480
%%EOF
'''.trim());

  // 3. Mixed Document PDF (Contains both embedded text stream and raster Image)
  await File(p.join(fixturesDir.path, '03_mixed_document.pdf')).writeAsString('''
%PDF-1.4
1 0 obj
<< /Type /Catalog /Pages 2 0 R >>
endobj
2 0 obj
<< /Type /Pages /Kids [3 0 R] /Count 1 >>
endobj
3 0 obj
<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> /XObject << /Im1 6 0 R >> >> >>
endobj
4 0 obj
<< /Length 180 >>
stream
BT
/F1 12 Tf
50 780 Td
(BAN GIAM HIEU NHA TRUONG - BIEN BAN HOP HOI DONG) Tj
0 -20 Td
(Thoi gian hop: 08:30 ngay 15/09/2026 tai phong hoi thao.) Tj
ET
q
200 0 0 150 50 550 cm
/Im1 Do
Q
endstream
endobj
5 0 obj
<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>
endobj
6 0 obj
<< /Type /XObject /Subtype /Image /Width 50 /Height 50 /ColorSpace /DeviceRGB /BitsPerComponent 8 /Length 10 >>
stream
0123456789
endstream
endobj
xref
0 7
0000000000 65535 f
0000000009 00000 n
0000000058 00000 n
0000000115 00000 n
0000000268 00000 n
0000000501 00000 n
0000000578 00000 n
trailer
<< /Size 7 /Root 1 0 R >>
startxref
715
%%EOF
'''.trim());

  // 4. Table PDF (Contains table format with pipes and columns)
  await File(p.join(fixturesDir.path, '04_table.pdf')).writeAsString('''
%PDF-1.4
1 0 obj
<< /Type /Catalog /Pages 2 0 R >>
endobj
2 0 obj
<< /Type /Pages /Kids [3 0 R] /Count 1 >>
endobj
3 0 obj
<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>
endobj
4 0 obj
<< /Length 320 >>
stream
BT
/F1 12 Tf
50 780 Td
(DANH SACH HOC SINH DAT THANH TICH XUAT SAC) Tj
0 -30 Td
(| STT | Ho va ten | Lop | Diem TB | Xep loai |) Tj
0 -20 Td
(| 1 | Nguyen Van An | 9A1 | 9.5 | Xuat sac |) Tj
0 -20 Td
(| 2 | Tran Thi Mai | 9A1 | 9.3 | Xuat sac |) Tj
0 -20 Td
(| 3 | Le Hoang Nam | 9A2 | 9.0 | Gioi |) Tj
0 -20 Td
(| 4 | Pham Thu Huong | 9A3 | 9.1 | Gioi |) Tj
ET
endstream
endobj
5 0 obj
<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>
endobj
xref
0 6
0000000000 65535 f
0000000009 00000 n
0000000058 00000 n
0000000115 00000 n
0000000244 00000 n
0000000615 00000 n
trailer
<< /Size 6 /Root 1 0 R >>
startxref
692
%%EOF
'''.trim());

  // 5. Multi-Page PDF (Contains 3 pages)
  await File(p.join(fixturesDir.path, '05_multi_page.pdf')).writeAsString('''
%PDF-1.4
1 0 obj
<< /Type /Catalog /Pages 2 0 R >>
endobj
2 0 obj
<< /Type /Pages /Kids [3 0 R 6 0 R 8 0 R] /Count 3 >>
endobj
3 0 obj
<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>
endobj
4 0 obj
<< /Length 120 >>
stream
BT
/F1 14 Tf
50 750 Td
(TRANG 1 - PHAN MO DAU VA QUY DINH CHUNG) Tj
ET
endstream
endobj
5 0 obj
<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>
endobj
6 0 obj
<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Contents 7 0 R /Resources << /Font << /F1 5 0 R >> >> >>
endobj
7 0 obj
<< /Length 120 >>
stream
BT
/F1 14 Tf
50 750 Td
(TRANG 2 - NOI DUNG CHI TIET VA HUONG DAN THUC HIEN) Tj
ET
endstream
endobj
8 0 obj
<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Contents 9 0 R /Resources << /Font << /F1 5 0 R >> >> >>
endobj
9 0 obj
<< /Length 120 >>
stream
BT
/F1 14 Tf
50 750 Td
(TRANG 3 - DIEU KHOAN THI HANH VA KY TEN DONG DAU) Tj
ET
endstream
endobj
xref
0 10
0000000000 65535 f
0000000009 00000 n
0000000058 00000 n
0000000127 00000 n
0000000256 00000 n
0000000429 00000 n
0000000506 00000 n
0000000635 00000 n
0000000818 00000 n
0000000947 00000 n
trailer
<< /Size 10 /Root 1 0 R >>
startxref
1130
%%EOF
'''.trim());

  // 6. Rotated Scan PDF (Contains scan with rotation flag /Rotate 90)
  await File(p.join(fixturesDir.path, '06_rotated_scan.pdf')).writeAsString('''
%PDF-1.4
1 0 obj
<< /Type /Catalog /Pages 2 0 R >>
endobj
2 0 obj
<< /Type /Pages /Kids [3 0 R] /Count 1 >>
endobj
3 0 obj
<< /Type /Page /Parent 2 0 R /Rotate 90 /MediaBox [0 0 595 842] /Contents 4 0 R /Resources << /XObject << /Im1 5 0 R >> >> >>
endobj
4 0 obj
<< /Length 45 >>
stream
q
500 0 0 700 50 50 cm
/Im1 Do
Q
endstream
endobj
5 0 obj
<< /Type /XObject /Subtype /Image /Width 100 /Height 100 /ColorSpace /DeviceRGB /BitsPerComponent 8 /Length 10 >>
stream
0123456789
endstream
endobj
xref
0 6
0000000000 65535 f
0000000009 00000 n
0000000058 00000 n
0000000115 00000 n
0000000254 00000 n
0000000352 00000 n
trailer
<< /Size 6 /Root 1 0 R >>
startxref
492
%%EOF
'''.trim());

  stdout.writeln('Generated 6 PDF fixtures successfully in \${fixturesDir.path}');
}
