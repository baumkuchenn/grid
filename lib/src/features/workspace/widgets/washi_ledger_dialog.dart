import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../rust/api/simple.dart';
import 'data_grid_view.dart';

class WashiLedgerDialog extends StatelessWidget {
  final List<String> columns;
  final List<List<String>> rows;
  final String title;

  // The preview stays capped for responsiveness; copy/export still uses all rows.
  final QueryResult _previewResult;

  WashiLedgerDialog({
    super.key,
    required this.columns,
    required this.rows,
    required this.title,
  }) : _previewResult = QueryResult(
         columns: columns,
         rows: rows.take(150).toList(),
       );

  static Future<void> show({
    required BuildContext context,
    required List<String> columns,
    required List<List<String>> rows,
    required String title,
  }) async {
    return showDialog(
      context: context,
      builder: (context) =>
          WashiLedgerDialog(columns: columns, rows: rows, title: title),
    );
  }

  String _generateCsv() {
    final buffer = StringBuffer();

    // Header
    for (int i = 0; i < columns.length; i++) {
      if (i > 0) buffer.write(',');
      buffer.write('"');
      buffer.write(columns[i].replaceAll('"', '""'));
      buffer.write('"');
    }
    buffer.writeln();

    // Rows
    for (final row in rows) {
      for (int i = 0; i < row.length; i++) {
        if (i > 0) buffer.write(',');
        buffer.write('"');
        buffer.write(row[i].replaceAll('"', '""'));
        buffer.write('"');
      }
      buffer.writeln();
    }
    return buffer.toString();
  }

  String _generateMarkdown() {
    final buffer = StringBuffer();

    // Header
    buffer.write('| ');
    for (int i = 0; i < columns.length; i++) {
      if (i > 0) buffer.write(' | ');
      buffer.write(columns[i]);
    }
    buffer.writeln(' |');

    // Divider
    buffer.write('| ');
    for (int i = 0; i < columns.length; i++) {
      if (i > 0) buffer.write(' | ');
      buffer.write('---');
    }
    buffer.writeln(' |');

    // Rows
    for (final row in rows) {
      buffer.write('| ');
      for (int i = 0; i < row.length; i++) {
        if (i > 0) buffer.write(' | ');
        buffer.write(row[i]);
      }
      buffer.writeln(' |');
    }
    return buffer.toString();
  }

  void _copyToClipboard(BuildContext context, String text, String formatName) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF5A6B5C), size: 16),
            const SizedBox(width: 8),
            Text(
              "Copied successfully as $formatName!",
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFFFAF8F5),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2D2D2D), // Sumi Ink
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateString = DateTime.now().toIso8601String().substring(0, 10);
    final timeString = DateTime.now().toIso8601String().substring(11, 16);

    return Dialog(
      backgroundColor: const Color(0xFFFAF8F5), // Washi Cream
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(color: Color(0xFFE8E5DF), width: 0.5),
      ),
      child: Container(
        width: 800,
        height: 600,
        padding: const EdgeInsets.all(28),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left Side: The Ledger Sheet
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Red Ledger Header Accents
                  Container(
                    width: 36,
                    height: 2,
                    color: const Color(0xFF7F0019), // Muji Red
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.menu_book,
                        size: 18,
                        color: Color(0xFF73726F),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 15,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2D2D2D),
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "PHYSICAL DATA RECORD / ARCHIVE SHEET",
                    style: TextStyle(
                      fontSize: 10,
                      color: Color(0xFF73726F),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Color(0xFFE8E5DF)),
                  const SizedBox(height: 16),

                  // Scrollable Lined Paper Ledger
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          color: const Color(0xFFE8E5DF),
                          width: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: buildDataGrid(context, _previewResult),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 24),

            // Right Side: The Muji Tag/Receipt Metadata Card
            Container(
              width: 240,
              decoration: BoxDecoration(
                color: const Color(0xFFF3EFE9), // Kraft Sand paper
                border: Border.all(color: const Color(0xFFE8E5DF)),
                borderRadius: BorderRadius.circular(4),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Receipt Barcode Pattern (Aesthetic CSS Representation)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(
                      14,
                      (index) => Container(
                        width: index % 3 == 0 ? 4 : (index % 2 == 0 ? 2 : 1),
                        height: 20,
                        color: const Color(0xFF73726F),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "GRID LEDGER SYSTEM",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2D2D2D),
                      letterSpacing: 1.0,
                    ),
                  ),
                  const Text(
                    "MATERIAL / UNBLEACHED WASHI",
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF73726F),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 1, color: Color(0xFFE8E5DF)),
                  const SizedBox(height: 16),

                  _buildTagRow(
                    "LEDGER ID",
                    title.toLowerCase().hashCode.abs().toString().substring(
                      0,
                      8,
                    ),
                  ),
                  _buildTagRow("RECORD DATE", dateString),
                  _buildTagRow("RECORD TIME", timeString),
                  _buildTagRow("TOTAL ROWS", "${rows.length} LINES"),
                  _buildTagRow("COLUMNS", "${columns.length} VALS"),

                  const Spacer(),
                  const Divider(height: 1, color: Color(0xFFE8E5DF)),
                  const SizedBox(height: 20),

                  // Copy Actions
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _copyToClipboard(context, _generateCsv(), "CSV"),
                      icon: const Icon(
                        Icons.copy,
                        size: 14,
                        color: Colors.white,
                      ),
                      label: const Text(
                        "COPY CSV",
                        style: TextStyle(fontSize: 11),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7F0019), // Muji Red
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _copyToClipboard(
                        context,
                        _generateMarkdown(),
                        "Markdown Table",
                      ),
                      icon: const Icon(
                        Icons.table_rows_outlined,
                        size: 14,
                        color: Color(0xFF2D2D2D),
                      ),
                      label: const Text(
                        "COPY MARKDOWN",
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF2D2D2D),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: Color(0xFF73726F),
                          width: 0.8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "DONE",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                          color: Color(0xFF73726F),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: Color(0xFF73726F),
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                value,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2D2D2D),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
