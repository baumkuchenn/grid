import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid/src/features/workspace/widgets/workspace_sidebar.dart';

void main() {
  Widget buildSidebar({required FocusNode focusNode}) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 360,
          height: 640,
          child: WorkspaceSidebar(
            isLoadingDatabases: false,
            errorMessage: '',
            databases: const ['analytics', 'partner_data'],
            databaseTables: const {
              'analytics': ['partner_ginee_orders', 'customer_profiles'],
              'partner_data': ['all_orders'],
            },
            onRetryDatabases: () {},
            onOpenQueryTab: () {},
            onOpenTableTab: (db, table) {},
            onCreateDatabase: () {},
            onRenameDatabase: (db) {},
            onDropDatabase: (db) {},
            onCreateTable: (db) {},
            onCloneTable: (db, table) {},
            onTruncateTable: (db, table) {},
            onDropTable: (db, table) {},
            searchFocusNode: focusNode,
          ),
        ),
      ),
    );
  }

  testWidgets('sidebar search matches schema names across separators', (
    tester,
  ) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(buildSidebar(focusNode: focusNode));

    Future<void> search(String query) async {
      await tester.enterText(find.byType(TextField), query);
      await tester.pumpAndSettle();
    }

    await search('partner ginee order');
    expect(find.text('partner_ginee_orders'), findsOneWidget);
    expect(find.text('customer_profiles'), findsNothing);

    await search('gineeorder');
    expect(find.text('partner_ginee_orders'), findsOneWidget);
    expect(find.text('customer_profiles'), findsNothing);

    await search('partner data');
    expect(find.text('partner_data'), findsOneWidget);
    expect(find.text('all_orders'), findsOneWidget);

    await search('totally unrelated');
    expect(find.text('analytics'), findsNothing);
    expect(find.text('partner_data'), findsNothing);
    expect(find.text('partner_ginee_orders'), findsNothing);
  });
}
