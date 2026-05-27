import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../connections/models/database_connection.dart';
import '../models/workspace_tab.dart';
import '../services/database_service.dart';

class WorkspaceSchemaState {
  final bool isLoadingDatabases;
  final String errorMessage;
  final List<String> databases;
  final Map<String, List<String>> databaseTables;

  const WorkspaceSchemaState({
    required this.isLoadingDatabases,
    required this.errorMessage,
    required this.databases,
    required this.databaseTables,
  });

  const WorkspaceSchemaState.loading()
    : isLoadingDatabases = true,
      errorMessage = '',
      databases = const [],
      databaseTables = const {};
}

class WorkspaceTabsState {
  final List<WorkspaceTab> tabs;
  final String? activeTabId;

  const WorkspaceTabsState({required this.tabs, required this.activeTabId});
}

class WorkspaceConnectionState {
  final bool isAlive;
  final bool isChecking;

  const WorkspaceConnectionState({
    required this.isAlive,
    required this.isChecking,
  });
}

@visibleForTesting
Map<String, List<String>> immutableDatabaseTablesSnapshot(
  Map<String, List<String>> databaseTables,
) {
  return Map<String, List<String>>.unmodifiable(<String, List<String>>{
    for (final entry in databaseTables.entries)
      entry.key: List<String>.unmodifiable(entry.value),
  });
}

/// Controller to manage state and business logic for the Workspace feature,
/// decoupling it entirely from the Flutter UI layout.
class WorkspaceController {
  final DatabaseConnection connection;
  final DatabaseService _dbService;

  final ValueNotifier<WorkspaceSchemaState> schemaState =
      ValueNotifier<WorkspaceSchemaState>(const WorkspaceSchemaState.loading());
  final ValueNotifier<WorkspaceTabsState> tabsState =
      ValueNotifier<WorkspaceTabsState>(
        const WorkspaceTabsState(tabs: [], activeTabId: null),
      );
  final ValueNotifier<WorkspaceConnectionState> connectionState =
      ValueNotifier<WorkspaceConnectionState>(
        const WorkspaceConnectionState(isAlive: true, isChecking: false),
      );

  bool _isLoadingDatabases = true;
  String _errorMessage = '';
  List<String> _databases = [];
  final Map<String, List<String>> _databaseTables = {};

  final List<WorkspaceTab> _tabs = [];
  String? _activeTabId;

  bool _isConnectionAlive = true;
  bool _isCheckingConnection = false;
  Timer? _connectionCheckTimer;

  WorkspaceController({required this.connection})
    : _dbService = DatabaseService(url: connection.url) {
    _init();
  }

  bool get isLoadingDatabases => _isLoadingDatabases;
  String get errorMessage => _errorMessage;
  List<String> get databases => _databases;
  Map<String, List<String>> get databaseTables => _databaseTables;

  List<WorkspaceTab> get tabs => _tabs;
  String? get activeTabId => _activeTabId;

  bool get isConnectionAlive => _isConnectionAlive;
  bool get isCheckingConnection => _isCheckingConnection;

  void _init() {
    fetchDatabases();
    checkConnection();
    _connectionCheckTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => checkConnection(),
    );
  }

  void dispose() {
    _connectionCheckTimer?.cancel();
    schemaState.dispose();
    tabsState.dispose();
    connectionState.dispose();
  }

  void _publishSchemaState() {
    schemaState.value = WorkspaceSchemaState(
      isLoadingDatabases: _isLoadingDatabases,
      errorMessage: _errorMessage,
      databases: List<String>.unmodifiable(_databases),
      databaseTables: immutableDatabaseTablesSnapshot(_databaseTables),
    );
  }

  void _publishTabsState() {
    tabsState.value = WorkspaceTabsState(
      tabs: List.unmodifiable(_tabs),
      activeTabId: _activeTabId,
    );
  }

  void _publishConnectionState() {
    connectionState.value = WorkspaceConnectionState(
      isAlive: _isConnectionAlive,
      isChecking: _isCheckingConnection,
    );
  }

  /// Perform a heartbeat query to check if the connection is alive.
  Future<void> checkConnection() async {
    if (_isCheckingConnection) return;

    final wasAlive = _isConnectionAlive;
    _isCheckingConnection = true;
    if (!wasAlive) {
      _publishConnectionState();
    }

    try {
      _isConnectionAlive = await _dbService.checkConnection();
    } catch (_) {
      _isConnectionAlive = false;
    } finally {
      _isCheckingConnection = false;
      if (!wasAlive || wasAlive != _isConnectionAlive) {
        _publishConnectionState();
      }
    }
  }

  /// Attempt to check connectivity and reload database schema lists if alive.
  Future<void> reconnect() async {
    await checkConnection();
    if (_isConnectionAlive) {
      await fetchDatabases();
    }
  }

  /// Fetch all databases and tables in one Rust call.
  Future<void> fetchDatabases() async {
    _isLoadingDatabases = true;
    _errorMessage = '';
    _publishSchemaState();

    try {
      final overview = await _dbService.fetchSchemaOverview();
      _databases = overview.databases.map((db) => db.name).toList();
      _databaseTables
        ..clear()
        ..addEntries(
          overview.databases.map(
            (db) => MapEntry(db.name, List<String>.from(db.tables)),
          ),
        );
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoadingDatabases = false;
      _publishSchemaState();
    }
  }

  /// Open a browsing tab for a database table.
  void openTableTab(String db, String table) {
    final tabId = "table_${db}_$table";
    final existingIndex = _tabs.indexWhere((t) => t.id == tabId);

    if (existingIndex >= 0) {
      _activeTabId = tabId;
    } else {
      _tabs.add(
        WorkspaceTab(
          id: tabId,
          title: table,
          databaseName: db,
          tableName: table,
        ),
      );
      _activeTabId = tabId;
    }
    _publishTabsState();
  }

  /// Open a new custom SQL query execution tab.
  void openQueryTab() {
    final tabId = "query_${DateTime.now().millisecondsSinceEpoch}";
    _tabs.add(
      WorkspaceTab(
        id: tabId,
        title: "New Query",
        databaseName: '',
        tableName: null,
      ),
    );
    _activeTabId = tabId;
    _publishTabsState();
  }

  /// Close an open tab.
  void closeTab(String tabId) {
    final index = _tabs.indexWhere((t) => t.id == tabId);
    if (index < 0) return;

    _tabs.removeAt(index);
    if (_activeTabId == tabId) {
      if (_tabs.isNotEmpty) {
        _activeTabId = _tabs[index > 0 ? index - 1 : 0].id;
      } else {
        _activeTabId = null;
      }
    }
    _publishTabsState();
  }

  /// Change active selection to the specified tab.
  void selectTab(String tabId) {
    if (_activeTabId == tabId) return;
    _activeTabId = tabId;
    _publishTabsState();
  }

  // ==========================================
  // Database / Schema CRUD Operations
  // ==========================================

  /// Execute CREATE DATABASE.
  Future<void> createDatabase(String name) async {
    await _dbService.createDatabase(name);
    await fetchDatabases();
  }

  /// Execute RENAME DATABASE by migrating all tables.
  Future<void> renameDatabase(String oldDb, String newDb) async {
    final tables = _databaseTables[oldDb] ?? [];
    await _dbService.renameDatabase(oldDb, newDb, tables);
    await fetchDatabases();
  }

  /// Execute DROP DATABASE.
  Future<void> dropDatabase(String db) async {
    await _dbService.dropDatabase(db);
    await fetchDatabases();
  }

  /// Execute CREATE TABLE.
  Future<void> createTable(String db, String name) async {
    await _dbService.createTable(db, name);
    await fetchDatabases();
  }

  /// Execute table cloning.
  Future<void> cloneTable(
    String db,
    String table,
    String newName,
    bool duplicateData,
  ) async {
    await _dbService.cloneTable(db, table, newName, duplicateData);
    await fetchDatabases();
  }

  /// Execute TRUNCATE TABLE.
  Future<void> truncateTable(String db, String table, bool disableFk) async {
    await _dbService.truncateTable(db, table, disableFk);
  }

  /// Execute DROP TABLE.
  Future<void> dropTable(String db, String table, bool disableFk) async {
    await _dbService.dropTable(db, table, disableFk);
    closeTab("table_${db}_$table");
    await fetchDatabases();
  }
}
