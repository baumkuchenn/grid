import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../connections/models/database_connection.dart';
import '../../../rust/api/simple.dart';

class WorkspaceTab {
  final String id;
  final String title;
  final String databaseName;
  final String? tableName; // null if it's a query tab

  WorkspaceTab({
    required this.id,
    required this.title,
    required this.databaseName,
    this.tableName,
  });
}

class WorkspacePage extends StatefulWidget {
  final DatabaseConnection connection;

  const WorkspacePage({super.key, required this.connection});

  @override
  State<WorkspacePage> createState() => _WorkspacePageState();
}

class _WorkspacePageState extends State<WorkspacePage> {
  bool _isLoadingDatabases = true;
  String _errorMessage = '';
  double _sidebarWidth = 280.0;
  List<String> _databases = [];
  String _databaseSearchQuery = '';
  final Map<String, String> _tableSearchQueries = {};
  final Map<String, TextEditingController> _tableSearchControllers = {};

  // Real tables per database
  final Map<String, List<String>> _databaseTables = {};
  
  // Tabs state
  final List<WorkspaceTab> _tabs = [];
  String? _activeTabId;

  bool _isConnectionAlive = true;
  bool _isCheckingConnection = false;
  Timer? _connectionCheckTimer;

  @override
  void initState() {
    super.initState();
    _fetchDatabases();
    _checkConnection();
    _connectionCheckTimer = Timer.periodic(const Duration(seconds: 15), (_) => _checkConnection());
  }

  @override
  void dispose() {
    _connectionCheckTimer?.cancel();
    for (var controller in _tableSearchControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _checkConnection() async {
    if (_isCheckingConnection) return;
    setState(() => _isCheckingConnection = true);
    try {
      await runMysqlQuery(url: widget.connection.url, database: '', query: 'SELECT 1');
      if (mounted && !_isConnectionAlive) setState(() => _isConnectionAlive = true);
    } catch (e) {
      if (mounted && _isConnectionAlive) setState(() => _isConnectionAlive = false);
    } finally {
      if (mounted) setState(() => _isCheckingConnection = false);
    }
  }

  Future<void> _reconnect() async {
    await _checkConnection();
    if (_isConnectionAlive) {
      _fetchDatabases();
    }
  }

  Future<void> _fetchDatabases() async {
    setState(() {
      _isLoadingDatabases = true;
      _errorMessage = '';
    });

    try {
      final dbs = await getMysqlDatabases(url: widget.connection.url);
      setState(() {
        _databases = dbs;
      });

      // Fetch tables for each database asynchronously
      for (var db in dbs) {
        try {
          final tables = await getMysqlTables(url: widget.connection.url, database: db);
          if (mounted) {
            setState(() {
              _databaseTables[db] = tables;
            });
          }
        } catch (e) {
          debugPrint("Failed to fetch tables for $db: $e");
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingDatabases = false;
        });
      }
    }
  }

  void _openTableTab(String db, String table) {
    final tabId = "table_${db}_$table";
    final existingIndex = _tabs.indexWhere((t) => t.id == tabId);

    setState(() {
      if (existingIndex >= 0) {
        _activeTabId = tabId;
      } else {
        _tabs.add(WorkspaceTab(
          id: tabId,
          title: table,
          databaseName: db,
          tableName: table,
        ));
        _activeTabId = tabId;
      }
    });
  }

  void _openQueryTab() {
    final tabId = "query_${DateTime.now().millisecondsSinceEpoch}";
    setState(() {
      _tabs.add(WorkspaceTab(
        id: tabId,
        title: "New Query",
        databaseName: '',
        tableName: null,
      ));
      _activeTabId = tabId;
    });
  }

  void _closeTab(String tabId) {
    setState(() {
      final index = _tabs.indexWhere((t) => t.id == tabId);
      if (index >= 0) {
        _tabs.removeAt(index);
        if (_activeTabId == tabId) {
          if (_tabs.isNotEmpty) {
            _activeTabId = _tabs[index > 0 ? index - 1 : 0].id;
          } else {
            _activeTabId = null;
          }
        }
      }
    });
  }

  Future<String?> _showFormDialog({required String title, required String label, String initialValue = ""}) async {
    String value = initialValue;
    return showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF333333))),
              const SizedBox(height: 24),
              Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
              const SizedBox(height: 8),
              TextField(
                autofocus: true,
                controller: TextEditingController(text: initialValue)..selection = TextSelection(baseOffset: 0, extentOffset: initialValue.length),
                onChanged: (v) => value = v,
                decoration: const InputDecoration(
                  isDense: true,
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFEAEAEA))),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF333333))),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL", style: TextStyle(color: Color(0xFF888888)))),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, value),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF333333), foregroundColor: Colors.white, elevation: 0),
                    child: const Text("SAVE"),
                  ),
                ],
              )
            ],
          ),
        ),
      )
    );
  }

  Future<Map<String, dynamic>?> _showCloneDialog(String table) async {
    String value = "${table}_copy";
    bool duplicateData = true;
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Clone Table", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF333333))),
                const SizedBox(height: 24),
                const Text("New Table Name", style: TextStyle(fontSize: 12, color: Color(0xFF888888))),
                const SizedBox(height: 8),
                TextField(
                  autofocus: true,
                  controller: TextEditingController(text: value)..selection = TextSelection(baseOffset: 0, extentOffset: value.length),
                  onChanged: (v) => value = v,
                  decoration: const InputDecoration(
                    isDense: true,
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFEAEAEA))),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF333333))),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Checkbox(
                      value: duplicateData,
                      onChanged: (v) => setState(() => duplicateData = v ?? false),
                      activeColor: const Color(0xFF333333),
                    ),
                    const Text("Duplicate table data", style: TextStyle(fontSize: 13, color: Color(0xFF555555))),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL", style: TextStyle(color: Color(0xFF888888)))),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, {'name': value, 'data': duplicateData}),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF333333), foregroundColor: Colors.white, elevation: 0),
                      child: const Text("CLONE"),
                    ),
                  ],
                )
              ],
            ),
          ),
        )
      )
    );
  }

  Future<bool?> _showConfirmDialog({required String title, required String message, bool showFkCheckbox = false, String confirmText = "CONFIRM"}) async {
    bool disableFk = false;
    return showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFFD32F2F))),
                const SizedBox(height: 16),
                Text(message, style: const TextStyle(fontSize: 13, color: Color(0xFF555555), height: 1.5)),
                if (showFkCheckbox) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: disableFk,
                        onChanged: (v) => setState(() => disableFk = v ?? false),
                        activeColor: const Color(0xFFD32F2F),
                      ),
                      const Expanded(child: Text("Disable Foreign Key Checks", style: TextStyle(fontSize: 13, color: Color(0xFF555555)))),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL", style: TextStyle(color: Color(0xFF888888)))),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, showFkCheckbox ? disableFk : true),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F), foregroundColor: Colors.white, elevation: 0),
                      child: Text(confirmText),
                    ),
                  ],
                )
              ],
            ),
          ),
        )
      )
    );
  }

  Future<void> _createDatabase() async {
    final name = await _showFormDialog(title: "Create Database", label: "Database Name");
    if (name == null || name.isEmpty) return;
    try {
      await executeMysqlAction(url: widget.connection.url, database: '', query: 'CREATE DATABASE `$name`', disableFk: false);
      _fetchDatabases();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  Future<void> _renameDatabase(String oldDb) async {
    final newDb = await _showFormDialog(title: "Rename Database", label: "New Database Name", initialValue: oldDb);
    if (newDb == null || newDb.isEmpty || newDb == oldDb) return;
    try {
      await executeMysqlAction(url: widget.connection.url, database: '', query: 'CREATE DATABASE `$newDb`', disableFk: false);
      final tables = _databaseTables[oldDb] ?? [];
      for (var table in tables) {
        await executeMysqlAction(url: widget.connection.url, database: '', query: 'RENAME TABLE `$oldDb`.`$table` TO `$newDb`.`$table`', disableFk: false);
      }
      await executeMysqlAction(url: widget.connection.url, database: '', query: 'DROP DATABASE `$oldDb`', disableFk: false);
      _fetchDatabases();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  Future<void> _dropDatabase(String db) async {
    final confirm = await _showConfirmDialog(title: "Drop Database", message: "Are you sure you want to drop database '$db'? This action cannot be undone.", confirmText: "DROP");
    if (confirm != true) return;
    try {
      await executeMysqlAction(url: widget.connection.url, database: '', query: 'DROP DATABASE `$db`', disableFk: false);
      _fetchDatabases();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  Future<void> _createTable(String db) async {
    final name = await _showFormDialog(title: "Create Table", label: "Table Name");
    if (name == null || name.isEmpty) return;
    try {
      await executeMysqlAction(url: widget.connection.url, database: db, query: 'CREATE TABLE `$name` (id INT PRIMARY KEY AUTO_INCREMENT)', disableFk: false);
      _fetchDatabases();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  Future<void> _cloneTable(String db, String table) async {
    final result = await _showCloneDialog(table);
    if (result == null) return;
    final newName = result['name'];
    final dupData = result['data'];
    try {
      await executeMysqlAction(url: widget.connection.url, database: db, query: 'CREATE TABLE `$newName` LIKE `$table`', disableFk: false);
      if (dupData) {
        await executeMysqlAction(url: widget.connection.url, database: db, query: 'INSERT INTO `$newName` SELECT * FROM `$table`', disableFk: false);
      }
      _fetchDatabases();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  Future<void> _truncateTable(String db, String table) async {
    final disableFk = await _showConfirmDialog(title: "Truncate Table", message: "Are you sure you want to truncate table '$table'? All data will be lost.", showFkCheckbox: true, confirmText: "TRUNCATE");
    if (disableFk == null) return;
    try {
      await executeMysqlAction(url: widget.connection.url, database: db, query: 'TRUNCATE TABLE `$table`', disableFk: disableFk);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Table truncated successfully."), backgroundColor: Color(0xFF333333)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  Future<void> _dropTable(String db, String table) async {
    final disableFk = await _showConfirmDialog(title: "Drop Table", message: "Are you sure you want to drop table '$table'? This action cannot be undone.", showFkCheckbox: true, confirmText: "DROP");
    if (disableFk == null) return;
    try {
      await executeMysqlAction(url: widget.connection.url, database: db, query: 'DROP TABLE `$table`', disableFk: disableFk);
      _closeTab("table_${db}_$table");
      _fetchDatabases();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("WORKSPACE — ${widget.connection.name.toUpperCase()}"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isConnectionAlive ? Colors.green : Colors.red,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isConnectionAlive ? "Connected" : "Disconnected",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _isConnectionAlive ? Colors.green : Colors.red,
                    ),
                  ),
                  if (!_isConnectionAlive) ...[
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _isCheckingConnection ? null : _reconnect,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: _isCheckingConnection 
                          ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text("RECONNECT", style: TextStyle(fontSize: 11, color: Colors.red)),
                    ),
                  ],
                ],
              ),
            ),
          )
        ],
      ),
      body: Row(
        children: [
          // Sidebar
          Container(
            width: _sidebarWidth,
            color: const Color(0xFFFAFAFA),
            child: _buildSidebar(),
          ),
          
          // Resize Handle
          MouseRegion(
            cursor: SystemMouseCursors.resizeLeftRight,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanUpdate: (details) {
                setState(() {
                  _sidebarWidth += details.delta.dx;
                  if (_sidebarWidth < 200) _sidebarWidth = 200;
                  if (_sidebarWidth > 600) _sidebarWidth = 600;
                });
              },
              child: Container(
                width: 4,
                color: Colors.transparent,
                child: Center(
                  child: Container(width: 1, color: const Color(0xFFEAEAEA)),
                ),
              ),
            ),
          ),
          
          // Main Area
          Expanded(
            child: Column(
              children: [
                // Tabs Bar
                _buildTabsBar(),
                
                // Tab Content
                Expanded(
                  child: Container(
                    color: const Color(0xFFFFFFFF),
                    child: _tabs.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: const Color(0xFFEAEAEA), width: 1),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  "Select a table or open a query tab to begin.",
                                  style: TextStyle(color: Color(0xFF999999), fontSize: 13, letterSpacing: 0.5),
                                ),
                              ],
                            ),
                          )
                        : _buildActiveTabContent(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    if (_isLoadingDatabases) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFCCCCCC), strokeWidth: 2));
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Color(0xFFD32F2F), size: 32),
              const SizedBox(height: 12),
              Text(_errorMessage, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
              const SizedBox(height: 12),
              TextButton(onPressed: _fetchDatabases, child: const Text("RETRY"))
            ],
          ),
        ),
      );
    }

    String dbQ = _databaseSearchQuery.toLowerCase();
    List<String> filteredDatabases = _databases.where((db) {
      return db.toLowerCase().contains(dbQ);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: _openQueryTab,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.terminal, size: 16, color: Color(0xFF333333)),
                      const SizedBox(width: 12),
                      const Text("New Query", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF333333))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "DATABASES",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF888888),
                      letterSpacing: 0.5,
                    ),
                  ),
                  InkWell(
                    onTap: _createDatabase,
                    child: const Padding(
                      padding: EdgeInsets.all(4.0),
                      child: Icon(Icons.add, size: 16, color: Color(0xFF888888)),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 36,
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: "Filter databases...",
                    hintStyle: TextStyle(color: Color(0xFF999999)),
                    prefixIcon: Icon(Icons.search, size: 16, color: Color(0xFF999999)),
                    contentPadding: EdgeInsets.symmetric(vertical: 0),
                    fillColor: Colors.transparent,
                    filled: true,
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFE0E0E0))),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF333333))),
                  ),
                  style: const TextStyle(fontSize: 13, color: Color(0xFF333333)),
                  onChanged: (val) {
                    setState(() {
                      _databaseSearchQuery = val;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: filteredDatabases.length,
            itemBuilder: (context, index) {
              final db = filteredDatabases[index];
              final allTables = _databaseTables[db] ?? [];
              final tableQ = (_tableSearchQueries[db] ?? '').toLowerCase();
              
              final tables = allTables.where((t) {
                if (tableQ.isEmpty) return true;
                return t.toLowerCase().contains(tableQ);
              }).toList();
              
              final controller = _tableSearchControllers.putIfAbsent(
                db,
                () => TextEditingController(text: _tableSearchQueries[db] ?? ''),
              );

              return ExpansionTile(
                key: PageStorageKey('db_$db'),
                title: Row(
                  children: [
                    Expanded(child: Text(db, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF333333)))),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 16, color: Color(0xFF999999)),
                      padding: EdgeInsets.zero,
                      onSelected: (val) {
                        if (val == 'rename') _renameDatabase(db);
                        if (val == 'drop') _dropDatabase(db);
                        if (val == 'create_table') _createTable(db);
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'create_table', child: Text("Create Table", style: TextStyle(fontSize: 13))),
                        const PopupMenuItem(value: 'rename', child: Text("Rename Database", style: TextStyle(fontSize: 13))),
                        const PopupMenuItem(value: 'drop', child: Text("Drop Database", style: TextStyle(fontSize: 13, color: Colors.red))),
                      ]
                    )
                  ],
                ),
                leading: const Icon(Icons.data_usage, size: 18, color: Color(0xFF5C6670)),
                iconColor: const Color(0xFF333333),
                shape: const Border(), // Remove borders
                childrenPadding: EdgeInsets.zero,
                children: [
                  // Search box for tables inside this DB
                  if (allTables.isNotEmpty)
                    PageStorage(
                      bucket: PageStorageBucket(),
                      child: Padding(
                        key: ValueKey('search_padding_$db'),
                        padding: const EdgeInsets.fromLTRB(48, 4, 16, 8),
                        child: SizedBox(
                          height: 32,
                          child: TextField(
                            key: ValueKey('search_field_$db'),
                            controller: controller,
                            decoration: const InputDecoration(
                              hintText: "Filter tables...",
                              hintStyle: TextStyle(color: Color(0xFF999999)),
                              prefixIcon: Icon(Icons.search, size: 14, color: Color(0xFF999999)),
                              contentPadding: EdgeInsets.symmetric(vertical: 0),
                              fillColor: Colors.transparent,
                              filled: true,
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFE0E0E0))),
                              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF333333))),
                            ),
                            style: const TextStyle(fontSize: 12, color: Color(0xFF333333)),
                            onChanged: (val) {
                              setState(() {
                                _tableSearchQueries[db] = val;
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                  // List of tables
                  ...tables.map((table) => InkWell(
                    key: ValueKey('table_btn_${db}_$table'),
                    onTap: () => _openTableTab(db, table),
                    child: Container(
                      padding: const EdgeInsets.only(left: 48, right: 16, top: 4, bottom: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.table_chart_outlined, size: 16, color: Color(0xFF888888)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(table, style: const TextStyle(fontSize: 13, color: Color(0xFF555555), height: 1.2), overflow: TextOverflow.ellipsis),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_horiz, size: 16, color: Color(0xFFCCCCCC)),
                            padding: EdgeInsets.zero,
                            onSelected: (val) {
                              if (val == 'clone') _cloneTable(db, table);
                              if (val == 'truncate') _truncateTable(db, table);
                              if (val == 'drop') _dropTable(db, table);
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'clone', child: Text("Clone Table", style: TextStyle(fontSize: 13))),
                              const PopupMenuItem(value: 'truncate', child: Text("Truncate Data", style: TextStyle(fontSize: 13))),
                              const PopupMenuItem(value: 'drop', child: Text("Drop Table", style: TextStyle(fontSize: 13, color: Colors.red))),
                            ]
                          )
                        ],
                      ),
                    ),
                  )),
                  // Show message if no tables match
                  if (tables.isEmpty && allTables.isNotEmpty)
                    Padding(
                      key: ValueKey('no_tables_$db'),
                      padding: const EdgeInsets.fromLTRB(48, 8, 16, 16),
                      child: const Text("No tables match filter.", style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
                    )
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTabsBar() {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAFA),
        border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _tabs.length,
        itemBuilder: (context, index) {
          final tab = _tabs[index];
          final isActive = tab.id == _activeTabId;

          return InkWell(
            onTap: () => setState(() => _activeTabId = tab.id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFFFFFFFF) : Colors.transparent,
                border: Border(
                  top: BorderSide(
                    color: isActive ? const Color(0xFF333333) : Colors.transparent,
                    width: 2,
                  ),
                  right: const BorderSide(color: Color(0xFFF0F0F0)),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    tab.tableName == null ? Icons.terminal : Icons.table_chart_outlined,
                    size: 14,
                    color: isActive ? const Color(0xFF333333) : const Color(0xFF888888),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tab.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      color: isActive ? const Color(0xFF333333) : const Color(0xFF555555),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _closeTab(tab.id),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(Icons.close, size: 14, color: isActive ? const Color(0xFF333333) : const Color(0xFF888888)),
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActiveTabContent() {
    final activeTab = _tabs.firstWhere((t) => t.id == _activeTabId);

    if (activeTab.tableName != null) {
      // Table Data View
      return _buildTableDataView(activeTab);
    } else {
      // Query Editor View
      return _buildQueryEditorView(activeTab);
    }
  }

  Widget _buildTableDataView(WorkspaceTab tab) {
    return _TableDataWidget(
      key: ValueKey(tab.id),
      connectionUrl: widget.connection.url,
      databaseName: tab.databaseName,
      tableName: tab.tableName!,
    );
  }

  Widget _buildQueryEditorView(WorkspaceTab tab) {
    return _QueryEditorWidget(
      key: ValueKey(tab.id),
      connectionUrl: widget.connection.url,
      databaseName: tab.databaseName,
    );
  }
}

class _TableDataWidget extends StatefulWidget {
  final String connectionUrl;
  final String databaseName;
  final String tableName;

  const _TableDataWidget({
    super.key,
    required this.connectionUrl,
    required this.databaseName,
    required this.tableName,
  });

  @override
  State<_TableDataWidget> createState() => _TableDataWidgetState();
}

class _TableDataWidgetState extends State<_TableDataWidget> {
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              child: Container(
                width: 400,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Add New Row", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF333333))),
                    const SizedBox(height: 24),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: _result!.columns.map((col) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: TextField(
                                decoration: InputDecoration(
                                  labelText: col,
                                  labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
                                  enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFEAEAEA))),
                                  focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF333333))),
                                  isDense: true,
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
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCEL", style: TextStyle(color: Color(0xFF888888)))),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true), 
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF333333), foregroundColor: Colors.white, elevation: 0),
                          child: const Text("SAVE")
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
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _deleteSelectedRows() async {
    if (_selectedRowIndices.isEmpty || _result == null) return;
    
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Delete Rows", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFFD32F2F))),
              const SizedBox(height: 16),
              Text("Are you sure you want to delete ${_selectedRowIndices.length} row(s)? This action cannot be undone.", style: const TextStyle(fontSize: 13, color: Color(0xFF555555), height: 1.5)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCEL", style: TextStyle(color: Color(0xFF888888)))),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F), foregroundColor: Colors.white, elevation: 0),
                    onPressed: () => Navigator.pop(context, true), 
                    child: const Text("DELETE")
                  ),
                ],
              )
            ],
          ),
        ),
      )
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
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
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEAEAEA))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            _isLoadingCount ? "Loading count..." : "Total: $_totalRows rows", 
            style: const TextStyle(fontSize: 12, color: Color(0xFF888888))
          ),
          const Spacer(),
          Text(
            "Page $currentPageDisplay of ${totalPages > 0 ? totalPages : 1}",
            style: const TextStyle(fontSize: 12, color: Color(0xFF555555)),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 20),
            onPressed: _currentPage > 0 && !_isLoading ? _prevPage : null,
            color: const Color(0xFF333333),
            disabledColor: const Color(0xFFCCCCCC),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 20),
            onPressed: ((_currentPage + 1) * _pageSize < _totalRows) && !_isLoading ? _nextPage : null,
            color: const Color(0xFF333333),
            disabledColor: const Color(0xFFCCCCCC),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _result == null) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFCCCCCC), strokeWidth: 2));
    }

    if (_error.isNotEmpty && _result == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFD32F2F), size: 32),
            const SizedBox(height: 12),
            Text(_error, style: const TextStyle(color: Color(0xFFD32F2F))),
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
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFEAEAEA))),
              ),
              child: Row(
                children: [
                  Text("Database: ${widget.databaseName} > Table: ${widget.tableName}", style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
                  const Spacer(),
                  if (_selectedRowIndices.isNotEmpty) ...[
                    Text("${_selectedRowIndices.length} selected", style: const TextStyle(fontSize: 12, color: Color(0xFFD32F2F))),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFD32F2F)),
                      onPressed: _deleteSelectedRows,
                      tooltip: "Delete Selected",
                    ),
                    const SizedBox(width: 8),
                    Container(width: 1, height: 16, color: const Color(0xFFEAEAEA)),
                    const SizedBox(width: 8),
                  ],
                  IconButton(
                    icon: const Icon(Icons.add, size: 16, color: Color(0xFF555555)),
                    onPressed: _addNewRow,
                    tooltip: "Add Row",
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 16, color: Color(0xFF555555)),
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
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFCCCCCC), strokeWidth: 2)) 
              : _buildDataGrid(
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

class _QueryEditorWidget extends StatefulWidget {
  final String connectionUrl;
  final String databaseName;

  const _QueryEditorWidget({
    super.key,
    required this.connectionUrl,
    required this.databaseName,
  });

  @override
  State<_QueryEditorWidget> createState() => _QueryEditorWidgetState();
}

class _QueryEditorWidgetState extends State<_QueryEditorWidget> {
  final TextEditingController _queryController = TextEditingController();
  bool _isRunning = false;
  String _error = '';
  QueryResult? _result;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
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
        query: query
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
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  Text("Querying Database: ${widget.databaseName}", style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _queryController,
                maxLines: 5,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 14, color: Color(0xFF333333)),
                decoration: const InputDecoration(
                  hintText: "Enter SQL Query here...",
                  filled: true,
                  fillColor: Color(0xFFFAFAFA),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _isRunning ? null : _runQuery,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7F0019),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                ),
                icon: _isRunning 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.play_arrow, size: 16),
                label: Text(_isRunning ? "RUNNING..." : "RUN QUERY", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFEAEAEA)),
        Expanded(
          child: _isRunning
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFCCCCCC), strokeWidth: 2))
              : _error.isNotEmpty 
                  ? Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(_error, style: const TextStyle(color: Color(0xFFD32F2F))),
                    )
                  : _result != null
                      ? _buildDataGrid(context, _result!)
                      : const Center(
                          child: Text("Run a query to see results.", style: TextStyle(color: Color(0xFF999999))),
                        ),
        ),
      ],
    );
  }
}

Widget _buildDataGrid(
  BuildContext context, 
  QueryResult result, {
  Future<void> Function(String column, String oldValue, String newValue, Map<String, String> rowMap)? onSave,
  Set<int>? selectedIndices,
  Function(int, bool)? onSelectChanged,
  Function(bool?)? onSelectAll,
}) {
  if (result.columns.isEmpty) {
    return const Center(child: Text("0 rows returned.", style: TextStyle(color: Color(0xFF999999))));
  }

  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: DataTable(
            showCheckboxColumn: onSelectChanged != null,
            onSelectAll: onSelectAll,
            headingRowColor: WidgetStateProperty.resolveWith((states) => const Color(0xFFFAFAFA)),
            dataRowColor: WidgetStateProperty.resolveWith((states) => Colors.white),
            dividerThickness: 1,
            border: const TableBorder(
              horizontalInside: BorderSide(color: Color(0xFFF0F0F0), width: 1),
              bottom: BorderSide(color: Color(0xFFF0F0F0), width: 1),
            ),
            columns: result.columns.map((col) => DataColumn(
              label: Text(
                col.toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11, color: Color(0xFF888888), letterSpacing: 0.5),
              )
            )).toList(),
            rows: result.rows.asMap().entries.map((rowEntry) {
              final rowIndex = rowEntry.key;
              final row = rowEntry.value;
              final rowMap = {
                for (var i = 0; i < result.columns.length; i++) result.columns[i]: row[i]
              };
              
              return DataRow(
                selected: selectedIndices?.contains(rowIndex) ?? false,
                onSelectChanged: onSelectChanged == null ? null : (selected) => onSelectChanged(rowIndex, selected ?? false),
                cells: row.asMap().entries.map((entry) {
                  final colIndex = entry.key;
                  final cell = entry.value;
                  final colName = result.columns[colIndex];
                  
                  final isNull = cell == 'NULL';
                  final isEmpty = cell.isEmpty;
                  final isSpecial = isNull || isEmpty;
                  
                  String displayValue = cell;
                  if (isEmpty) displayValue = 'EMPTY';

                  return DataCell(
                    _InlineEditCell(
                      columnName: colName,
                      initialValue: cell,
                      displayValue: displayValue,
                      isSpecial: isSpecial,
                      onSave: onSave == null ? null : (newValue) async {
                        await onSave(colName, cell, newValue, rowMap);
                      },
                    ),
                  );
              }).toList(),
            );
          }).toList(),
        ),
      ),
    ),
  );
}

class _InlineEditCell extends StatelessWidget {
  final String columnName;
  final String initialValue;
  final String displayValue;
  final bool isSpecial;
  final Future<void> Function(String newValue)? onSave;

  const _InlineEditCell({
    required this.columnName,
    required this.initialValue,
    required this.displayValue,
    required this.isSpecial,
    this.onSave,
  });

  void _openEditPanel(BuildContext context) {
    if (onSave == null) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withValues(alpha: 0.1),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) {
        String currentValue = isSpecial ? "" : initialValue;
        bool isSaving = false;
        String? saveError;

        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.white,
            elevation: 0,
            child: Container(
              width: 400,
              height: double.infinity,
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: Color(0xFFF0F0F0))),
              ),
              child: StatefulBuilder(
                builder: (context, setState) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          columnName.toUpperCase(),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF888888), letterSpacing: 0.5),
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFF0F0F0)),
                      
                      // Editor
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                initialValue: currentValue,
                                maxLines: null,
                                autofocus: true,
                                onChanged: (val) {
                                  currentValue = val;
                                  if (saveError != null) setState(() => saveError = null);
                                },
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isSpecial ? const Color(0xFF333333).withValues(alpha: 0.4) : const Color(0xFF333333),
                                  fontStyle: isSpecial ? FontStyle.italic : FontStyle.normal,
                                  height: 1.5,
                                ),
                                decoration: InputDecoration(
                                  hintText: isSpecial ? displayValue : "Enter value...",
                                  hintStyle: const TextStyle(color: Color(0xFF999999)),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                              if (saveError != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: Text(saveError!, style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 12)),
                                ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Footer
                      const Divider(height: 1, color: Color(0xFFF0F0F0)),
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF555555),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              ),
                              child: const Text("CANCEL"),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: isSaving ? null : () async {
                                if (currentValue == initialValue && !isSpecial) {
                                  Navigator.pop(context);
                                  return;
                                }
                                setState(() {
                                  isSaving = true;
                                  saveError = null;
                                });
                                try {
                                  await onSave!(currentValue);
                                  if (context.mounted) Navigator.pop(context);
                                } catch (e) {
                                  setState(() {
                                    isSaving = false;
                                    saveError = e.toString();
                                  });
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF333333),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                              ),
                              child: isSaving 
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Text("SAVE", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openEditPanel(context),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 200, minWidth: 50),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          displayValue,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13, 
            color: isSpecial ? const Color(0xFF333333).withValues(alpha: 0.4) : const Color(0xFF333333),
            fontStyle: isSpecial ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ),
    );
  }
}
