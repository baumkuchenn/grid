import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../rust/api/simple.dart';
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

  @override
  void initState() {
    super.initState();
    _fetchCount();
    _fetchData();
  }

  Future<void> _fetchCount() async {
    try {
      final res = await runMysqlQuery(
        url: widget.connectionUrl,
        database: widget.databaseName,
        query: 'SELECT COUNT(*) FROM `${widget.tableName}`',
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
      final result = await runMysqlQuery(
        url: widget.connectionUrl,
        database: widget.databaseName,
        query: 'SELECT * FROM `${widget.tableName}` LIMIT $_pageSize OFFSET $offset',
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
}
