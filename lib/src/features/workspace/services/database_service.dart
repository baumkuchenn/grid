import '../../../rust/api/simple.dart';

/// Service class to encapsulate database/schema actions and decouple SQL composition 
/// and Rust Bridge execution from Flutter presentation components.
class DatabaseService {
  final String url;

  const DatabaseService({required this.url});

  /// Check whether the database server is alive/reachable
  Future<bool> checkConnection() async {
    try {
      await runMysqlQuery(url: url, database: '', query: 'SELECT 1');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Retrieve the list of databases from the server
  Future<List<String>> fetchDatabases() async {
    return getMysqlDatabases(url: url);
  }

  /// Retrieve the list of tables for a given database
  Future<List<String>> fetchTables(String database) async {
    return getMysqlTables(url: url, database: database);
  }

  /// Create a database with the specified name
  Future<void> createDatabase(String name) async {
    await executeMysqlAction(
      url: url,
      database: '',
      query: 'CREATE DATABASE `$name`',
      disableFk: false,
    );
  }

  /// Rename a database by creating the new database, renaming tables, and dropping the old one
  Future<void> renameDatabase(String oldDb, String newDb, List<String> tables) async {
    await executeMysqlAction(
      url: url,
      database: '',
      query: 'CREATE DATABASE `$newDb`',
      disableFk: false,
    );
    for (var table in tables) {
      await executeMysqlAction(
        url: url,
        database: '',
        query: 'RENAME TABLE `$oldDb`.`$table` TO `$newDb`.`$table`',
        disableFk: false,
      );
    }
    await executeMysqlAction(
      url: url,
      database: '',
      query: 'DROP DATABASE `$oldDb`',
      disableFk: false,
    );
  }

  /// Drop/delete a database
  Future<void> dropDatabase(String db) async {
    await executeMysqlAction(
      url: url,
      database: '',
      query: 'DROP DATABASE `$db`',
      disableFk: false,
    );
  }

  /// Create a basic table in the specified database with an auto-incrementing ID column
  Future<void> createTable(String db, String name) async {
    await executeMysqlAction(
      url: url,
      database: db,
      query: 'CREATE TABLE `$name` (id INT PRIMARY KEY AUTO_INCREMENT)',
      disableFk: false,
    );
  }

  /// Clone a table's structure (and optionally its data)
  Future<void> cloneTable(String db, String table, String newName, bool duplicateData) async {
    await executeMysqlAction(
      url: url,
      database: db,
      query: 'CREATE TABLE `$newName` LIKE `$table`',
      disableFk: false,
    );
    if (duplicateData) {
      await executeMysqlAction(
        url: url,
        database: db,
        query: 'INSERT INTO `$newName` SELECT * FROM `$table`',
        disableFk: false,
      );
    }
  }

  /// Truncate (wipe data from) a table
  Future<void> truncateTable(String db, String table, bool disableFk) async {
    await executeMysqlAction(
      url: url,
      database: db,
      query: 'TRUNCATE TABLE `$table`',
      disableFk: disableFk,
    );
  }

  /// Drop/delete a table
  Future<void> dropTable(String db, String table, bool disableFk) async {
    await executeMysqlAction(
      url: url,
      database: db,
      query: 'DROP TABLE `$table`',
      disableFk: disableFk,
    );
  }
}
