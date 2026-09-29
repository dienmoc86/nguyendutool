import 'dart:io';
import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../pdf_converter/domain/models/ocr_models.dart';
import '../application/scanner_state.dart';
import '../domain/models/document_quad.dart';
import '../domain/models/scan_page.dart';

/// Center preview viewport displaying high-resolution document page,
/// interactive zoom & pan, manual 4-corner adjustment handles, and OCR bounding box overlays.
class ScannerPreviewViewport extends StatelessWidget {
  final ScanPage? page;
  final ScanPreviewMode previewMode;
  final bool isManualCropMode;
  final DocumentQuad? pendingManualQuad;
  final ValueChanged<DocumentQuad> onManualQuadChanged;
  final VoidCallback onApplyCrop;
  final VoidCallback onCancelCrop;
  final ValueChanged<ScanPreviewMode> onPreviewModeChanged;

  const ScannerPreviewViewport({
    super.key,
    required this.page,
    required this.previewMode,
    required this.isManualCropMode,
    required this.pendingManualQuad,
    required this.onManualQuadChanged,
    required this.onApplyCrop,
    required this.onCancelCrop,
    required this.onPreviewModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (page == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            const Text('Chưa có trang nào được chọn', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    final displayPath = (previewMode == ScanPreviewMode.original || isManualCropMode)
        ? page!.originalPath
        : page!.processedPath;

    final imageFile = File(displayPath);
    if (!imageFile.existsSync()) {
      return const Center(child: Text('Tệp ảnh không tồn tại trên đĩa'));
    }

    return Container(
      color: isDark ? const Color(0xFF020617) : const Color(0xFFE2E8F0),
      child: Column(
        children: [
          // Top Viewport Mode Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                ),
              ),
            ),
            child: Row(
              children: [
                // Preview mode segmented control
                SegmentedButton<ScanPreviewMode>(
                  segments: const [
                    ButtonSegment(
                      value: ScanPreviewMode.processed,
                      label: Text('Đã xử lý'),
                      icon: Icon(Icons.auto_fix_high_rounded, size: 16),
                    ),
                    ButtonSegment(
                      value: ScanPreviewMode.original,
                      label: Text('Ảnh gốc'),
                      icon: Icon(Icons.image_outlined, size: 16),
                    ),
                    ButtonSegment(
                      value: ScanPreviewMode.ocrOverlay,
                      label: Text('Lớp OCR'),
                      icon: Icon(Icons.text_fields_rounded, size: 16),
                    ),
                  ],
                  selected: {previewMode},
                  onSelectionChanged: (set) => onPreviewModeChanged(set.first),
                  style: SegmentedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const Spacer(),
                if (isManualCropMode) ...[
                  TextButton.icon(
                    onPressed: onCancelCrop,
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Hủy'),
                    style: TextButton.styleFrom(foregroundColor: Colors.grey),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: onApplyCrop,
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Áp dụng cắt & nắn góc'),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.moduleScanner),
                  ),
                ],
              ],
            ),
          ),

          // Main Interactive Zoom Viewport
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return InteractiveViewer(
                  boundaryMargin: const EdgeInsets.all(80),
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(
                    child: FutureBuilder<Size>(
                      future: _getImageSize(imageFile),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final imgSize = snapshot.data!;
                        // Calculate aspect-fit box inside viewport
                        final maxW = constraints.maxWidth - 40;
                        final maxH = constraints.maxHeight - 40;
                        final scaleW = maxW / imgSize.width;
                        final scaleH = maxH / imgSize.height;
                        final scale = scaleW < scaleH ? scaleW : scaleH;

                        final displayW = imgSize.width * scale;
                        final displayH = imgSize.height * scale;

                        return Container(
                          width: displayW,
                          height: displayH,
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Background Image
                              Image.file(imageFile, fit: BoxFit.fill),

                              // Manual 4-Corner Draggable Quad Overlay
                              if (isManualCropMode && pendingManualQuad != null)
                                _ManualQuadOverlay(
                                  quad: pendingManualQuad!,
                                  imgWidth: imgSize.width,
                                  imgHeight: imgSize.height,
                                  displayW: displayW,
                                  displayH: displayH,
                                  onQuadChanged: onManualQuadChanged,
                                ),

                              // OCR Bounding Boxes Overlay
                              if (previewMode == ScanPreviewMode.ocrOverlay &&
                                  page!.ocrResult != null &&
                                  page!.ocrResult!.blocks.isNotEmpty)
                                _OcrBlocksOverlay(
                                  blocks: page!.ocrResult!.blocks,
                                  imgWidth: imgSize.width,
                                  imgHeight: imgSize.height,
                                  displayW: displayW,
                                  displayH: displayH,
                                ),
                            ],
                          ),
                        );
                      },
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

  Future<Size> _getImageSize(File file) async {
    final bytes = await file.readAsBytes();
    final decoded = await decodeImageFromList(bytes);
    return Size(decoded.width.toDouble(), decoded.height.toDouble());
  }
}

/// Interactive 4-corner draggable handles overlay for manual perspective crop.
class _ManualQuadOverlay extends StatelessWidget {
  final DocumentQuad quad;
  final double imgWidth;
  final double imgHeight;
  final double displayW;
  final double displayH;
  final ValueChanged<DocumentQuad> onQuadChanged;

  const _ManualQuadOverlay({
    required this.quad,
    required this.imgWidth,
    required this.imgHeight,
    required this.displayW,
    required this.displayH,
    required this.onQuadChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scaleX = displayW / imgWidth;
    final scaleY = displayH / imgHeight;

    final tlX = quad.topLeft.x * scaleX;
    final tlY = quad.topLeft.y * scaleY;
    final trX = quad.topRight.x * scaleX;
    final trY = quad.topRight.y * scaleY;
    final brX = quad.bottomRight.x * scaleX;
    final brY = quad.bottomRight.y * scaleY;
    final blX = quad.bottomLeft.x * scaleX;
    final blY = quad.bottomLeft.y * scaleY;

    return Stack(
      children: [
        // Connecting polygon outline
        CustomPaint(
          size: Size(displayW, displayH),
          painter: _QuadPainter(
            tl: Offset(tlX, tlY),
            tr: Offset(trX, trY),
            br: Offset(brX, brY),
            bl: Offset(blX, blY),
          ),
        ),

        // Corner Handles
        _buildHandle(
          pos: Offset(tlX, tlY),
          onDrag: (delta) {
            final newX = (quad.topLeft.x + delta.dx / scaleX).clamp(0.0, imgWidth);
            final newY = (quad.topLeft.y + delta.dy / scaleY).clamp(0.0, imgHeight);
            onQuadChanged(
              DocumentQuad(
                topLeft: Point2D(newX, newY),
                topRight: quad.topRight,
                bottomRight: quad.bottomRight,
                bottomLeft: quad.bottomLeft,
              ),
            );
          },
        ),
        _buildHandle(
          pos: Offset(trX, trY),
          onDrag: (delta) {
            final newX = (quad.topRight.x + delta.dx / scaleX).clamp(0.0, imgWidth);
            final newY = (quad.topRight.y + delta.dy / scaleY).clamp(0.0, imgHeight);
            onQuadChanged(
              DocumentQuad(
                topLeft: quad.topLeft,
                topRight: Point2D(newX, newY),
                bottomRight: quad.bottomRight,
                bottomLeft: quad.bottomLeft,
              ),
            );
          },
        ),
        _buildHandle(
          pos: Offset(brX, brY),
          onDrag: (delta) {
            final newX = (quad.bottomRight.x + delta.dx / scaleX).clamp(0.0, imgWidth);
            final newY = (quad.bottomRight.y + delta.dy / scaleY).clamp(0.0, imgHeight);
            onQuadChanged(
              DocumentQuad(
                topLeft: quad.topLeft,
                topRight: quad.topRight,
                bottomRight: Point2D(newX, newY),
                bottomLeft: quad.bottomLeft,
              ),
            );
          },
        ),
        _buildHandle(
          pos: Offset(blX, blY),
          onDrag: (delta) {
            final newX = (quad.bottomLeft.x + delta.dx / scaleX).clamp(0.0, imgWidth);
            final newY = (quad.bottomLeft.y + delta.dy / scaleY).clamp(0.0, imgHeight);
            onQuadChanged(
              DocumentQuad(
                topLeft: quad.topLeft,
                topRight: quad.topRight,
                bottomRight: quad.bottomRight,
                bottomLeft: Point2D(newX, newY),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildHandle({required Offset pos, required ValueChanged<Offset> onDrag}) {
    const handleSize = 24.0;
    return Positioned(
      left: pos.dx - handleSize / 2,
      top: pos.dy - handleSize / 2,
      child: GestureDetector(
        onPanUpdate: (details) => onDrag(details.delta),
        child: Container(
          width: handleSize,
          height: handleSize,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.moduleScanner, width: 3),
            boxShadow: const [
              BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
            ],
          ),
          child: const Center(
            child: CircleAvatar(radius: 3, backgroundColor: AppColors.moduleScanner),
          ),
        ),
      ),
    );
  }
}

class _QuadPainter extends CustomPainter {
  final Offset tl;
  final Offset tr;
  final Offset br;
  final Offset bl;

  _QuadPainter({required this.tl, required this.tr, required this.br, required this.bl});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(tl.dx, tl.dy)
      ..lineTo(tr.dx, tr.dy)
      ..lineTo(br.dx, br.dy)
      ..lineTo(bl.dx, bl.dy)
      ..close();

    final fillPaint = Paint()
      ..color = AppColors.moduleScanner.withOpacity(0.15)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    final linePaint = Paint()
      ..color = AppColors.moduleScanner
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _QuadPainter oldDelegate) => true;
}

/// Visual overlay drawing detected OCR bounding boxes and text preview.
class _OcrBlocksOverlay extends StatelessWidget {
  final List<OcrTextBlock> blocks;
  final double imgWidth;
  final double imgHeight;
  final double displayW;
  final double displayH;

  const _OcrBlocksOverlay({
    required this.blocks,
    required this.imgWidth,
    required this.imgHeight,
    required this.displayW,
    required this.displayH,
  });

  @override
  Widget build(BuildContext context) {
    final scaleX = displayW / imgWidth;
    final scaleY = displayH / imgHeight;

    return Stack(
      children: blocks.map((block) {
        final left = block.box.left * scaleX;
        final top = block.box.top * scaleY;
        final w = block.box.width * scaleX;
        final h = block.box.height * scaleY;

        return Positioned(
          left: left,
          top: top,
          width: w,
          height: h,
          child: Tooltip(
            message: block.text,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.18),
                border: Border.all(color: Colors.blue.withOpacity(0.6), width: 1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
