import 'package:flutter/material.dart';
import '../../../rust/api/simple.dart';
import 'sql_text_controller.dart';
import 'data_grid_view.dart';
import 'washi_ledger_dialog.dart';

class QueryEditorView extends StatefulWidget {
  final String connectionUrl;
  final String databaseName;

  const QueryEditorView({
    super.key,
    required this.connectionUrl,
    required this.databaseName,
  });

  @override
  State<QueryEditorView> createState() => QueryEditorViewState();
}

class QueryEditorViewState extends State<QueryEditorView> {
  final SqlTextEditingController _queryController = SqlTextEditingController();
  final FocusNode _editorFocusNode = FocusNode();
  bool _isHovered = false;
  bool _isRunning = false;
  String _error = '';
  QueryResult? _result;

  @override
  void initState() {
    super.initState();
    _editorFocusNode.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _queryController.dispose();
    _editorFocusNode.dispose();
    super.dispose();
  }

  void _copyResultsToClipboard() {
    if (_result == null) return;
    WashiLedgerDialog.show(
      context: context,
      columns: _result!.columns,
      rows: _result!.rows,
      title: "Query Results",
    );
  }

  Future<void> _runQuery() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isRunning = true;
      _error = '';
      _result = null;
    });

    try {
      final res = await runMysqlQuery(
        url: widget.connectionUrl,
        database: widget.databaseName,
        query: query,
      );
      if (mounted) {
        setState(() {
          _result = res;
          _isRunning = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isRunning = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasFocus = _editorFocusNode.hasFocus;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: (hasFocus && !_isHovered) ? 0.15 : 1.0,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.edit_note,
                        size: 16,
                        color: Color(0xFF73726F),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Querying Database: ${widget.databaseName}",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF73726F),
                          letterSpacing: 0.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: const Cubic(0.16, 1, 0.3, 1),
                  decoration: BoxDecoration(
                    color: hasFocus
                        ? const Color(0xFFFAF8F5)
                        : const Color(0xFFF3EFE9),
                    border: Border(
                      left: BorderSide(
                        color: hasFocus
                            ? const Color(0xFF7F0019)
                            : const Color(0xFF73726F),
                        width: 3.0,
                      ),
                      top: const BorderSide(
                        color: Color(0xFFE8E5DF),
                        width: 0.5,
                      ),
                      right: const BorderSide(
                        color: Color(0xFFE8E5DF),
                        width: 0.5,
                      ),
                      bottom: const BorderSide(
                        color: Color(0xFFE8E5DF),
                        width: 0.5,
                      ),
                    ),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(4),
                      bottomRight: Radius.circular(4),
                    ),
                  ),
                  child: TextField(
                    controller: _queryController,
                    focusNode: _editorFocusNode,
                    maxLines: 5,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: Color(0xFF2D2D2D),
                      height: 1.5,
                    ),
                    decoration: const InputDecoration(
                      hintText: "Enter SQL Query here...",
                      hintStyle: TextStyle(color: Color(0xFFC4C2BC)),
                      filled: true,
                      fillColor: Colors.transparent,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: (hasFocus && !_isHovered) ? 0.05 : 1.0,
                  child: IgnorePointer(
                    ignoring: hasFocus && !_isHovered,
                    child: ElevatedButton.icon(
                      onPressed: _isRunning ? null : _runQuery,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D2D2D),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      icon: _isRunning
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 1.5,
                              ),
                            )
                          : const Icon(Icons.play_arrow, size: 14),
                      label: Text(
                        _isRunning ? "RUNNING..." : "RUN QUERY",
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE8E5DF)),
          Expanded(
            child: _isRunning
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF7F0019), // Muji Red loader
                      strokeWidth: 2,
                    ),
                  )
                : _error.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      _error,
                      style: const TextStyle(color: Color(0xFFAC6B62), fontSize: 13), // Terracotta alert
                    ),
                  )
                : _result != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 6,
                        ),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFAF8F5), // Washi Cream Sheet
                          border: Border(
                            bottom: BorderSide(color: Color(0xFFE8E5DF), width: 0.5), // Divider Clay
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              size: 14,
                              color: Color(0xFF5A6B5C), // Moss Green Rest Light
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "${_result!.rows.length} rows returned.",
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF2D2D2D), // Sumi Ink
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(
                                Icons.copy_all,
                                size: 16,
                                color: Color(0xFF73726F), // Wood Ash
                              ),
                              onPressed: _copyResultsToClipboard,
                              tooltip: "Copy Results as CSV",
                            ),
                          ],
                        ),
                      ),
                      Expanded(child: buildDataGrid(context, _result!)),
                    ],
                  )
                : const Center(
                    child: Text(
                      "Run a query to see results.",
                      style: TextStyle(color: Color(0xFF73726F), fontStyle: FontStyle.italic, fontSize: 13), // Wood Ash
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
