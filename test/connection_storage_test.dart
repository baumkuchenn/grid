import 'package:flutter_test/flutter_test.dart';
import 'package:grid/src/features/connections/models/database_connection.dart';

void main() {
  test('DatabaseConnection JSON serialization and deserialization works correctly', () {
    final conn = DatabaseConnection(
      id: 'test_id',
      name: 'Test Connection',
      type: 'mysql',
      host: '127.0.0.1',
      port: 3306,
      username: 'root',
      password: 'password123',
    );

    final json = conn.toJson();
    expect(json['id'], 'test_id');
    expect(json['name'], 'Test Connection');
    expect(json['type'], 'mysql');
    expect(json['host'], '127.0.0.1');
    expect(json['port'], 3306);
    expect(json['username'], 'root');
    expect(json['password'], 'password123');

    final deserialized = DatabaseConnection.fromJson(json);
    expect(deserialized.id, conn.id);
    expect(deserialized.name, conn.name);
    expect(deserialized.type, conn.type);
    expect(deserialized.host, conn.host);
    expect(deserialized.port, conn.port);
    expect(deserialized.username, conn.username);
    expect(deserialized.password, conn.password);
  });
}
