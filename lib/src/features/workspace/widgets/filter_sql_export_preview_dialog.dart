import 'package:flutter/material.dart';

enum FilterSqlExportStatus { idle, exporting, success, error }

class FilterSqlExportPreviewDialog extends StatefulWidget {
  final String sql;
  final Future<String?> Function() onExport;

  const FilterSqlExportPreviewDialog({
    super.key,
    required this.sql,
    required this.onExport,
  });

  @override
  State<FilterSqlExportPreviewDialog> createState() =>
      _FilterSqlExportPreviewDialogState();
}

class _FilterSqlExportPreviewDialogState
    extends State<FilterSqlExportPreviewDialog> {
  FilterSqlExportStatus _status = FilterSqlExportStatus.idle;
  String _message = '';

  bool get _isExporting => _status == FilterSqlExportStatus.exporting;

  Future<void> _export() async {
    setState(() {
      _status = FilterSqlExportStatus.exporting;
      _message = 'Choosing destination...';
    });

    try {
      final exportedPath = await widget.onExport();
      if (!mounted) return;

      if (exportedPath == null) {
        setState(() {
          _status = FilterSqlExportStatus.idle;
          _message = '';
        });
        return;
      }

      setState(() {
        _status = FilterSqlExportStatus.success;
        _message = 'Exported to $exportedPath';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = FilterSqlExportStatus.error;
        _message = 'Export failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFFFAF8F5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(color: Color(0xFFE8E5DF), width: 0.5),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "EXPORT FILTER SQL",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2D2D2D),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 18),
              Flexible(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(
                      color: const Color(0xFFE8E5DF),
                      width: 0.5,
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      widget.sql,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        height: 1.5,
                        color: Color(0xFF2D2D2D),
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeInOut,
                child: _message.isEmpty
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_isExporting)
                              const LinearProgressIndicator(
                                minHeight: 2,
                                color: Color(0xFF7F0019),
                                backgroundColor: Color(0xFFE8E5DF),
                              ),
                            if (_isExporting) const SizedBox(height: 10),
                            Text(
                              _message,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _status == FilterSqlExportStatus.success
                                    ? const Color(0xFF5A6B5C)
                                    : _status == FilterSqlExportStatus.error
                                    ? const Color(0xFFAC6B62)
                                    : const Color(0xFF73726F),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isExporting
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text(
                      "CANCEL",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isExporting ? null : _export,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7F0019),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFC4C2BC),
                      disabledForegroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                    child: Text(
                      _isExporting ? "EXPORTING..." : "EXPORT",
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
