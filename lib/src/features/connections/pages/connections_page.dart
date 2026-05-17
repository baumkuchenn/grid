import 'package:flutter/material.dart';
import '../models/database_connection.dart';
import 'create_connection_page.dart';
import '../../workspace/pages/workspace_page.dart';

class ConnectionsPage extends StatefulWidget {
  const ConnectionsPage({super.key});

  @override
  State<ConnectionsPage> createState() => _ConnectionsPageState();
}

class _ConnectionsPageState extends State<ConnectionsPage> {
  String _searchQuery = '';

  List<DatabaseConnection> get _filteredConnections {
    if (_searchQuery.isEmpty) return globalConnections;
    return globalConnections
        .where((c) => c.name.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                      c.host.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  void _deleteConnection(DatabaseConnection conn) async {
    setState(() {
      globalConnections.remove(conn);
    });
    await saveConnections();
  }

  void _editConnection(DatabaseConnection conn) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateConnectionPage(connectionToEdit: conn),
      ),
    );
    setState(() {}); // refresh after edit
  }

  void _openConnection(DatabaseConnection conn) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WorkspacePage(connection: conn),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("CONNECTIONS"),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search connections...",
                prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF999999)),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          Expanded(
            child: _filteredConnections.isEmpty
                ? const Center(
                    child: Text(
                      "No connections found.",
                      style: TextStyle(color: Color(0xFF999999), fontSize: 14),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: _filteredConnections.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final conn = _filteredConnections[index];
                      return Card(
                        child: InkWell(
                          onTap: () => _openConnection(conn),
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0F0F0),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Icon(Icons.storage, size: 20, color: Color(0xFF7F0019)),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        conn.name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF333333),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "${conn.username}@${conn.host}:${conn.port}",
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF888888),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_horiz, color: Color(0xFF999999)),
                                  color: Colors.white,
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _editConnection(conn);
                                    } else if (value == 'delete') {
                                      _deleteConnection(conn);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Text("Edit", style: TextStyle(fontSize: 14)),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text("Delete", style: TextStyle(fontSize: 14, color: Colors.redAccent)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateConnectionPage()),
          );
          setState(() {}); // refresh on return
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
