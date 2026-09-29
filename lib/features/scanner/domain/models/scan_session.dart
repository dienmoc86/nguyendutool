import 'scan_options.dart';
import 'scan_page.dart';

/// Represents an ongoing or saved scanning session containing one or more pages.
class ScanSession {
  final String id;
  final String name;
  final ScanSource sourceType;
  final List<ScanPage> pages;
  final String status; // 'active', 'completed', 'cancelled'
  final DateTime createdAt;
  final DateTime updatedAt;

  const ScanSession({
    required this.id,
    required this.name,
    required this.sourceType,
    this.pages = const [],
    this.status = 'active',
    required this.createdAt,
    required this.updatedAt,
  });

  int get pageCount => pages.length;
  bool get isEmpty => pages.isEmpty;
  bool get isNotEmpty => pages.isNotEmpty;

  ScanSession copyWith({
    String? id,
    String? name,
    ScanSource? sourceType,
    List<ScanPage>? pages,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ScanSession(
      id: id ?? this.id,
      name: name ?? this.name,
      sourceType: sourceType ?? this.sourceType,
      pages: pages ?? this.pages,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Adds a page to the session and recalculates indices.
  ScanSession addPage(ScanPage page) {
    final updatedPages = List<ScanPage>.from(pages)..add(page);
    return _withReindexedPages(updatedPages);
  }

  /// Removes a page by index.
  ScanSession removePageAt(int index) {
    if (index < 0 || index >= pages.length) return this;
    final updatedPages = List<ScanPage>.from(pages)..removeAt(index);
    return _withReindexedPages(updatedPages);
  }

  /// Duplicates a page at index.
  ScanSession duplicatePageAt(int index, String newId) {
    if (index < 0 || index >= pages.length) return this;
    final source = pages[index];
    final duplicate = source.copyWith(
      id: newId,
      createdAt: DateTime.now(),
    );
    final updatedPages = List<ScanPage>.from(pages)..insert(index + 1, duplicate);
    return _withReindexedPages(updatedPages);
  }

  /// Moves page from oldIndex to newIndex.
  ScanSession reorderPage(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= pages.length) return this;
    if (newIndex < 0 || newIndex >= pages.length) return this;
    final updatedPages = List<ScanPage>.from(pages);
    final page = updatedPages.removeAt(oldIndex);
    updatedPages.insert(newIndex, page);
    return _withReindexedPages(updatedPages);
  }

  /// Rotates a page by deltaDegrees (e.g. +90 or -90).
  ScanSession rotatePageAt(int index, int deltaDegrees) {
    if (index < 0 || index >= pages.length) return this;
    final currentRotation = pages[index].rotation;
    final newRotation = (currentRotation + deltaDegrees) % 360;
    final normalized = newRotation < 0 ? newRotation + 360 : newRotation;

    final updatedPage = pages[index].copyWith(
      rotation: normalized,
      processingOptions: pages[index].processingOptions.copyWith(rotationDegrees: normalized),
    );
    final updatedPages = List<ScanPage>.from(pages);
    updatedPages[index] = updatedPage;
    return copyWith(pages: updatedPages, updatedAt: DateTime.now());
  }

  /// Updates a specific page at index.
  ScanSession updatePageAt(int index, ScanPage updatedPage) {
    if (index < 0 || index >= pages.length) return this;
    final updatedPages = List<ScanPage>.from(pages);
    updatedPages[index] = updatedPage;
    return copyWith(pages: updatedPages, updatedAt: DateTime.now());
  }

  ScanSession _withReindexedPages(List<ScanPage> updatedPages) {
    final reindexed = <ScanPage>[];
    for (int i = 0; i < updatedPages.length; i++) {
      reindexed.add(updatedPages[i].copyWith(pageIndex: i));
    }
    return copyWith(pages: reindexed, updatedAt: DateTime.now());
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sourceType': sourceType.name,
        'pages': pages.map((p) => p.toJson()).toList(),
        'status': status,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}
