import 'package:flutter_test/flutter_test.dart';
import 'package:grid/src/features/workspace/models/table_filter.dart';
import 'package:grid/src/features/workspace/models/table_page_sql.dart';

void main() {
  group('buildTablePageSql', () {
    test('builds paged data and count queries without filters', () {
      final sql = buildTablePageSql(
        tableName: 'orders',
        filters: const [],
        sortColumn: null,
        sortAscending: true,
        limit: 50,
        offset: 100,
      );

      expect(sql.dataQuery, 'SELECT * FROM `orders` LIMIT 50 OFFSET 100');
      expect(sql.countQuery, 'SELECT COUNT(*) FROM `orders`');
    });

    test('applies active filters to both queries and sort only to data', () {
      final sql = buildTablePageSql(
        tableName: 'orders',
        filters: [
          TableFilter(columnName: 'status', operator: 'equals', value: 'paid'),
          TableFilter(columnName: 'notes', operator: 'contains'),
          TableFilter(columnName: 'archived_at', operator: 'is_null'),
        ],
        sortColumn: 'created_at',
        sortAscending: false,
        limit: 50,
        offset: 0,
      );

      expect(
        sql.dataQuery,
        "SELECT * FROM `orders` WHERE `status` = 'paid' AND `archived_at` IS NULL ORDER BY `created_at` DESC LIMIT 50 OFFSET 0",
      );
      expect(
        sql.countQuery,
        "SELECT COUNT(*) FROM `orders` WHERE `status` = 'paid' AND `archived_at` IS NULL",
      );
    });

    test('escapes identifiers and filter values', () {
      final sql = buildTablePageSql(
        tableName: 'order`lines',
        filters: [
          TableFilter(
            columnName: 'buyer`name',
            operator: 'equals',
            value: "O'Hara",
          ),
        ],
        sortColumn: 'total`gross',
        sortAscending: true,
        limit: 25,
        offset: 50,
      );

      expect(
        sql.dataQuery,
        "SELECT * FROM `order``lines` WHERE `buyer``name` = 'O''Hara' ORDER BY `total``gross` ASC LIMIT 25 OFFSET 50",
      );
      expect(
        sql.countQuery,
        "SELECT COUNT(*) FROM `order``lines` WHERE `buyer``name` = 'O''Hara'",
      );
    });
  });
}
