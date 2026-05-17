import 'package:flutter/material.dart';
import 'package:grid/src/rust/api/simple.dart';
import '../models/database_connection.dart';
import 'database_explorer_page.dart';

class ConnectionDatabasesPage extends StatefulWidget {
  final DatabaseConnection connection;

  const ConnectionDatabasesPage({super.key, required this.connection});

  @override
  State<ConnectionDatabasesPage> createState() => _ConnectionDatabasesPageState();
}

class _ConnectionDatabasesPageState extends State<ConnectionDatabasesPage> {
  List<String> _databases = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchDatabases();
  }

  Future<void> _fetchDatabases() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final dbs = await getMysqlDatabases(url: widget.connection.url);
      setState(() {
        _databases = dbs;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.connection.name.toUpperCase()),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF7F0019), strokeWidth: 2),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Color(0xFFD32F2F)),
              const SizedBox(height: 16),
              const Text(
                "Connection Failed",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF333333)),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: _fetchDatabases,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF333333),
                  side: const BorderSide(color: Color(0xFFEAEAEA)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                child: const Text("RETRY"),
              ),
            ],
          ),
        ),
      );
    }

    if (_databases.isEmpty) {
      return const Center(
        child: Text("No databases found.", style: TextStyle(color: Color(0xFF999999))),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Text(
            "DATABASES (${_databases.length})",
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF888888),
              letterSpacing: 0.5,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            itemCount: _databases.length,
            separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFEAEAEA)),
            itemBuilder: (context, index) {
              final db = _databases[index];
              return Container(
                color: Colors.white,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: const Icon(Icons.data_usage, size: 20, color: Color(0xFF888888)),
                  title: Text(
                    db,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF333333)),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20, color: Color(0xFFCCCCCC)),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DatabaseExplorerPage(
                          connection: widget.connection,
                          databaseName: db,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
