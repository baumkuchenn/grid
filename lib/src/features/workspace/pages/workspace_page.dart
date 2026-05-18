import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../connections/models/database_connection.dart';
import '../widgets/table_data_view.dart';
import '../widgets/query_editor_view.dart';
import '../widgets/workspace_sidebar.dart';
import '../widgets/workspace_tabs_bar.dart';
import '../widgets/workspace_dialogs.dart';
import '../controllers/workspace_controller.dart';

class WorkspacePage extends StatefulWidget {
  final DatabaseConnection connection;

  const WorkspacePage({super.key, required this.connection});

  @override
  State<WorkspacePage> createState() => _WorkspacePageState();
}

class _WorkspacePageState extends State<WorkspacePage> {
  late final WorkspaceController _controller;
  late final ValueNotifier<double> _sidebarWidthNotifier;
  double _lastSidebarWidth = 280.0;
  final FocusNode _searchFocusNode = FocusNode();

  Widget? _activeTabWidgetCache;
  String? _lastActiveTabId;

  @override
  void initState() {
    super.initState();
    _controller = WorkspaceController(connection: widget.connection);
    _sidebarWidthNotifier = ValueNotifier<double>(280.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchFocusNode.dispose();
    _sidebarWidthNotifier.dispose();
    super.dispose();
  }

  Future<void> _createDatabase() async {
    final name = await WorkspaceDialogs.showForm(context: context, title: "Create Database", label: "Database Name");
    if (name == null || name.isEmpty) return;
    try {
      await _controller.createDatabase(name);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: const Color(0xFFB06A60)));
    }
  }

  Future<void> _renameDatabase(String oldDb) async {
    final newDb = await WorkspaceDialogs.showForm(context: context, title: "Rename Database", label: "New Database Name", initialValue: oldDb);
    if (newDb == null || newDb.isEmpty || newDb == oldDb) return;
    try {
      await _controller.renameDatabase(oldDb, newDb);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: const Color(0xFFB06A60)));
    }
  }

  Future<void> _dropDatabase(String db) async {
    final confirm = await WorkspaceDialogs.showConfirm(context: context, title: "Drop Database", message: "Are you sure you want to drop database '$db'? This action cannot be undone.", confirmText: "DROP");
    if (confirm != true) return;
    try {
      await _controller.dropDatabase(db);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: const Color(0xFFB06A60)));
    }
  }

  Future<void> _createTable(String db) async {
    final name = await WorkspaceDialogs.showForm(context: context, title: "Create Table", label: "Table Name");
    if (name == null || name.isEmpty) return;
    try {
      await _controller.createTable(db, name);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: const Color(0xFFB06A60)));
    }
  }

  Future<void> _cloneTable(String db, String table) async {
    final result = await WorkspaceDialogs.showCloneTable(context: context, table: table);
    if (result == null) return;
    final newName = result['name'];
    final dupData = result['data'];
    try {
      await _controller.cloneTable(db, table, newName, dupData);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: const Color(0xFFB06A60)));
    }
  }

  Future<void> _truncateTable(String db, String table) async {
    final disableFk = await WorkspaceDialogs.showConfirm(context: context, title: "Truncate Table", message: "Are you sure you want to truncate table '$table'? All data will be lost.", showFkCheckbox: true, confirmText: "TRUNCATE");
    if (disableFk == null) return;
    try {
      await _controller.truncateTable(db, table, disableFk);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Table truncated successfully."), backgroundColor: Color(0xFF4A4A4A)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: const Color(0xFFB06A60)));
    }
  }

  Future<void> _dropTable(String db, String table) async {
    final disableFk = await WorkspaceDialogs.showConfirm(context: context, title: "Drop Table", message: "Are you sure you want to drop table '$table'? This action cannot be undone.", showFkCheckbox: true, confirmText: "DROP");
    if (disableFk == null) return;
    try {
      await _controller.dropTable(db, table, disableFk);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: const Color(0xFFB06A60)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.slash): () {
              _searchFocusNode.requestFocus();
            },
            const SingleActivator(LogicalKeyboardKey.keyF, meta: true): () {
              _searchFocusNode.requestFocus();
            },
            const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
              _searchFocusNode.requestFocus();
            },
            const SingleActivator(LogicalKeyboardKey.keyB, meta: true): () {
              final width = _sidebarWidthNotifier.value;
              if (width > 0) {
                _lastSidebarWidth = width;
                _sidebarWidthNotifier.value = 0;
              } else {
                _sidebarWidthNotifier.value = _lastSidebarWidth;
              }
            },
            const SingleActivator(LogicalKeyboardKey.keyB, control: true): () {
              final width = _sidebarWidthNotifier.value;
              if (width > 0) {
                _lastSidebarWidth = width;
                _sidebarWidthNotifier.value = 0;
              } else {
                _sidebarWidthNotifier.value = _lastSidebarWidth;
              }
            },
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text("WORKSPACE — ${widget.connection.name.toUpperCase()}"),
              leadingWidth: 96,
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  ValueListenableBuilder<double>(
                    valueListenable: _sidebarWidthNotifier,
                    builder: (context, width, child) {
                      return IconButton(
                        icon: Icon(width > 0 ? Icons.menu_open : Icons.menu, size: 20),
                        onPressed: () {
                          if (width > 0) {
                            _lastSidebarWidth = width;
                            _sidebarWidthNotifier.value = 0;
                          } else {
                            _sidebarWidthNotifier.value = _lastSidebarWidth;
                          }
                        },
                        tooltip: "Toggle Sidebar (Zen Mode)",
                      );
                    },
                  ),
                ],
              ),
              actions: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _BreathingConnectionDot(isAlive: _controller.isConnectionAlive),
                        const SizedBox(width: 8),
                        Text(
                          _controller.isConnectionAlive ? "At rest / Connected" : "Offline / Quiet",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _controller.isConnectionAlive ? const Color(0xFF5A6B5C) : const Color(0xFFAC6B62),
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (!_controller.isConnectionAlive) ...[
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: _controller.isCheckingConnection ? null : _controller.reconnect,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: _controller.isCheckingConnection 
                                ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Text("RECONNECT", style: TextStyle(fontSize: 11, color: Color(0xFFB06A60))),
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
                ValueListenableBuilder<double>(
                  valueListenable: _sidebarWidthNotifier,
                  builder: (context, width, child) {
                    return SizedBox(
                      width: width,
                      child: child,
                    );
                  },
                  child: Container(
                    color: const Color(0xFFF3EFE9), // Kraft Sand (Notebook Binder Cover)
                    child: WorkspaceSidebar(
                      isLoadingDatabases: _controller.isLoadingDatabases,
                      errorMessage: _controller.errorMessage,
                      databases: _controller.databases,
                      databaseTables: _controller.databaseTables,
                      onRetryDatabases: _controller.fetchDatabases,
                      onOpenQueryTab: _controller.openQueryTab,
                      onOpenTableTab: _controller.openTableTab,
                      onCreateDatabase: _createDatabase,
                      onRenameDatabase: _renameDatabase,
                      onDropDatabase: _dropDatabase,
                      onCreateTable: _createTable,
                      onCloneTable: _cloneTable,
                      onTruncateTable: _truncateTable,
                      onDropTable: _dropTable,
                      searchFocusNode: _searchFocusNode,
                    ),
                  ),
                ),
                
                // Resize Handle
                MouseRegion(
                  cursor: SystemMouseCursors.resizeLeftRight,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onPanUpdate: (details) {
                      double newWidth = _sidebarWidthNotifier.value + details.delta.dx;
                      if (newWidth < 200) newWidth = 200;
                      if (newWidth > 600) newWidth = 600;
                      _sidebarWidthNotifier.value = newWidth;
                    },
                    child: Container(
                      width: 4,
                      color: Colors.transparent,
                      child: Center(
                        child: Container(width: 1, color: const Color(0xFFE8E5DF)), // Divider Clay
                      ),
                    ),
                  ),
                ),
                
                // Main Area
                Expanded(
                  child: Column(
                    children: [
                      WorkspaceTabsBar(
                        tabs: _controller.tabs,
                        activeTabId: _controller.activeTabId,
                        onTabSelected: _controller.selectTab,
                        onTabClosed: _controller.closeTab,
                      ),
                      
                      // Tab Content
                      Expanded(
                        child: Container(
                          color: const Color(0xFFFAF8F5), // Washi Cream Sheet backing
                          child: _controller.tabs.isEmpty
                              ? Center(
                                  child: Container(
                                    constraints: const BoxConstraints(maxWidth: 400),
                                    padding: const EdgeInsets.all(32),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "GRID",
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF7F0019), // Muji Red Title
                                            letterSpacing: 4.0,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          "Minimalist database workspace built for speed and visual clarity.",
                                          style: TextStyle(fontSize: 13, color: Color(0xFF73726F), height: 1.5),
                                        ),
                                        const SizedBox(height: 32),
                                        Container(width: 40, height: 1, color: const Color(0xFF7F0019)),
                                        const SizedBox(height: 24),
                                        const Text(
                                          "QUICK ACTIONS",
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF73726F), letterSpacing: 1.0),
                                        ),
                                        const SizedBox(height: 12),
                                        _buildShortcutRow("Click a table", "to browse data"),
                                        _buildShortcutRow("Click 'New Query'", "to write custom SQL"),
                                        const SizedBox(height: 20),
                                        const Text(
                                          "KEYBOARD SHORTCUTS",
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF73726F), letterSpacing: 1.0),
                                        ),
                                        const SizedBox(height: 12),
                                        _buildShortcutRow("Cmd + B / Ctrl + B", "Toggle Sidebar (Zen Mode)"),
                                        _buildShortcutRow("/ or Cmd + F", "Focus Sidebar Search"),
                                        _buildShortcutRow("Cmd + R / Ctrl + R", "Refresh Selected Table"),
                                      ],
                                    ),
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
          ),
        );
      },
    );
  }

  Widget _buildActiveTabContent() {
    if (_controller.tabs.isEmpty) {
      _activeTabWidgetCache = null;
      _lastActiveTabId = null;
      return const SizedBox.shrink();
    }

    final activeTab = _controller.tabs.firstWhere((t) => t.id == _controller.activeTabId);
    
    if (_activeTabWidgetCache != null && _lastActiveTabId == activeTab.id) {
      return _activeTabWidgetCache!;
    }

    _lastActiveTabId = activeTab.id;
    if (activeTab.tableName != null) {
      _activeTabWidgetCache = TableDataView(
        key: ValueKey(activeTab.id),
        connectionUrl: widget.connection.url,
        databaseName: activeTab.databaseName,
        tableName: activeTab.tableName!,
      );
    } else {
      _activeTabWidgetCache = QueryEditorView(
        key: ValueKey(activeTab.id),
        connectionUrl: widget.connection.url,
        databaseName: activeTab.databaseName,
      );
    }
    return _activeTabWidgetCache!;
  }

  Widget _buildShortcutRow(String trigger, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF3EFE9), // Kraft Sand shortcut tag
              border: Border.all(color: const Color(0xFFE8E5DF), width: 0.5), // Divider Clay
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              trigger,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2D2D2D)),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            description,
            style: const TextStyle(fontSize: 12, color: Color(0xFF73726F)), // Wood Ash description
          ),
        ],
      ),
    );
  }
}

class _BreathingConnectionDot extends StatefulWidget {
  final bool isAlive;

  const _BreathingConnectionDot({required this.isAlive});

  @override
  State<_BreathingConnectionDot> createState() => _BreathingConnectionDotState();
}

class _BreathingConnectionDotState extends State<_BreathingConnectionDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _opacityAnimation = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isAlive ? const Color(0xFF5A6B5C) : const Color(0xFFAC6B62);
    
    return FadeTransition(
      opacity: _opacityAnimation,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 4,
              spreadRadius: 1,
            )
          ],
        ),
      ),
    );
  }
}
