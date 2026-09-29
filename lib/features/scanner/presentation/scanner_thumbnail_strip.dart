import 'dart:io';
import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../domain/models/scan_page.dart';

/// Left sidebar listing scanned page thumbnails with reordering, rotation, deletion, and status badges.
class ScannerThumbnailStrip extends StatelessWidget {
  final List<ScanPage> pages;
  final int selectedIndex;
  final ValueChanged<int> onSelectPage;
  final ValueChanged<int> onDeletePage;
  final ValueChanged<int> onDuplicatePage;
  final void Function(int oldIndex, int newIndex) onReorder;
  final VoidCallback onAddPage;

  const ScannerThumbnailStrip({
    super.key,
    required this.pages,
    required this.selectedIndex,
    required this.onSelectPage,
    required this.onDeletePage,
    required this.onDuplicatePage,
    required this.onReorder,
    required this.onAddPage,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        border: Border(
          right: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Danh sách trang (${pages.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                IconButton(
                  icon: const Icon(Icons.add_photo_alternate_rounded, size: 20),
                  tooltip: 'Thêm trang mới',
                  onPressed: onAddPage,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),

          // Reorderable Thumbnails List
          Expanded(
            child: pages.isEmpty
                ? const Center(
                    child: Text(
                      'Chưa có trang nào',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                    itemCount: pages.length,
                    onReorder: (oldIndex, newIndex) {
                      if (oldIndex < newIndex) {
                        newIndex -= 1;
                      }
                      onReorder(oldIndex, newIndex);
                    },
                    itemBuilder: (context, index) {
                      final page = pages[index];
                      final isSelected = index == selectedIndex;
                      final imagePath = File(page.processedPath).existsSync()
                          ? page.processedPath
                          : page.originalPath;

                      return Container(
                        key: ValueKey(page.id),
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => onSelectPage(index),
                            borderRadius: BorderRadius.circular(10),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.moduleScanner
                                      : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                                  width: isSelected ? 2 : 1,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: AppColors.moduleScanner.withOpacity(0.15),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Thumbnail preview
                                  Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: AspectRatio(
                                          aspectRatio: 0.75,
                                          child: File(imagePath).existsSync()
                                              ? Image.file(
                                                  File(imagePath),
                                                  fit: BoxFit.cover,
                                                )
                                              : Container(
                                                  color: Colors.grey[300],
                                                  child: const Icon(Icons.broken_image, size: 28),
                                                ),
                                        ),
                                      ),
                                      // Page number badge
                                      Positioned(
                                        top: 6,
                                        left: 6,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.7),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '${index + 1}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Blank page warning badge
                                      if (page.isLikelyBlank)
                                        Positioned(
                                          top: 6,
                                          right: 6,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.withOpacity(0.9),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'Trống',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  // Quick Action buttons
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      // OCR badge if recognized
                                      if (page.ocrStatus == 'done')
                                        const Tooltip(
                                          message: 'Đã nhận dạng OCR',
                                          child: Icon(Icons.check_circle_rounded, size: 14, color: Colors.green),
                                        )
                                      else
                                        const SizedBox(width: 14),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.copy_rounded, size: 14),
                                            tooltip: 'Nhân bản trang',
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                            onPressed: () => onDuplicatePage(index),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline_rounded, size: 14, color: Colors.red),
                                            tooltip: 'Xóa trang',
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                            onPressed: () => onDeletePage(index),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
