import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

import '../../../rust/api/simple.dart';
import '../models/filter_sql_export.dart';
import '../models/table_filter.dart';
import '../models/table_page_sql.dart';
import 'data_grid_view.dart';
import 'filter_sql_export_preview_dialog.dart';
import 'workspace_dialogs.dart';
import 'washi_ledger_dialog.dart';

class TableDataView extends StatefulWidget {
  final String connectionUrl;
  final String databaseName;
  final String tableName;

  const TableDataView({
    super.key,
    required this.connectionUrl,
    required this.databaseName,
    required this.tableName,
  });

  @override
  State<TableDataView> createState() => TableDataViewState();
}

class TableDataViewState extends State<TableDataView> {
  bool _isLoading = true;
  String _error = '';
  QueryResult? _result;

  int _currentPage = 0;
  final int _pageSize = 50;
  int _totalRows = 0;
  bool _isLoadingCount = true;
  int _pageRequestRevision = 0;

  final Set<int> _selectedRowIndices = {};

  String? _sortColumn;
  bool _sortAscending = true;

  // Filter state variables
  final List<TableFilter> _filters = [];
  bool _showFilterBar = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _fetchPage();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Iterable<TableFilter> get _activeFilters =>
      _filters.where(isActiveTableFilter);

  bool get _hasActiveFilters => _filters.any(isActiveTableFilter);

  int? _sortColumnIndexFor(List<String> columns) {
    final sortColumn = _sortColumn;
    if (sortColumn == null) return null;

    final index = columns.indexOf(sortColumn);
    return index == -1 ? null : index;
  }

  void _onSortColumn(int columnIndex) {
    final result = _result;
    if (result == null ||
        columnIndex < 0 ||
        columnIndex >= result.columns.length) {
      return;
    }

    final column = result.columns[columnIndex];
    setState(() {
      _currentPage = 0;
      _selectedRowIndices.clear();

      if (_sortColumn != column) {
        _sortColumn = column;
        _sortAscending = true;
      } else if (_sortAscending) {
        _sortAscending = false;
      } else {
        _sortColumn = null;
        _sortAscending = true;
      }
    });
    _fetchPage();
  }

  void _onFiltersUpdated({bool debounce = false}) {
    setState(() {
      _currentPage = 0;
      _isLoadingCount = true;
    });

    if (debounce) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 350), () {
        if (mounted) {
          _fetchPage();
        }
      });
    } else {
      _debounceTimer?.cancel();
      _fetchPage();
    }
  }

  Future<void> _fetchPage() async {
    final revision = ++_pageRequestRevision;
    setState(() {
      _isLoading = true;
      _isLoadingCount = true;
      _error = '';
      _selectedRowIndices.clear();
    });

    try {
      final offset = _currentPage * _pageSize;
      final tablePageSql = buildTablePageSql(
        tableName: widget.tableName,
        filters: _filters,
        sortColumn: _sortColumn,
        sortAscending: _sortAscending,
        limit: _pageSize,
        offset: offset,
      );
      final page = await runMysqlTablePage(
        url: widget.connectionUrl,
        database: widget.databaseName,
        dataQuery: tablePageSql.dataQuery,
        countQuery: tablePageSql.countQuery,
      );
      if (mounted && revision == _pageRequestRevision) {
        setState(() {
          _result = page.result;
          _totalRows = page.totalRows.toInt();
          _isLoading = false;
          _isLoadingCount = false;
        });
      }
    } catch (e) {
      if (mounted && revision == _pageRequestRevision) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
          _isLoadingCount = false;
        });
      }
    }
  }

  Future<void> _addNewRow() async {
    if (_result == null || _result!.columns.isEmpty) return;

    final Map<String, String> newValues = {};
    for (var col in _result!.columns) {
      newValues[col] = '';
    }

    final bool? shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: const Color(0xFFFAF8F5), // Washi Cream Sheet
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: const BorderSide(color: Color(0xFFE8E5DF), width: 0.5),
              ),
              child: Container(
                width: 400,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "ADD NEW ROW",
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2D2D2D), // Sumi Ink
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: _result!.columns.map((col) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: TextField(
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF2D2D2D),
                                ),
                                decoration: InputDecoration(
                                  labelText: col.toUpperCase(),
                                  labelStyle: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF73726F),
                                    letterSpacing: 0.5,
                                  ),
                                  fillColor: Colors.white,
                                  filled: true,
                                  enabledBorder: const OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Color(0xFFE8E5DF),
                                      width: 0.5,
                                    ),
                                  ),
                                  focusedBorder: const OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Color(0xFF7F0019),
                                      width: 1.0,
                                    ),
                                  ),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                ),
                                onChanged: (val) => newValues[col] = val,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF73726F),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
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
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(
                              0xFF7F0019,
                            ), // Muji Red
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                          ),
                          child: const Text(
                            "SAVE",
                            style: TextStyle(
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
            );
          },
        );
      },
    );

    if (shouldSave == true) {
      final cols = newValues.entries
          .where((e) => e.value.isNotEmpty)
          .map((e) => '`${e.key}`')
          .join(', ');
      final vals = newValues.entries
          .where((e) => e.value.isNotEmpty)
          .map((e) => "'${e.value.replaceAll("'", "''")}'")
          .join(', ');

      String query;
      if (cols.isEmpty) {
        query = 'INSERT INTO `${widget.tableName}` () VALUES ()';
      } else {
        query = 'INSERT INTO `${widget.tableName}` ($cols) VALUES ($vals)';
      }

      try {
        await runMysqlQuery(
          url: widget.connectionUrl,
          database: widget.databaseName,
          query: query,
        );
        _fetchPage();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error: $e"),
              backgroundColor: const Color(0xFFAC6B62),
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteSelectedRows() async {
    if (_selectedRowIndices.isEmpty || _result == null) return;

    final bool? confirm = await WorkspaceDialogs.showConfirm(
      context: context,
      title: "Delete Rows",
      message:
          "Are you sure you want to delete ${_selectedRowIndices.length} row(s)? This action cannot be undone.",
      confirmText: "DELETE",
    );

    if (confirm != true) return;

    final firstCol = _result!.columns.first;
    final List<String> pkValues = [];
    for (int idx in _selectedRowIndices) {
      pkValues.add(_result!.rows[idx][0]);
    }

    final inClause = pkValues
        .map((v) => "'${v.replaceAll("'", "''")}'")
        .join(', ');
    final query =
        "DELETE FROM `${widget.tableName}` WHERE `$firstCol` IN ($inClause)";

    try {
      await runMysqlQuery(
        url: widget.connectionUrl,
        database: widget.databaseName,
        query: query,
      );
      setState(() {
        _selectedRowIndices.clear();
      });
      _fetchPage();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: const Color(0xFFAC6B62),
          ),
        );
      }
    }
  }

  void _nextPage() {
    if ((_currentPage + 1) * _pageSize < _totalRows) {
      setState(() => _currentPage++);
      _fetchPage();
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      setState(() => _currentPage--);
      _fetchPage();
    }
  }

  void _copyResultsToClipboard() {
    if (_result == null) return;
    WashiLedgerDialog.show(
      context: context,
      columns: _result!.columns,
      rows: _result!.rows,
      title: widget.tableName,
    );
  }

  String _buildFilterExportSql() {
    return buildFilteredSelectSql(
      databaseName: widget.databaseName,
      tableName: widget.tableName,
      filters: _filters,
      sortColumn: _sortColumn,
      sortAscending: _sortAscending,
    );
  }

  Future<void> _showFilterSqlExportPreview() async {
    if (!_hasActiveFilters) return;

    final sql = _buildFilterExportSql();
    await showDialog<void>(
      context: context,
      builder: (context) => FilterSqlExportPreviewDialog(
        sql: sql,
        onExport: () => _saveFilterSql(sql),
      ),
    );
  }

  Future<String?> _saveFilterSql(String sql) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Export filter SQL',
      fileName: buildSqlExportFileName(
        databaseName: widget.databaseName,
        tableName: widget.tableName,
      ),
      type: FileType.custom,
      allowedExtensions: const ['sql'],
    );

    if (path == null) return null;

    final exportPath = path.toLowerCase().endsWith('.sql') ? path : '$path.sql';
    await File(exportPath).writeAsString(sql);
    return exportPath;
  }

  Future<void> _showSchemaInspector() async {
    showDialog(
      context: context,
      builder: (context) => _SchemaInspectorDialog(
        connectionUrl: widget.connectionUrl,
        databaseName: widget.databaseName,
        tableName: widget.tableName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _result == null) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF7F0019),
          strokeWidth: 2,
        ),
      );
    }

    if (_error.isNotEmpty && _result == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFAC6B62), size: 32),
            const SizedBox(height: 12),
            Text(_error, style: const TextStyle(color: Color(0xFFAC6B62))),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                _fetchPage();
              },
              child: const Text("RETRY"),
            ),
          ],
        ),
      );
    }

    final data = _result!;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyR, meta: true): () {
          _fetchPage();
        },
        const SingleActivator(LogicalKeyboardKey.keyR, control: true): () {
          _fetchPage();
        },
      },
      child: Focus(
        autofocus: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TableToolbar(
              databaseName: widget.databaseName,
              tableName: widget.tableName,
              selectedCount: _selectedRowIndices.length,
              activeFilterCount: _activeFilters.length,
              onDeleteSelected: _deleteSelectedRows,
              onToggleFilterBar: () {
                setState(() {
                  _showFilterBar = !_showFilterBar;
                });
              },
              onExportFilterSql: _showFilterSqlExportPreview,
              onAddRow: _addNewRow,
              onShowSchemaInspector: _showSchemaInspector,
              onCopyResults: _copyResultsToClipboard,
              onRefresh: _fetchPage,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: _showFilterBar
                  ? _TableFilterBar(
                      columns: data.columns,
                      filters: _filters,
                      onClear: () {
                        setState(() => _filters.clear());
                        _onFiltersUpdated(debounce: false);
                      },
                      onRemove: (index) {
                        setState(() => _filters.removeAt(index));
                        _onFiltersUpdated(debounce: false);
                      },
                      onColumnChanged: (filter, value) {
                        setState(() => filter.columnName = value);
                        _onFiltersUpdated(debounce: false);
                      },
                      onOperatorChanged: (filter, value) {
                        setState(() => filter.operator = value);
                        _onFiltersUpdated(debounce: false);
                      },
                      onValueChanged: (filter, value) {
                        filter.value = value;
                        _onFiltersUpdated(debounce: true);
                      },
                      onAdd: () {
                        if (data.columns.isEmpty) return;
                        setState(() {
                          _filters.add(
                            TableFilter(
                              columnName: data.columns.first,
                              operator: 'contains',
                              value: '',
                            ),
                          );
                        });
                      },
                    )
                  : const SizedBox.shrink(),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF7F0019),
                        strokeWidth: 2,
                      ),
                    )
                  : buildDataGrid(
                      context,
                      data,
                      selectedIndices: _selectedRowIndices,
                      sortColumnIndex: _sortColumnIndexFor(data.columns),
                      sortAscending: _sortAscending,
                      onSortColumn: _onSortColumn,
                      onSelectAll: (selected) {
                        setState(() {
                          if (selected == true) {
                            _selectedRowIndices.addAll(
                              Iterable.generate(data.rows.length),
                            );
                          } else {
                            _selectedRowIndices.clear();
                          }
                        });
                      },
                      onSelectChanged: (index, selected) {
                        setState(() {
                          if (selected) {
                            _selectedRowIndices.add(index);
                          } else {
                            _selectedRowIndices.remove(index);
                          }
                        });
                      },
                      onSave: (column, oldValue, newValue, rowMap) async {
                        if (oldValue == newValue) return;

                        final firstCol = rowMap.keys.first;
                        final firstColVal = rowMap[firstCol]!;
                        final escapedNewValue = newValue.replaceAll("'", "''");
                        final escapedFirstColVal = firstColVal.replaceAll(
                          "'",
                          "''",
                        );

                        final query =
                            "UPDATE `${widget.tableName}` SET `$column` = '$escapedNewValue' WHERE `$firstCol` = '$escapedFirstColVal'";

                        await runMysqlQuery(
                          url: widget.connectionUrl,
                          database: widget.databaseName,
                          query: query,
                        );

                        _fetchPage();
                      },
                    ),
            ),
            _TablePaginationControls(
              currentPage: _currentPage,
              pageSize: _pageSize,
              totalRows: _totalRows,
              isLoading: _isLoading,
              isLoadingCount: _isLoadingCount,
              onPreviousPage: _prevPage,
              onNextPage: _nextPage,
            ),
          ],
        ),
      ),
    );
  }
}

class _TableToolbar extends StatelessWidget {
  final String databaseName;
  final String tableName;
  final int selectedCount;
  final int activeFilterCount;
  final VoidCallback onDeleteSelected;
  final VoidCallback onToggleFilterBar;
  final VoidCallback onExportFilterSql;
  final VoidCallback onAddRow;
  final VoidCallback onShowSchemaInspector;
  final VoidCallback onCopyResults;
  final VoidCallback onRefresh;

  const _TableToolbar({
    required this.databaseName,
    required this.tableName,
    required this.selectedCount,
    required this.activeFilterCount,
    required this.onDeleteSelected,
    required this.onToggleFilterBar,
    required this.onExportFilterSql,
    required this.onAddRow,
    required this.onShowSchemaInspector,
    required this.onCopyResults,
    required this.onRefresh,
  });

  bool get _hasActiveFilters => activeFilterCount > 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFFAF8F5),
        border: Border(
          bottom: BorderSide(color: Color(0xFFE8E5DF), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Text(
            "DATABASE: ${databaseName.toUpperCase()} > TABLE: ${tableName.toUpperCase()}",
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF73726F),
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          if (selectedCount > 0) ...[
            Text(
              "$selectedCount SELECTED",
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFFAC6B62),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                size: 16,
                color: Color(0xFFAC6B62),
              ),
              onPressed: onDeleteSelected,
              tooltip: "Delete Selected",
            ),
            const SizedBox(width: 8),
            Container(width: 1, height: 16, color: const Color(0xFFE8E5DF)),
            const SizedBox(width: 8),
          ],
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onToggleFilterBar,
              mouseCursor: SystemMouseCursors.click,
              borderRadius: BorderRadius.circular(4),
              hoverColor: const Color(0xFFE8E5DF).withValues(alpha: 0.5),
              splashColor: const Color(0xFFE8E5DF).withValues(alpha: 0.3),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.filter_alt_outlined,
                          size: 14,
                          color: _hasActiveFilters
                              ? const Color(0xFF7F0019)
                              : const Color(0xFF73726F),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          "FILTER",
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF73726F),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_hasActiveFilters)
                    Positioned(
                      top: 0,
                      right: -2,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: const BoxDecoration(
                          color: Color(0xFF7F0019),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$activeFilterCount',
                            style: const TextStyle(
                              fontSize: 8,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              Icons.file_download_outlined,
              size: 16,
              color: _hasActiveFilters
                  ? const Color(0xFF73726F)
                  : const Color(0xFFC4C2BC),
            ),
            onPressed: _hasActiveFilters ? onExportFilterSql : null,
            tooltip: "Export Filter SQL",
          ),
          const SizedBox(width: 8),
          Container(width: 1, height: 16, color: const Color(0xFFE8E5DF)),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.add, size: 16, color: Color(0xFF73726F)),
            onPressed: onAddRow,
            tooltip: "Add Row",
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(
              Icons.info_outline,
              size: 16,
              color: Color(0xFF73726F),
            ),
            onPressed: onShowSchemaInspector,
            tooltip: "Table Schema Inspector",
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(
              Icons.copy_all,
              size: 16,
              color: Color(0xFF73726F),
            ),
            onPressed: onCopyResults,
            tooltip: "Copy Table to Clipboard (CSV)",
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh, size: 16, color: Color(0xFF73726F)),
            onPressed: onRefresh,
            tooltip: "Refresh (Cmd+R / Ctrl+R)",
          ),
        ],
      ),
    );
  }
}

class _TablePaginationControls extends StatelessWidget {
  final int currentPage;
  final int pageSize;
  final int totalRows;
  final bool isLoading;
  final bool isLoadingCount;
  final VoidCallback onPreviousPage;
  final VoidCallback onNextPage;

  const _TablePaginationControls({
    required this.currentPage,
    required this.pageSize,
    required this.totalRows,
    required this.isLoading,
    required this.isLoadingCount,
    required this.onPreviousPage,
    required this.onNextPage,
  });

  @override
  Widget build(BuildContext context) {
    final totalPages = (totalRows / pageSize).ceil();
    final currentPageDisplay = currentPage + 1;
    final canGoPrevious = currentPage > 0 && !isLoading;
    final canGoNext = (currentPage + 1) * pageSize < totalRows && !isLoading;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFFAF8F5),
        border: Border(top: BorderSide(color: Color(0xFFE8E5DF), width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            isLoadingCount ? "Loading count..." : "Total: $totalRows rows",
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF73726F),
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            "Page $currentPageDisplay of ${totalPages > 0 ? totalPages : 1}",
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF2D2D2D),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 20),
            onPressed: canGoPrevious ? onPreviousPage : null,
            color: const Color(0xFF2D2D2D),
            disabledColor: const Color(0xFFC4C2BC),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 20),
            onPressed: canGoNext ? onNextPage : null,
            color: const Color(0xFF2D2D2D),
            disabledColor: const Color(0xFFC4C2BC),
          ),
        ],
      ),
    );
  }
}

class _TableFilterBar extends StatelessWidget {
  final List<String> columns;
  final List<TableFilter> filters;
  final VoidCallback onClear;
  final ValueChanged<int> onRemove;
  final void Function(TableFilter filter, String value) onColumnChanged;
  final void Function(TableFilter filter, String value) onOperatorChanged;
  final void Function(TableFilter filter, String value) onValueChanged;
  final VoidCallback onAdd;

  const _TableFilterBar({
    required this.columns,
    required this.filters,
    required this.onClear,
    required this.onRemove,
    required this.onColumnChanged,
    required this.onOperatorChanged,
    required this.onValueChanged,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(
        color: Color(0xFFF3EFE9),
        border: Border(
          bottom: BorderSide(color: Color(0xFFE8E5DF), width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                "FILTER RULES",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF73726F),
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              if (filters.isNotEmpty)
                OutlinedButton(
                  onPressed: onClear,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFAC6B62),
                    side: const BorderSide(
                      color: Color(0xFFAC6B62),
                      width: 0.5,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  child: const Text(
                    "CLEAR ALL",
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          if (filters.isNotEmpty) ...[
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filters.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final filter = filters[index];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 56,
                      child: Text(
                        index == 0 ? "WHERE" : "AND",
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF73726F),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    _buildColumnDropdown(filter),
                    const SizedBox(width: 10),
                    _buildOperatorDropdown(filter),
                    const SizedBox(width: 10),
                    if (filter.operator != 'is_null' &&
                        filter.operator != 'is_not_null')
                      Expanded(
                        child: _FilterValueInput(
                          key: ValueKey(filter),
                          filter: filter,
                          onChanged: (value) => onValueChanged(filter, value),
                        ),
                      )
                    else
                      const Spacer(),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        size: 14,
                        color: Color(0xFF73726F),
                      ),
                      hoverColor: const Color(0xFFFAF8F5),
                      onPressed: () => onRemove(index),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      splashRadius: 16,
                      tooltip: "Remove rule",
                    ),
                  ],
                );
              },
            ),
          ],
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () {
              if (columns.isNotEmpty) {
                onAdd();
              }
            },
            icon: const Icon(Icons.add, size: 11, color: Color(0xFF2D2D2D)),
            label: const Text(
              "ADD FILTER",
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2D2D2D),
                letterSpacing: 0.5,
              ),
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFFE8E5DF), width: 0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(2),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumnDropdown(TableFilter filter) {
    final currentValue = columns.contains(filter.columnName)
        ? filter.columnName
        : columns.first;

    return _FilterPopupField(
      width: 130,
      value: currentValue,
      tooltip: "Select column",
      fontFamily: 'monospace',
      options: [
        for (final column in columns) _FilterPopupOption(column, column),
      ],
      onSelected: (value) => onColumnChanged(filter, value),
    );
  }

  Widget _buildOperatorDropdown(TableFilter filter) {
    final currentOperator = TableFilter.operators.firstWhere(
      (operator) => operator['value'] == filter.operator,
      orElse: () => TableFilter.operators.first,
    );

    return _FilterPopupField(
      width: 110,
      value: currentOperator['label']!,
      tooltip: "Select condition",
      options: [
        for (final operator in TableFilter.operators)
          _FilterPopupOption(operator['value']!, operator['label']!),
      ],
      onSelected: (value) => onOperatorChanged(filter, value),
    );
  }
}

class _FilterPopupOption {
  final String value;
  final String label;

  const _FilterPopupOption(this.value, this.label);
}

class _FilterPopupField extends StatelessWidget {
  final double width;
  final String value;
  final String tooltip;
  final String? fontFamily;
  final List<_FilterPopupOption> options;
  final ValueChanged<String> onSelected;

  const _FilterPopupField({
    required this.width,
    required this.value,
    required this.tooltip,
    this.fontFamily,
    required this.options,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final fieldStyle = TextStyle(
      fontSize: 11,
      color: const Color(0xFF2D2D2D),
      fontFamily: fontFamily,
    );

    return SizedBox(
      width: width,
      height: 32,
      child: PopupMenuButton<String>(
        onSelected: onSelected,
        tooltip: tooltip,
        offset: const Offset(0, 30),
        color: const Color(0xFFFAF8F5),
        itemBuilder: (context) => options
            .map(
              (option) => PopupMenuItem(
                value: option.value,
                height: 32,
                child: Text(option.label, style: fieldStyle),
              ),
            )
            .toList(),
        child: AbsorbPointer(
          child: TextField(
            readOnly: true,
            style: fieldStyle,
            decoration: InputDecoration(
              hintText: value,
              hintStyle: fieldStyle,
              fillColor: Colors.white,
              filled: true,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              suffixIcon: const Icon(
                Icons.arrow_drop_down,
                size: 14,
                color: Color(0xFF73726F),
              ),
              suffixIconConstraints: const BoxConstraints(
                minWidth: 24,
                minHeight: 24,
              ),
              enabledBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFE8E5DF), width: 0.5),
                borderRadius: BorderRadius.all(Radius.circular(2)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SchemaInspectorDialog extends StatefulWidget {
  final String connectionUrl;
  final String databaseName;
  final String tableName;

  const _SchemaInspectorDialog({
    required this.connectionUrl,
    required this.databaseName,
    required this.tableName,
  });

  @override
  State<_SchemaInspectorDialog> createState() => _SchemaInspectorDialogState();
}

class _SchemaInspectorDialogState extends State<_SchemaInspectorDialog> {
  late final Future<QueryResult> _columnsFuture;
  late final Future<QueryResult> _indexesFuture;

  @override
  void initState() {
    super.initState();
    _columnsFuture = runMysqlQuery(
      url: widget.connectionUrl,
      database: widget.databaseName,
      query: 'DESCRIBE `${widget.tableName}`',
    );
    _indexesFuture = runMysqlQuery(
      url: widget.connectionUrl,
      database: widget.databaseName,
      query: 'SHOW INDEX FROM `${widget.tableName}`',
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Dialog(
        backgroundColor: const Color(0xFFFAF8F5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: Color(0xFFE8E5DF), width: 0.5),
        ),
        child: Container(
          width: 700,
          height: 480,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 20,
                    color: Color(0xFF73726F),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "TABLE INFO: ${widget.tableName.toUpperCase()}",
                    style: const TextStyle(
                      fontSize: 14,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2D2D2D),
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const TabBar(
                labelColor: Color(0xFF7F0019),
                unselectedLabelColor: Color(0xFF73726F),
                indicatorColor: Color(0xFF7F0019),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Color(0xFFE8E5DF),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
                tabs: [
                  Tab(text: "COLUMNS"),
                  Tab(text: "INDEXES"),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TabBarView(
                  children: [
                    _SchemaQueryView(
                      future: _columnsFuture,
                      errorPrefix: 'Error fetching columns',
                      emptyMessage: 'No column metadata found.',
                    ),
                    _SchemaQueryView(
                      future: _indexesFuture,
                      errorPrefix: 'Error fetching indexes',
                      emptyMessage: 'No indexes found on this table.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF73726F),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                    child: const Text(
                      "CLOSE",
                      style: TextStyle(
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

class _SchemaQueryView extends StatelessWidget {
  final Future<QueryResult> future;
  final String errorPrefix;
  final String emptyMessage;

  const _SchemaQueryView({
    required this.future,
    required this.errorPrefix,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QueryResult>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF7F0019),
              strokeWidth: 2,
            ),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                "$errorPrefix: ${snapshot.error}",
                style: const TextStyle(color: Color(0xFFAC6B62), fontSize: 13),
              ),
            ),
          );
        }

        final schema = snapshot.data!;
        if (schema.rows.isEmpty) {
          return Center(
            child: Text(
              emptyMessage,
              style: const TextStyle(color: Color(0xFF73726F), fontSize: 13),
            ),
          );
        }
        return buildDataGrid(context, schema);
      },
    );
  }
}

class _FilterValueInput extends StatefulWidget {
  final TableFilter filter;
  final ValueChanged<String> onChanged;

  const _FilterValueInput({
    super.key,
    required this.filter,
    required this.onChanged,
  });

  @override
  State<_FilterValueInput> createState() => _FilterValueInputState();
}

class _FilterValueInputState extends State<_FilterValueInput> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.filter.value);
  }

  @override
  void didUpdateWidget(covariant _FilterValueInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filter != widget.filter) {
      _controller.text = widget.filter.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32, // Matches the new dropdown replacement blueprints exactly
      child: TextField(
        controller: _controller,
        style: const TextStyle(
          fontSize: 11,
          color: Color(0xFF2D2D2D),
          fontFamily: 'monospace',
        ),
        decoration: const InputDecoration(
          hintText: "Enter value...",
          hintStyle: TextStyle(fontSize: 11, color: Color(0xFFC4C2BC)),
          fillColor: Colors.white,
          filled: true,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ), // Perfect text baseline symmetry
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFFE8E5DF), width: 0.5),
            borderRadius: BorderRadius.all(Radius.circular(2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF73726F), width: 0.7),
            borderRadius: BorderRadius.all(Radius.circular(2)),
          ),
        ),
        onChanged: widget.onChanged,
      ),
    );
  }
}
