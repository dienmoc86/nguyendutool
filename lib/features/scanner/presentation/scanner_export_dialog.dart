import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../../app/theme/app_colors.dart';
import '../domain/models/scan_options.dart';

/// Modal dialog for configuring and launching document export (Searchable PDF, DOCX, TXT, Images).
class ScannerExportDialog extends StatefulWidget {
  final int totalPages;
  final int currentPageIndex;
  final ValueChanged<ScanOutputOptions> onExport;

  const ScannerExportDialog({
    super.key,
    required this.totalPages,
    required this.currentPageIndex,
    required this.onExport,
  });

  @override
  State<ScannerExportDialog> createState() => _ScannerExportDialogState();
}

class _ScannerExportDialogState extends State<ScannerExportDialog> {
  ScanOutputFormat _selectedFormat = ScanOutputFormat.searchablePdf;
  ScanOutputQuality _selectedQuality = ScanOutputQuality.balanced;
  String _selectedLanguage = 'vie';
  bool _exportAllPages = true;
  late final TextEditingController _filenameController;
  late final TextEditingController _outputFolderController;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    _filenameController = TextEditingController(text: 'Scan_Document_$dateStr');
    final defaultDir = p.join(Directory.current.path, 'output');
    _outputFolderController = TextEditingController(text: defaultDir);
  }

  @override
  void dispose() {
    _filenameController.dispose();
    _outputFolderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.output_rounded, color: AppColors.moduleScanner),
          SizedBox(width: 10),
          Text('Xuất tài liệu quét', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Export Format
              const Text('Định dạng xuất:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              DropdownButtonFormField<ScanOutputFormat>(
                value: _selectedFormat,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: ScanOutputFormat.values.map((f) {
                  return DropdownMenuItem(
                    value: f,
                    child: Text(f.label, style: const TextStyle(fontSize: 13)),
                  );
                }).toList(),
                onChanged: (f) {
                  if (f != null) setState(() => _selectedFormat = f);
                },
              ),
              const SizedBox(height: 14),

              // Page Range
              const Text('Phạm vi trang:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Radio<bool>(
                    value: true,
                    groupValue: _exportAllPages,
                    onChanged: (val) => setState(() => _exportAllPages = val ?? true),
                  ),
                  Text('Tất cả ${widget.totalPages} trang', style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 20),
                  Radio<bool>(
                    value: false,
                    groupValue: _exportAllPages,
                    onChanged: (val) => setState(() => _exportAllPages = val ?? false),
                  ),
                  Text('Chỉ trang hiện tại (Trang ${widget.currentPageIndex + 1})',
                      style: const TextStyle(fontSize: 13)),
                ],
              ),
              const SizedBox(height: 14),

              // Quality Preset (for PDF / Images)
              if (_selectedFormat == ScanOutputFormat.searchablePdf ||
                  _selectedFormat == ScanOutputFormat.standardPdf ||
                  _selectedFormat == ScanOutputFormat.images) ...[
                const Text('Mức chất lượng ảnh nén:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<ScanOutputQuality>(
                  value: _selectedQuality,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: ScanOutputQuality.values.map((q) {
                    return DropdownMenuItem(
                      value: q,
                      child: Text(q.label, style: const TextStyle(fontSize: 13)),
                    );
                  }).toList(),
                  onChanged: (q) {
                    if (q != null) setState(() => _selectedQuality = q);
                  },
                ),
                const SizedBox(height: 14),
              ],

              // OCR Language
              if (_selectedFormat == ScanOutputFormat.searchablePdf ||
                  _selectedFormat == ScanOutputFormat.docx ||
                  _selectedFormat == ScanOutputFormat.pptx ||
                  _selectedFormat == ScanOutputFormat.txt) ...[
                const Text('Ngôn ngữ nhận dạng OCR:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _selectedLanguage,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'vie', child: Text('Tiếng Việt (vi-VN)')),
                    DropdownMenuItem(value: 'eng', child: Text('Tiếng Anh (en-US)')),
                    DropdownMenuItem(value: 'vie+eng', child: Text('Song ngữ Việt + Anh')),
                  ],
                  onChanged: (l) {
                    if (l != null) setState(() => _selectedLanguage = l);
                  },
                ),
                const SizedBox(height: 14),
              ],

              // Output Filename & Folder
              const Text('Tên tệp xuất:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: _filenameController,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  suffixText: _selectedFormat.extension,
                ),
              ),
              const SizedBox(height: 14),

              const Text('Thư mục lưu trữ:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: _outputFolderController,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
        ),
        FilledButton.icon(
          onPressed: _handleExport,
          icon: const Icon(Icons.file_download_rounded, size: 18),
          label: const Text('Bắt đầu xuất'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.moduleScanner),
        ),
      ],
    );
  }

  void _handleExport() {
    final folder = _outputFolderController.text.trim();
    var filename = _filenameController.text.trim();
    if (!filename.endsWith(_selectedFormat.extension)) {
      filename = '$filename${_selectedFormat.extension}';
    }
    final fullOutPath = p.join(folder, filename);

    final List<int>? indices = _exportAllPages ? null : [widget.currentPageIndex];

    final options = ScanOutputOptions(
      format: _selectedFormat,
      outputPath: fullOutPath,
      quality: _selectedQuality,
      enableOcr: true,
      ocrLanguage: _selectedLanguage,
      pageIndices: indices,
    );

    Navigator.of(context).pop();
    widget.onExport(options);
  }
}
