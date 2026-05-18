import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

// Global reactive state repository for connections (saved to ~/.grid_connections.json)
final ConnectionRepository connectionRepository = ConnectionRepository();

// Legacy getter for backward-compatibility if accessed in read-only mode
List<DatabaseConnection> get globalConnections => connectionRepository.connections;

class DatabaseConnection {
  final String id;
  String name;
  String type; // 'mysql'
  String host;
  int port;
  String username;
  String password;

  DatabaseConnection({
    required this.id,
    required this.name,
    this.type = 'mysql',
    required this.host,
    required this.port,
    required this.username,
    required this.password,
  });

  String get url {
    if (password.isEmpty) {
      return "$type://$username@$host:$port";
    }
    return "$type://$username:$password@$host:$port";
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'host': host,
    'port': port,
    'username': username,
    'password': password,
  };

  factory DatabaseConnection.fromJson(Map<String, dynamic> json) {
    return DatabaseConnection(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String? ?? 'mysql',
      host: json['host'] as String,
      port: json['port'] as int,
      username: json['username'] as String,
      password: json['password'] as String? ?? '',
    );
  }
}

class ConnectionStorage {
  static File? _cachedFile;

  static File _getFile() {
    if (_cachedFile != null) return _cachedFile!;
    
    String? homePath;
    if (Platform.isWindows) {
      homePath = Platform.environment['USERPROFILE'] ?? Platform.environment['APPDATA'];
    } else if (Platform.isMacOS || Platform.isLinux) {
      homePath = Platform.environment['HOME'];
    }
    
    if (homePath != null && Directory(homePath).existsSync()) {
      _cachedFile = File('$homePath/.grid_connections.json');
    } else {
      _cachedFile = File('${Directory.systemTemp.path}/.grid_connections.json');
    }
    
    return _cachedFile!;
  }

  static Future<List<DatabaseConnection>> loadConnections() async {
    try {
      final file = _getFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(content);
        return jsonList.map((json) => DatabaseConnection.fromJson(json as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint("Error loading connections: $e");
    }
    return [];
  }

  static Future<void> saveConnections(List<DatabaseConnection> connections) async {
    try {
      final file = _getFile();
      final jsonList = connections.map((c) => c.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      debugPrint("Error saving connections: $e");
    }
  }
}

class ConnectionRepository extends ChangeNotifier {
  final List<DatabaseConnection> _connections = [];

  List<DatabaseConnection> get connections => List.unmodifiable(_connections);

  Future<void> load() async {
    final loaded = await ConnectionStorage.loadConnections();
    _connections.clear();
    _connections.addAll(loaded);
    notifyListeners();
  }

  Future<void> save() async {
    await ConnectionStorage.saveConnections(_connections);
  }

  Future<void> add(DatabaseConnection connection) async {
    _connections.add(connection);
    notifyListeners();
    await save();
  }

  Future<void> remove(DatabaseConnection connection) async {
    _connections.remove(connection);
    notifyListeners();
    await save();
  }

  Future<void> update(DatabaseConnection connection, {
    required String name,
    required String type,
    required String host,
    required int port,
    required String username,
    required String password,
  }) async {
    connection.name = name;
    connection.type = type;
    connection.host = host;
    connection.port = port;
    connection.username = username;
    connection.password = password;
    notifyListeners();
    await save();
  }
}

Future<void> loadSavedConnections() async {
  await connectionRepository.load();
}

Future<void> saveConnections() async {
  await connectionRepository.save();
}
