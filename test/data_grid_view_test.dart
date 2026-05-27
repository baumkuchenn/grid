import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid/src/features/workspace/widgets/data_grid_view.dart';
import 'package:grid/src/rust/api/simple.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

void main() {
  testWidgets(
    'buildDataGrid calls sort callback when a sortable header is tapped',
    (tester) async {
      int? sortedColumnIndex;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => buildDataGrid(
                context,
                const QueryResult(
                  columns: ['id', 'name'],
                  rows: [
                    ['1', 'Aki'],
                    ['2', 'Yui'],
                  ],
                ),
                sortColumnIndex: 0,
                sortAscending: true,
                onSortColumn: (columnIndex) {
                  sortedColumnIndex = columnIndex;
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('ID'));
      await tester.pump();

      expect(sortedColumnIndex, 0);
    },
  );

  testWidgets('buildDataGrid shows the empty result state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => buildDataGrid(
              context,
              const QueryResult(columns: [], rows: []),
            ),
          ),
        ),
      ),
    );

    expect(find.text('0 rows returned.'), findsOneWidget);
  });

  testWidgets('buildDataGrid wires row selection and select all', (
    tester,
  ) async {
    int? selectedIndex;
    bool? selectedValue;
    bool? selectAllValue;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => buildDataGrid(
              context,
              const QueryResult(
                columns: ['id', 'name'],
                rows: [
                  ['1', 'Aki'],
                  ['2', 'Yui'],
                ],
              ),
              selectedIndices: const {},
              onSelectChanged: (index, selected) {
                selectedIndex = index;
                selectedValue = selected;
              },
              onSelectAll: (selected) {
                selectAllValue = selected;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    expect(selectAllValue, true);

    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pump();
    expect(selectedIndex, 0);
    expect(selectedValue, true);
  });

  testWidgets('buildDataGrid calls inline edit save callback', (tester) async {
    String? savedColumn;
    String? savedOldValue;
    String? savedNewValue;
    Map<String, String>? savedRow;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => buildDataGrid(
              context,
              const QueryResult(
                columns: ['id', 'name'],
                rows: [
                  ['1', 'Aki'],
                ],
              ),
              onSave: (column, oldValue, newValue, rowMap) async {
                savedColumn = column;
                savedOldValue = oldValue;
                savedNewValue = newValue;
                savedRow = rowMap;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Aki'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Aya');
    await tester.tap(find.text('SAVE VALUE'));
    await tester.pumpAndSettle();

    expect(savedColumn, 'name');
    expect(savedOldValue, 'Aki');
    expect(savedNewValue, 'Aya');
    expect(savedRow, {'id': '1', 'name': 'Aki'});
  });

  testWidgets('buildDataGrid scrolls large row and column sets', (
    tester,
  ) async {
    final columns = List<String>.generate(20, (index) => 'c$index');
    final rows = List<List<String>>.generate(
      80,
      (row) => List<String>.generate(20, (column) => 'r${row}c$column'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 260,
            child: Builder(
              builder: (context) => buildDataGrid(
                context,
                QueryResult(columns: columns, rows: rows),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('r0c0'), findsOneWidget);
    expect(find.text('r30c8'), findsNothing);

    await tester.drag(find.byType(TableView), const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(TableView), const Offset(-700, 0));
    await tester.pumpAndSettle();

    expect(find.text('r30c8'), findsOneWidget);
  });
}
