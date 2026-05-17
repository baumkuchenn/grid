import 'package:flutter/material.dart';
import '../models/database_connection.dart';
import 'package:grid/src/rust/api/simple.dart';

class DatabaseExplorerPage extends StatefulWidget {
  final DatabaseConnection connection;
  final String databaseName;

  const DatabaseExplorerPage({
    super.key,
    required this.connection,
    required this.databaseName,
  });

  @override
  State<DatabaseExplorerPage> createState() => _DatabaseExplorerPageState();
}

class _DatabaseExplorerPageState extends State<DatabaseExplorerPage> {
  final TextEditingController _queryController = TextEditingController();
  
  List<String> _tables = [];
  String? _selectedTable;
  
  bool _isLoadingTables = true;
  bool _isRunningQuery = false;
  
  QueryResult? _queryResult;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchTables();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _fetchTables() async {
    setState(() {
      _isLoadingTables = true;
      _errorMessage = '';
    });
    try {
      final tables = await getMysqlTables(
        url: widget.connection.url, 
        database: widget.databaseName,
      );
      if (mounted) {
        setState(() {
          _tables = tables;
          _isLoadingTables = false;
          if (_tables.isNotEmpty) {
            _loadTable(_tables.first);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoadingTables = false;
        });
      }
    }
  }

  void _loadTable(String table) {
    setState(() {
      _selectedTable = table;
      _queryController.text = "SELECT * FROM `$table` LIMIT 100;";
    });
    _runQuery();
  }

  Future<void> _runQuery() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isRunningQuery = true;
      _errorMessage = '';
      _queryResult = null;
    });
    
    try {
      final res = await runMysqlQuery(
        url: widget.connection.url,
        database: widget.databaseName,
        query: query,
      );
      if (mounted) {
        setState(() {
          _queryResult = res;
          _isRunningQuery = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isRunningQuery = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.databaseName} — ${widget.connection.name}"),
      ),
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 250,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: Color(0xFFEAEAEA))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    "TABLES",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF888888),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  child: _isLoadingTables
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF7F0019)))
                      : ListView.builder(
                          itemCount: _tables.length,
                          itemBuilder: (context, index) {
                            final table = _tables[index];
                            final isSelected = table == _selectedTable;
                            return InkWell(
                              onTap: () => _loadTable(table),
                              child: Container(
                                color: isSelected ? const Color(0xFFF5F5F5) : Colors.transparent,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.table_chart_outlined, 
                                      size: 18, 
                                      color: isSelected ? const Color(0xFF7F0019) : const Color(0xFF888888)
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        table,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                          color: isSelected ? const Color(0xFF333333) : const Color(0xFF555555),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          
          // Main Content
          Expanded(
            child: Column(
              children: [
                // Query Editor
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      TextField(
                        controller: _queryController,
                        maxLines: 4,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          color: Color(0xFF333333),
                        ),
                        decoration: InputDecoration(
                          hintText: "Enter SQL Query here...",
                          filled: true,
                          fillColor: const Color(0xFFFAFAFA),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: const BorderSide(color: Color(0xFFEAEAEA)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: const BorderSide(color: Color(0xFFEAEAEA)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: const BorderSide(color: Color(0xFFEAEAEA)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _isRunningQuery ? null : _runQuery,
                        icon: _isRunningQuery 
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.play_arrow, size: 18),
                        label: Text(_isRunningQuery ? "RUNNING..." : "RUN QUERY"),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Divider(height: 1, color: Color(0xFFEAEAEA)),
                
                // Results Area
                Expanded(
                  child: Container(
                    width: double.infinity,
                    color: const Color(0xFFF9F9F9),
                    child: _isRunningQuery
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFF7F0019)))
                        : _errorMessage.isNotEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(20),
                                child: Text(_errorMessage, style: const TextStyle(color: Color(0xFFD32F2F))),
                              )
                            : _queryResult != null
                                ? _buildDataGrid(_queryResult!)
                                : const Center(child: Text("Run a query to see results.", style: TextStyle(color: Color(0xFF999999)))),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataGrid(QueryResult result) {
    if (result.columns.isEmpty) {
      return const Center(child: Text("0 rows returned.", style: TextStyle(color: Color(0xFF999999))));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Card(
            child: DataTable(
              headingRowColor: WidgetStateProperty.resolveWith((states) => const Color(0xFFF5F5F5)),
              dataRowColor: WidgetStateProperty.resolveWith((states) => Colors.white),
              columns: result.columns.map((col) => DataColumn(
                label: Text(
                  col.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Color(0xFF555555),
                  ),
                )
              )).toList(),
              rows: result.rows.map((row) => DataRow(
                cells: row.map((cell) => DataCell(
                  Text(
                    cell,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF333333)),
                  )
                )).toList(),
              )).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
