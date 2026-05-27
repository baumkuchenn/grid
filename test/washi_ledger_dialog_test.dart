import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid/src/features/workspace/widgets/washi_ledger_dialog.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

void main() {
  testWidgets('WashiLedgerDialog renders preview and copy controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WashiLedgerDialog(
            columns: const ['id', 'name'],
            rows: const [
              ['1', 'Aki'],
              ['2', 'Yui'],
            ],
            title: 'Query Results',
          ),
        ),
      ),
    );

    expect(find.text('QUERY RESULTS'), findsOneWidget);
    expect(find.text('2 LINES'), findsOneWidget);
    expect(find.text('2 VALS'), findsOneWidget);
    expect(find.byType(TableView), findsOneWidget);
    expect(find.text('Aki'), findsOneWidget);
    expect(find.text('COPY CSV'), findsOneWidget);
    expect(find.text('COPY MARKDOWN'), findsOneWidget);
    expect(find.text('DONE'), findsOneWidget);

    await tester.tap(find.text('COPY CSV'));
    await tester.pump();

    expect(find.text('Copied successfully as CSV!'), findsOneWidget);
  });
}
