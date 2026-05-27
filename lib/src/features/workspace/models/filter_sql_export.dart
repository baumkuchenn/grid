import 'table_filter.dart';
import 'sql_identifier.dart';

bool isActiveTableFilter(TableFilter filter) {
  if (filter.operator == 'is_null' || filter.operator == 'is_not_null') {
    return true;
  }
  return filter.value.isNotEmpty;
}

String buildFilteredSelectSql({
  required String databaseName,
  required String tableName,
  required Iterable<TableFilter> filters,
  String? sortColumn,
  bool sortAscending = true,
}) {
  final activeFilters = filters.where(isActiveTableFilter).toList();
  final tableRef =
      '${quoteMysqlIdentifier(databaseName)}.${quoteMysqlIdentifier(tableName)}';

  final buffer = StringBuffer('SELECT * FROM $tableRef');

  if (activeFilters.isNotEmpty) {
    final conditions = activeFilters
        .map((filter) => filter.toSql())
        .join(' AND ');
    buffer.write(' WHERE $conditions');
  }

  if (sortColumn != null) {
    final direction = sortAscending ? 'ASC' : 'DESC';
    buffer.write(' ORDER BY ${quoteMysqlIdentifier(sortColumn)} $direction');
  }

  buffer.write(';');
  return buffer.toString();
}

String buildSqlExportFileName({
  required String databaseName,
  required String tableName,
}) {
  final rawName = '${databaseName}_${tableName}_filter.sql';
  final safeName = rawName.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
  return safeName.isEmpty ? 'table_filter.sql' : safeName;
}
