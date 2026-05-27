import 'package:flutter_test/flutter_test.dart';
import 'package:grid/src/features/workspace/controllers/workspace_controller.dart';

void main() {
  group('immutableDatabaseTablesSnapshot', () {
    test('preserves typed immutable map and nested lists', () {
      final source = <String, List<String>>{
        'analytics': <String>['orders', 'profiles'],
      };

      final snapshot = immutableDatabaseTablesSnapshot(source);
      final tables = snapshot['analytics']!;

      expect(snapshot, isA<Map<String, List<String>>>());
      expect(tables, isA<List<String>>());
      expect(() => snapshot['new_db'] = <String>[], throwsUnsupportedError);
      expect(() => tables.add('events'), throwsUnsupportedError);

      source['analytics']!.add('events');
      expect(snapshot['analytics'], <String>['orders', 'profiles']);
    });
  });
}
