import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../../rust/api/simple.dart';
import '../models/table_filter.dart';
import 'data_grid_view.dart';
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

  final Set<int> _selectedRowIndices = {};
  
  // Filter state variables
  final List<TableFilter> _filters = [];
  bool _showFilterBar = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _fetchCount();
    _fetchData();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  String _buildWhereClause() {
    final activeFilters = _filters.where((f) {
      if (f.operator == 'is_null' || f.operator == 'is_not_null') return true;
      return f.value.isNotEmpty;
    }).toList();

    if (activeFilters.isEmpty) return '';
    final conditions = activeFilters.map((f) => f.toSql()).toList();
    return ' WHERE ${conditions.join(' AND ')}';
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
          _fetchCount();
          _fetchData();
        }
      });
    } else {
      _debounceTimer?.cancel();
      _fetchCount();
      _fetchData();
    }
  }

  Future<void> _fetchCount() async {
    try {
      final whereClause = _buildWhereClause();
      final res = await runMysqlQuery(
        url: widget.connectionUrl,
        database: widget.databaseName,
        query: 'SELECT COUNT(*) FROM `${widget.tableName}`$whereClause',
      );
      if (mounted && res.rows.isNotEmpty && res.rows[0].isNotEmpty) {
        setState(() {
          _totalRows = int.tryParse(res.rows[0][0]) ?? 0;
          _isLoadingCount = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingCount = false;
        });
      }
    }
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = '';
      _selectedRowIndices.clear();
    });

    try {
      final offset = _currentPage * _pageSize;
      final whereClause = _buildWhereClause();
      final result = await runMysqlQuery(
        url: widget.connectionUrl,
        database: widget.databaseName,
        query: 'SELECT * FROM `${widget.tableName}`$whereClause LIMIT $_pageSize OFFSET $offset',
      );
      if (mounted) {
        setState(() {
          _result = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
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
                                style: const TextStyle(fontSize: 13, color: Color(0xFF2D2D2D)),
                                decoration: InputDecoration(
                                  labelText: col.toUpperCase(),
                                  labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF73726F), letterSpacing: 0.5),
                                  fillColor: Colors.white,
                                  filled: true,
                                  enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFE8E5DF), width: 0.5)),
                                  focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF7F0019), width: 1.0)),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          child: const Text(
                            "CANCEL", 
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true), 
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7F0019), // Muji Red
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          ),
                          child: const Text(
                            "SAVE",
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }
        );
      }
    );

    if (shouldSave == true) {
      final cols = newValues.entries.where((e) => e.value.isNotEmpty).map((e) => '`${e.key}`').join(', ');
      final vals = newValues.entries.where((e) => e.value.isNotEmpty).map((e) => "'${e.value.replaceAll("'", "''")}'").join(', ');
      
      String query;
      if (cols.isEmpty) {
        query = 'INSERT INTO `${widget.tableName}` () VALUES ()';
      } else {
        query = 'INSERT INTO `${widget.tableName}` ($cols) VALUES ($vals)';
      }
      
      try {
        await runMysqlQuery(url: widget.connectionUrl, database: widget.databaseName, query: query);
        _fetchCount();
        _fetchData();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: const Color(0xFFAC6B62)));
      }
    }
  }

  Future<void> _deleteSelectedRows() async {
    if (_selectedRowIndices.isEmpty || _result == null) return;
    
    final bool? confirm = await WorkspaceDialogs.showConfirm(
      context: context,
      title: "Delete Rows",
      message: "Are you sure you want to delete ${_selectedRowIndices.length} row(s)? This action cannot be undone.",
      confirmText: "DELETE",
    );

    if (confirm != true) return;

    final firstCol = _result!.columns.first;
    final List<String> pkValues = [];
    for (int idx in _selectedRowIndices) {
      pkValues.add(_result!.rows[idx][0]);
    }
    
    final inClause = pkValues.map((v) => "'${v.replaceAll("'", "''")}'").join(', ');
    final query = "DELETE FROM `${widget.tableName}` WHERE `$firstCol` IN ($inClause)";

    try {
      await runMysqlQuery(url: widget.connectionUrl, database: widget.databaseName, query: query);
      setState(() {
        _selectedRowIndices.clear();
      });
      _fetchCount();
      _fetchData();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: const Color(0xFFAC6B62)));
    }
  }

  void _nextPage() {
    if ((_currentPage + 1) * _pageSize < _totalRows) {
      setState(() => _currentPage++);
      _fetchData();
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      setState(() => _currentPage--);
      _fetchData();
    }
  }

  Widget _buildPaginationControls() {
    final totalPages = (_totalRows / _pageSize).ceil();
    final currentPageDisplay = _currentPage + 1;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFFAF8F5), // Washi Cream Sheet
        border: Border(top: BorderSide(color: Color(0xFFE8E5DF), width: 0.5)), // Divider Clay
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            _isLoadingCount ? "Loading count..." : "Total: $_totalRows rows", 
            style: const TextStyle(fontSize: 12, color: Color(0xFF73726F), fontWeight: FontWeight.w500)
          ),
          const Spacer(),
          Text(
            "Page $currentPageDisplay of ${totalPages > 0 ? totalPages : 1}",
            style: const TextStyle(fontSize: 12, color: Color(0xFF2D2D2D), fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 20),
            onPressed: _currentPage > 0 && !_isLoading ? _prevPage : null,
            color: const Color(0xFF2D2D2D),
            disabledColor: const Color(0xFFC4C2BC),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 20),
            onPressed: ((_currentPage + 1) * _pageSize < _totalRows) && !_isLoading ? _nextPage : null,
            color: const Color(0xFF2D2D2D),
            disabledColor: const Color(0xFFC4C2BC),
          ),
        ],
      ),
    );
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

  Widget _buildColumnsSchemaView(String url, String db, String table) {
    return FutureBuilder<QueryResult>(
      future: runMysqlQuery(
        url: url,
        database: db,
        query: 'DESCRIBE `$table`',
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF7F0019), strokeWidth: 2));
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text("Error fetching columns: ${snapshot.error}", style: const TextStyle(color: Color(0xFFAC6B62), fontSize: 13)),
            ),
          );
        }
        final schema = snapshot.data!;
        if (schema.rows.isEmpty) {
          return const Center(child: Text("No column metadata found.", style: TextStyle(color: Color(0xFF73726F), fontSize: 13)));
        }
        return _buildSchemaTable(schema);
      },
    );
  }

  Widget _buildIndexesSchemaView(String url, String db, String table) {
    return FutureBuilder<QueryResult>(
      future: runMysqlQuery(
        url: url,
        database: db,
        query: 'SHOW INDEX FROM `$table`',
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF7F0019), strokeWidth: 2));
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text("Error fetching indexes: ${snapshot.error}", style: const TextStyle(color: Color(0xFFAC6B62), fontSize: 13)),
            ),
          );
        }
        final schema = snapshot.data!;
        if (schema.rows.isEmpty) {
          return const Center(child: Text("No indexes found on this table.", style: TextStyle(color: Color(0xFF73726F), fontSize: 13)));
        }
        return _buildSchemaTable(schema);
      },
    );
  }

  Widget _buildSchemaTable(QueryResult schema) {
    return Theme(
      data: Theme.of(context).copyWith(
        cardColor: Colors.white,
        dividerColor: const Color(0xFFE8E5DF),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            horizontalMargin: 12,
            columnSpacing: 24,
            dataRowMinHeight: 28,
            dataRowMaxHeight: 32,
            headingRowHeight: 34,
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF3EFE9)), // Kraft Sand headers
            border: const TableBorder(
              horizontalInside: BorderSide(color: Color(0xFFE8E5DF), width: 0.5), // Divider Clay
              bottom: BorderSide(color: Color(0xFFE8E5DF), width: 0.5),
            ),
            columns: schema.columns.map((c) => DataColumn(
              label: Text(
                c.toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 10, color: Color(0xFF73726F), letterSpacing: 0.8, fontFamily: 'monospace'),
              ),
            )).toList(),
            rows: schema.rows.map((row) {
              return DataRow(
                cells: row.map((cell) => DataCell(
                  Text(cell, style: const TextStyle(fontSize: 12, color: Color(0xFF2D2D2D))),
                )).toList(),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Future<void> _showSchemaInspector() async {
    showDialog(
      context: context,
      builder: (context) {
        return DefaultTabController(
          length: 2,
          child: Dialog(
            backgroundColor: const Color(0xFFFAF8F5), // Washi Cream Sheet
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
                      const Icon(Icons.info_outline, size: 20, color: Color(0xFF73726F)),
                      const SizedBox(width: 8),
                      Text(
                        "TABLE INFO: ${widget.tableName.toUpperCase()}",
                        style: const TextStyle(
                          fontSize: 14, 
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700, 
                          color: Color(0xFF2D2D2D), // Sumi Ink
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const TabBar(
                    labelColor: Color(0xFF7F0019), // Muji Red active indicators
                    unselectedLabelColor: Color(0xFF73726F),
                    indicatorColor: Color(0xFF7F0019),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Color(0xFFE8E5DF),
                    labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.0),
                    tabs: [
                      Tab(text: "COLUMNS"),
                      Tab(text: "INDEXES"),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildColumnsSchemaView(widget.connectionUrl, widget.databaseName, widget.tableName),
                        _buildIndexesSchemaView(widget.connectionUrl, widget.databaseName, widget.tableName),
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
                          backgroundColor: const Color(0xFF73726F), // Wood Ash button
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        ),
                        child: const Text("CLOSE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _result == null) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF7F0019), strokeWidth: 2));
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
            ElevatedButton(onPressed: () { _fetchCount(); _fetchData(); }, child: const Text("RETRY"))
          ],
        ),
      );
    }

    final data = _result!;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyR, meta: true): () {
          _fetchCount();
          _fetchData();
        },
        const SingleActivator(LogicalKeyboardKey.keyR, control: true): () {
          _fetchCount();
          _fetchData();
        },
      },
      child: Focus(
        autofocus: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFFFAF8F5), // Washi Cream Sheet
                border: Border(bottom: BorderSide(color: Color(0xFFE8E5DF), width: 0.5)), // Divider Clay
              ),
              child: Row(
                children: [
                  Text(
                    "DATABASE: ${widget.databaseName.toUpperCase()} > TABLE: ${widget.tableName.toUpperCase()}", 
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF73726F), letterSpacing: 0.5),
                  ),
                  const Spacer(),
                  if (_selectedRowIndices.isNotEmpty) ...[
                    Text(
                      "${_selectedRowIndices.length} SELECTED", 
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFAC6B62), letterSpacing: 0.5),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFAC6B62)),
                      onPressed: _deleteSelectedRows,
                      tooltip: "Delete Selected",
                    ),
                    const SizedBox(width: 8),
                    Container(width: 1, height: 16, color: const Color(0xFFE8E5DF)),
                    const SizedBox(width: 8),
                  ],
                  // Filter toggle — stable width using Stack badge, never shifts
                  Material(
                    color: Colors.transparent, // Keeps the underlying top bar Washi color visible
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _showFilterBar = !_showFilterBar;
                        });
                      },
                      mouseCursor: SystemMouseCursors.click, // Ensures desktop cursor transforms to pointer
                      borderRadius: BorderRadius.circular(4),
                      hoverColor: const Color(0xFFE8E5DF).withOpacity(0.5), // Renders on top of the Material canvas
                      splashColor: const Color(0xFFE8E5DF).withOpacity(0.3),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            // Slightly taller padding bounds to align perfectly with the height of adjacent circular icons
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.filter_alt_outlined,
                                  size: 14,
                                  color: _filters.isNotEmpty ? const Color(0xFF7F0019) : const Color(0xFF73726F),
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
                          if (_filters.isNotEmpty)
                            Positioned(
                              top: 0,
                              right: -2,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF7F0019), // Muji Red active indicators
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${_filters.length}',
                                    style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(width: 1, height: 16, color: const Color(0xFFE8E5DF)),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add, size: 16, color: Color(0xFF73726F)),
                    onPressed: _addNewRow,
                    tooltip: "Add Row",
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.info_outline, size: 16, color: Color(0xFF73726F)),
                    onPressed: _showSchemaInspector,
                    tooltip: "Table Schema Inspector",
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.copy_all, size: 16, color: Color(0xFF73726F)),
                    onPressed: _copyResultsToClipboard,
                    tooltip: "Copy Table to Clipboard (CSV)",
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 16, color: Color(0xFF73726F)),
                    onPressed: () {
                      _fetchCount();
                      _fetchData();
                    },
                    tooltip: "Refresh (Cmd+R / Ctrl+R)",
                  ),
                ],
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: _showFilterBar ? _buildFilterBar(data.columns) : const SizedBox.shrink(),
            ),
            Expanded(
              child: _isLoading 
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF7F0019), strokeWidth: 2)) 
                  : buildDataGrid(
                      context, 
                      data,
                      selectedIndices: _selectedRowIndices,
                      onSelectAll: (selected) {
                        setState(() {
                          if (selected == true) {
                            _selectedRowIndices.addAll(Iterable.generate(data.rows.length));
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
                        final escapedFirstColVal = firstColVal.replaceAll("'", "''");
                        
                        final query = "UPDATE `${widget.tableName}` SET `$column` = '$escapedNewValue' WHERE `$firstCol` = '$escapedFirstColVal'";
                        
                        await runMysqlQuery(
                          url: widget.connectionUrl,
                          database: widget.databaseName,
                          query: query,
                        );
                        
                        _fetchData();
                      },
                    ),
            ),
            _buildPaginationControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar(List<String> columns) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20), // Spaced out backdrop boundary
      decoration: const BoxDecoration(
        color: Color(0xFFF3EFE9), // Kraft Sand backdrop
        border: Border(bottom: BorderSide(color: Color(0xFFE8E5DF), width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header Row
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
              if (_filters.isNotEmpty)
                // 1. CLEAR ALL: Added generous tactical padding
                OutlinedButton(
                  onPressed: () {
                    setState(() => _filters.clear());
                    _onFiltersUpdated(debounce: false);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFAC6B62),
                    side: const BorderSide(color: Color(0xFFAC6B62), width: 0.5),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), // Enhanced, spacious padding
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
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
          
          // Filter Rows Section
          if (_filters.isNotEmpty) ...[
            const SizedBox(height: 16), // Unified grid gap
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filters.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10), // Clean layout spacing
              itemBuilder: (context, index) {
                final filter = _filters[index];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center, // Flawless vertical centerline alignment
                  children: [
                    // SQL Keyword Label
                    SizedBox(
                      width: 56, // Slightly wider to feel less cramped
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
                    // Column Selector
                    _buildColumnDropdown(filter, columns),
                    const SizedBox(width: 10),
                    // Operator Selector
                    _buildOperatorDropdown(filter),
                    const SizedBox(width: 10),
                    // Value Input
                    if (filter.operator != 'is_null' && filter.operator != 'is_not_null')
                      Expanded(
                        child: _FilterValueInput(
                          key: ValueKey(filter),
                          filter: filter,
                          onChanged: (val) {
                            filter.value = val;
                            _onFiltersUpdated(debounce: true);
                          },
                        ),
                      )
                    else
                      const Spacer(),
                    const SizedBox(width: 12),
                    // Remove Filter Button
                    IconButton(
                      icon: const Icon(Icons.close, size: 14, color: Color(0xFF73726F)),
                      hoverColor: const Color(0xFFFAF8F5),
                      onPressed: () {
                        setState(() => _filters.removeAt(index));
                        _onFiltersUpdated(debounce: false);
                      },
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
          
          // 2. ADD FILTER: Shifted down slightly with custom padding layout
          const SizedBox(height: 14),
          _buildAddFilterButton(columns),
        ],
      ),
    );
  }

  Widget _buildColumnDropdown(TableFilter filter, List<String> columns) {
    final currentValue = columns.contains(filter.columnName) ? filter.columnName : columns.first;
    
    return SizedBox(
      width: 130, // Absolute, unyielding horizontal control block
      height: 32, // Perfect, crisp desktop ledger line height
      child: PopupMenuButton<String>(
        onSelected: (val) {
          setState(() => filter.columnName = val);
          _onFiltersUpdated(debounce: false);
        },
        tooltip: "Select column",
        offset: const Offset(0, 30),
        color: const Color(0xFFFAF8F5),
        itemBuilder: (context) => columns.map((col) => PopupMenuItem(
          value: col,
          height: 32,
          child: Text(col, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF2D2D2D))),
        )).toList(),
        // We use a completely disabled TextField to replicate the identical container spec
        child: AbsorbPointer(
          child: TextField(
            readOnly: true,
            style: const TextStyle(fontSize: 11, color: Color(0xFF2D2D2D), fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText: currentValue,
              hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF2D2D2D), fontFamily: 'monospace'),
              fillColor: Colors.white,
              filled: true,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              suffixIcon: const Icon(Icons.arrow_drop_down, size: 14, color: Color(0xFF73726F)),
              suffixIconConstraints: const BoxConstraints(minWidth: 24, minHeight: 24),
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

  Widget _buildOperatorDropdown(TableFilter filter) {
    final currentOpMap = TableFilter.operators.firstWhere(
      (op) => op['value'] == filter.operator,
      orElse: () => TableFilter.operators.first,
    );
    final currentLabel = currentOpMap['label']!;

    return SizedBox(
      width: 110, // Perfectly proportional operator frame step
      height: 32, // Exact matching desktop line baseline
      child: PopupMenuButton<String>(
        onSelected: (val) {
          setState(() => filter.operator = val);
          _onFiltersUpdated(debounce: false);
        },
        tooltip: "Select condition",
        offset: const Offset(0, 30),
        color: const Color(0xFFFAF8F5),
        itemBuilder: (context) => TableFilter.operators.map((op) => PopupMenuItem(
          value: op['value'],
          height: 32,
          child: Text(op['label']!, style: const TextStyle(fontSize: 11, color: Color(0xFF2D2D2D))),
        )).toList(),
        child: AbsorbPointer(
          child: TextField(
            readOnly: true,
            style: const TextStyle(fontSize: 11, color: Color(0xFF2D2D2D)),
            decoration: InputDecoration(
              hintText: currentLabel,
              hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF2D2D2D)),
              fillColor: Colors.white,
              filled: true,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              suffixIcon: const Icon(Icons.arrow_drop_down, size: 14, color: Color(0xFF73726F)),
              suffixIconConstraints: const BoxConstraints(minWidth: 24, minHeight: 24),
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

  Widget _buildAddFilterButton(List<String> columns) {
    return OutlinedButton.icon(
      onPressed: () {
        if (columns.isNotEmpty) {
          setState(() {
            _filters.add(TableFilter(
              columnName: columns.first,
              operator: 'contains',
              value: '',
            ));
          });
        }
      },
      icon: const Icon(Icons.add, size: 11, color: Color(0xFF2D2D2D)),
      label: const Text(
        "ADD FILTER",
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF2D2D2D), letterSpacing: 0.5),
      ),
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFFE8E5DF), width: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // Spacious tactile button padding
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
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
        style: const TextStyle(fontSize: 11, color: Color(0xFF2D2D2D), fontFamily: 'monospace'),
        decoration: const InputDecoration(
          hintText: "Enter value...",
          hintStyle: TextStyle(fontSize: 11, color: Color(0xFFC4C2BC)),
          fillColor: Colors.white,
          filled: true,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Perfect text baseline symmetry
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
