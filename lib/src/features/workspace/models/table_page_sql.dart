import 'filter_sql_export.dart';
import 'sql_identifier.dart';
import 'table_filter.dart';

class TablePageSql {
  final String dataQuery;
  final String countQuery;

  const TablePageSql({required this.dataQuery, required this.countQuery});
}

/// Builds SQL for the paged table-browser path only.
///
/// Custom SQL execution intentionally stays on the full-result query path until
/// a future UX explicitly adds paging or result limits for ad hoc queries.
TablePageSql buildTablePageSql({
  required String tableName,
  required Iterable<TableFilter> filters,
  required String? sortColumn,
  required bool sortAscending,
  required int limit,
  required int offset,
}) {
  final tableRef = quoteMysqlIdentifier(tableName);
  final whereClause = buildTablePageWhereClause(filters);
  final orderByClause = buildTablePageOrderByClause(
    sortColumn: sortColumn,
    sortAscending: sortAscending,
  );

  return TablePageSql(
    dataQuery:
        'SELECT * FROM $tableRef$whereClause$orderByClause LIMIT $limit OFFSET $offset',
    countQuery: 'SELECT COUNT(*) FROM $tableRef$whereClause',
  );
}

String buildTablePageWhereClause(Iterable<TableFilter> filters) {
  final activeFilters = filters.where(isActiveTableFilter).toList();
  if (activeFilters.isEmpty) return '';

  final conditions = activeFilters
      .map((filter) => filter.toSql())
      .join(' AND ');
  return ' WHERE $conditions';
}

String buildTablePageOrderByClause({
  required String? sortColumn,
  required bool sortAscending,
}) {
  if (sortColumn == null) return '';

  final direction = sortAscending ? 'ASC' : 'DESC';
  return ' ORDER BY ${quoteMysqlIdentifier(sortColumn)} $direction';
}
