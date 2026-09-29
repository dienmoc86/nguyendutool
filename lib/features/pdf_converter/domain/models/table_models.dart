/// Representation of a single table cell in an extracted document table.
class TableCell {
  final String text;
  final int rowIndex;
  final int colIndex;
  final int rowSpan;
  final int colSpan;
  final bool isHeader;
  final double? width;
  final String alignment; // 'left', 'center', 'right'

  const TableCell({
    required this.text,
    required this.rowIndex,
    required this.colIndex,
    this.rowSpan = 1,
    this.colSpan = 1,
    this.isHeader = false,
    this.width,
    this.alignment = 'left',
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'rowIndex': rowIndex,
    'colIndex': colIndex,
    'rowSpan': rowSpan,
    'colSpan': colSpan,
    'isHeader': isHeader,
    'width': width,
    'alignment': alignment,
  };

  factory TableCell.fromJson(Map<String, dynamic> json) => TableCell(
    text: json['text'] as String? ?? '',
    rowIndex: json['rowIndex'] as int? ?? 0,
    colIndex: json['colIndex'] as int? ?? 0,
    rowSpan: json['rowSpan'] as int? ?? 1,
    colSpan: json['colSpan'] as int? ?? 1,
    isHeader: json['isHeader'] as bool? ?? false,
    width: (json['width'] as num?)?.toDouble(),
    alignment: json['alignment'] as String? ?? 'left',
  );
}

/// Representation of a row of cells in a table.
class TableRow {
  final List<TableCell> cells;
  final bool isHeader;

  const TableRow({
    required this.cells,
    this.isHeader = false,
  });

  Map<String, dynamic> toJson() => {
    'cells': cells.map((c) => c.toJson()).toList(),
    'isHeader': isHeader,
  };

  factory TableRow.fromJson(Map<String, dynamic> json) => TableRow(
    cells: (json['cells'] as List<dynamic>?)
            ?.map((c) => TableCell.fromJson(c as Map<String, dynamic>))
            .toList() ??
        const [],
    isHeader: json['isHeader'] as bool? ?? false,
  );
}

/// Complete tabular structure extracted from a document.
class TableModel {
  final List<TableRow> rows;
  final int colCount;
  final int rowCount;
  final String? caption;
  final int pageNumber;

  const TableModel({
    required this.rows,
    required this.colCount,
    required this.rowCount,
    this.caption,
    this.pageNumber = 1,
  });

  bool get isEmpty => rows.isEmpty;
  bool get isNotEmpty => rows.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'rows': rows.map((r) => r.toJson()).toList(),
    'colCount': colCount,
    'rowCount': rowCount,
    'caption': caption,
    'pageNumber': pageNumber,
  };

  factory TableModel.fromJson(Map<String, dynamic> json) => TableModel(
    rows: (json['rows'] as List<dynamic>?)
            ?.map((r) => TableRow.fromJson(r as Map<String, dynamic>))
            .toList() ??
        const [],
    colCount: json['colCount'] as int? ?? 0,
    rowCount: json['rowCount'] as int? ?? 0,
    caption: json['caption'] as String?,
    pageNumber: json['pageNumber'] as int? ?? 1,
  );
}
