import '../domain/models/ocr_models.dart';
import '../domain/models/table_models.dart';

/// Detects and reconstructs tabular structures from extracted text blocks and lines.
class TableDetector {
  /// Detects tables from a list of OCR text blocks or raw text lines.
  static List<TableModel> detectTables(List<OcrTextBlock> blocks, {int pageNumber = 1}) {
    final tables = <TableModel>[];

    // 1. Check for pipe/tab delimited tables
    final textLines = blocks.expand((b) => b.text.split('\n')).toList();
    final delimitedTable = _detectDelimitedTable(textLines, pageNumber: pageNumber);
    if (delimitedTable != null) {
      tables.add(delimitedTable);
      return tables;
    }

    // 2. Spatial column alignment detection
    final spatialTable = _detectSpatialTable(blocks, pageNumber: pageNumber);
    if (spatialTable != null) {
      tables.add(spatialTable);
    }

    return tables;
  }

  /// Detects tables formatted with pipes '|' or tabs '\t'.
  static TableModel? _detectDelimitedTable(List<String> lines, {int pageNumber = 1}) {
    final tableLines = <List<String>>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.contains('|')) {
        final cells = trimmed
            .split('|')
            .map((c) => c.trim())
            .where((c) => c.isNotEmpty)
            .toList();
        if (cells.length >= 2) {
          // Ignore separator lines like "|---|---|"
          if (!cells.every((c) => RegExp(r'^-+$').hasMatch(c))) {
            tableLines.add(cells);
          }
        }
      } else if (trimmed.contains('\t\t') || (trimmed.contains('\t') && trimmed.split('\t').length >= 3)) {
        final cells = trimmed.split('\t').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
        if (cells.length >= 2) {
          tableLines.add(cells);
        }
      }
    }

    if (tableLines.length >= 2) {
      // Find max column count
      int maxCols = 0;
      for (final r in tableLines) {
        if (r.length > maxCols) maxCols = r.length;
      }

      final rows = <TableRow>[];
      for (int rIdx = 0; rIdx < tableLines.length; rIdx++) {
        final rawCells = tableLines[rIdx];
        final cells = <TableCell>[];
        for (int cIdx = 0; cIdx < maxCols; cIdx++) {
          final text = cIdx < rawCells.length ? rawCells[cIdx] : '';
          cells.add(
            TableCell(
              text: text,
              rowIndex: rIdx,
              colIndex: cIdx,
              isHeader: rIdx == 0,
            ),
          );
        }
        rows.add(TableRow(cells: cells, isHeader: rIdx == 0));
      }

      return TableModel(
        rows: rows,
        colCount: maxCols,
        rowCount: rows.length,
        pageNumber: pageNumber,
      );
    }

    return null;
  }

  /// Detects table structures based on spatial bounding box column alignments.
  static TableModel? _detectSpatialTable(List<OcrTextBlock> blocks, {int pageNumber = 1}) {
    if (blocks.length < 4) return null;

    // Group blocks by approximate Y coordinate (rows)
    final rowsMap = <int, List<OcrTextBlock>>{};
    const rowTolerance = 12.0;

    for (final block in blocks) {
      final y = block.box.top;
      int? foundKey;
      for (final key in rowsMap.keys) {
        if ((key - y).abs() <= rowTolerance) {
          foundKey = key;
          break;
        }
      }

      if (foundKey != null) {
        rowsMap[foundKey]!.add(block);
      } else {
        rowsMap[y.round()] = [block];
      }
    }

    // Filter rows that have at least 2 horizontally separated columns
    final candidateRows = rowsMap.values.where((r) => r.length >= 2).toList();
    if (candidateRows.length < 2) return null;

    // Sort blocks in each row by X coordinate (left to right)
    for (final row in candidateRows) {
      row.sort((a, b) => a.box.left.compareTo(b.box.left));
    }

    int maxCols = 0;
    for (final r in candidateRows) {
      if (r.length > maxCols) maxCols = r.length;
    }

    final tableRows = <TableRow>[];
    for (int rIdx = 0; rIdx < candidateRows.length; rIdx++) {
      final rowBlocks = candidateRows[rIdx];
      final cells = <TableCell>[];
      for (int cIdx = 0; cIdx < maxCols; cIdx++) {
        final text = cIdx < rowBlocks.length ? rowBlocks[cIdx].text : '';
        cells.add(
          TableCell(
            text: text,
            rowIndex: rIdx,
            colIndex: cIdx,
            isHeader: rIdx == 0,
          ),
        );
      }
      tableRows.add(TableRow(cells: cells, isHeader: rIdx == 0));
    }

    return TableModel(
      rows: tableRows,
      colCount: maxCols,
      rowCount: tableRows.length,
      pageNumber: pageNumber,
    );
  }
}
