import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

// Global state for connections (saved to ~/.grid_connections.json)
final List<DatabaseConnection> globalConnections = [];

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
  static File _getFile() {
    String? homePath;
    if (Platform.isWindows) {
      homePath = Platform.environment['USERPROFILE'] ?? Platform.environment['APPDATA'];
    } else if (Platform.isMacOS || Platform.isLinux) {
      homePath = Platform.environment['HOME'];
    }
    
    if (homePath != null && Directory(homePath).existsSync()) {
      return File('$homePath/.grid_connections.json');
    }
    
    // Fallback if home directory isn't found/accessible
    return File('${Directory.systemTemp.path}/.grid_connections.json');
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

Future<void> loadSavedConnections() async {
  final loaded = await ConnectionStorage.loadConnections();
  globalConnections.clear();
  globalConnections.addAll(loaded);
}

Future<void> saveConnections() async {
  await ConnectionStorage.saveConnections(globalConnections);
}
