import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid/src/features/workspace/models/filter_sql_export.dart';
import 'package:grid/src/features/workspace/models/table_filter.dart';
import 'package:grid/src/features/workspace/widgets/filter_sql_export_preview_dialog.dart';

void main() {
  group('buildFilteredSelectSql', () {
    test('builds a full select with one active filter', () {
      final sql = buildFilteredSelectSql(
        databaseName: 'shop',
        tableName: 'orders',
        filters: [
          TableFilter(columnName: 'status', operator: 'equals', value: 'paid'),
        ],
      );

      expect(sql, "SELECT * FROM `shop`.`orders` WHERE `status` = 'paid';");
    });

    test('joins multiple active filters with AND', () {
      final sql = buildFilteredSelectSql(
        databaseName: 'shop',
        tableName: 'orders',
        filters: [
          TableFilter(
            columnName: 'customer',
            operator: 'contains',
            value: 'Aki',
          ),
          TableFilter(
            columnName: 'total',
            operator: 'greater_equals',
            value: '100',
          ),
        ],
      );

      expect(
        sql,
        "SELECT * FROM `shop`.`orders` WHERE `customer` LIKE '%Aki%' AND `total` >= '100';",
      );
    });

    test('escapes filter values and identifiers', () {
      final sql = buildFilteredSelectSql(
        databaseName: 'client`db',
        tableName: 'order`lines',
        filters: [
          TableFilter(
            columnName: 'buyer`name',
            operator: 'equals',
            value: "O'Hara",
          ),
        ],
      );

      expect(
        sql,
        "SELECT * FROM `client``db`.`order``lines` WHERE `buyer``name` = 'O''Hara';",
      );
    });

    test('keeps null filters active without values', () {
      final sql = buildFilteredSelectSql(
        databaseName: 'shop',
        tableName: 'orders',
        filters: [
          TableFilter(columnName: 'archived_at', operator: 'is_null'),
          TableFilter(columnName: 'notes', operator: 'contains'),
        ],
      );

      expect(sql, 'SELECT * FROM `shop`.`orders` WHERE `archived_at` IS NULL;');
    });

    test('includes optional order by without pagination', () {
      final sql = buildFilteredSelectSql(
        databaseName: 'shop',
        tableName: 'orders',
        filters: [
          TableFilter(columnName: 'status', operator: 'equals', value: 'paid'),
        ],
        sortColumn: 'created_at',
        sortAscending: false,
      );

      expect(
        sql,
        "SELECT * FROM `shop`.`orders` WHERE `status` = 'paid' ORDER BY `created_at` DESC;",
      );
      expect(sql, isNot(contains('LIMIT')));
      expect(sql, isNot(contains('OFFSET')));
    });
  });

  testWidgets('filter SQL export preview shows the generated SQL', (
    tester,
  ) async {
    const sql = "SELECT * FROM `shop`.`orders` WHERE `status` = 'paid';";

    await tester.pumpWidget(
      MaterialApp(
        home: FilterSqlExportPreviewDialog(
          sql: sql,
          onExport: () async => '/tmp/orders_filter.sql',
        ),
      ),
    );

    expect(find.text('EXPORT FILTER SQL'), findsOneWidget);
    expect(find.text(sql), findsOneWidget);
    expect(find.text('CANCEL'), findsOneWidget);
    expect(find.text('EXPORT'), findsOneWidget);
  });

  testWidgets('filter SQL export preview stays open and shows success', (
    tester,
  ) async {
    const sql = "SELECT * FROM `shop`.`orders` WHERE `status` = 'paid';";

    await tester.pumpWidget(
      MaterialApp(
        home: FilterSqlExportPreviewDialog(
          sql: sql,
          onExport: () async => '/tmp/orders_filter.sql',
        ),
      ),
    );

    await tester.tap(find.text('EXPORT'));
    await tester.pumpAndSettle();

    expect(find.text('EXPORT FILTER SQL'), findsOneWidget);
    expect(
      find.textContaining('Exported to /tmp/orders_filter.sql'),
      findsOneWidget,
    );
  });

  testWidgets('filter SQL export preview stays open and shows errors', (
    tester,
  ) async {
    const sql = "SELECT * FROM `shop`.`orders` WHERE `status` = 'paid';";

    await tester.pumpWidget(
      MaterialApp(
        home: FilterSqlExportPreviewDialog(
          sql: sql,
          onExport: () async => throw Exception('disk is full'),
        ),
      ),
    );

    await tester.tap(find.text('EXPORT'));
    await tester.pumpAndSettle();

    expect(find.text('EXPORT FILTER SQL'), findsOneWidget);
    expect(find.textContaining('Export failed:'), findsOneWidget);
  });
}
