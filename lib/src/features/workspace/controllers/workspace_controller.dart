import 'dart:async';
import 'package:flutter/material.dart';
import '../models/workspace_tab.dart';
import '../services/database_service.dart';
import '../../connections/models/database_connection.dart';

/// Controller to manage state and business logic for the Workspace feature,
/// decoupling it entirely from the Flutter UI layout.
class WorkspaceController extends ChangeNotifier {
  final DatabaseConnection connection;
  final DatabaseService _dbService;

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
    _connectionCheckTimer = Timer.periodic(const Duration(seconds: 15), (_) => checkConnection());
  }

  @override
  void dispose() {
    _connectionCheckTimer?.cancel();
    super.dispose();
  }

  /// Perform a heartbeat query to check if the connection is alive
  Future<void> checkConnection() async {
    if (_isCheckingConnection) return;
    _isCheckingConnection = true;
    notifyListeners();

    try {
      final isAlive = await _dbService.checkConnection();
      if (_isConnectionAlive != isAlive) {
        _isConnectionAlive = isAlive;
      }
    } catch (_) {
      _isConnectionAlive = false;
    } finally {
      _isCheckingConnection = false;
      notifyListeners();
    }
  }

  /// Attempt to check connectivity and reload database schema lists if alive
  Future<void> reconnect() async {
    await checkConnection();
    if (_isConnectionAlive) {
      await fetchDatabases();
    }
  }

  /// Fetch all databases and asynchronously retrieve tables for each database
  Future<void> fetchDatabases() async {
    _isLoadingDatabases = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final dbs = await _dbService.fetchDatabases();
      _databases = dbs;
      notifyListeners();

      // Fetch tables for all databases in parallel to avoid sequential network bottleneck
      await Future.wait(dbs.map((db) async {
        try {
          final tables = await _dbService.fetchTables(db);
          _databaseTables[db] = tables;
        } catch (e) {
          debugPrint("Failed to fetch tables for $db: $e");
        }
      }));
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoadingDatabases = false;
      notifyListeners();
    }
  }

  /// Open a browsing tab for a database table
  void openTableTab(String db, String table) {
    final tabId = "table_${db}_$table";
    final existingIndex = _tabs.indexWhere((t) => t.id == tabId);

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
    notifyListeners();
  }

  /// Open a new custom SQL query execution tab
  void openQueryTab() {
    final tabId = "query_${DateTime.now().millisecondsSinceEpoch}";
    _tabs.add(WorkspaceTab(
      id: tabId,
      title: "New Query",
      databaseName: '',
      tableName: null,
    ));
    _activeTabId = tabId;
    notifyListeners();
  }

  /// Close an open tab
  void closeTab(String tabId) {
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
      notifyListeners();
    }
  }

  /// Change active selection to the specified tab
  void selectTab(String tabId) {
    _activeTabId = tabId;
    notifyListeners();
  }

  // ==========================================
  // Database / Schema CRUD Operations
  // ==========================================

  /// Execute CREATE DATABASE
  Future<void> createDatabase(String name) async {
    await _dbService.createDatabase(name);
    await fetchDatabases();
  }

  /// Execute RENAME DATABASE by migrating all tables
  Future<void> renameDatabase(String oldDb, String newDb) async {
    final tables = _databaseTables[oldDb] ?? [];
    await _dbService.renameDatabase(oldDb, newDb, tables);
    await fetchDatabases();
  }

  /// Execute DROP DATABASE
  Future<void> dropDatabase(String db) async {
    await _dbService.dropDatabase(db);
    await fetchDatabases();
  }

  /// Execute CREATE TABLE
  Future<void> createTable(String db, String name) async {
    await _dbService.createTable(db, name);
    await fetchDatabases();
  }

  /// Execute table cloning
  Future<void> cloneTable(String db, String table, String newName, bool duplicateData) async {
    await _dbService.cloneTable(db, table, newName, duplicateData);
    await fetchDatabases();
  }

  /// Execute TRUNCATE TABLE
  Future<void> truncateTable(String db, String table, bool disableFk) async {
    await _dbService.truncateTable(db, table, disableFk);
  }

  /// Execute DROP TABLE
  Future<void> dropTable(String db, String table, bool disableFk) async {
    await _dbService.dropTable(db, table, disableFk);
    closeTab("table_${db}_$table");
    await fetchDatabases();
  }
}
