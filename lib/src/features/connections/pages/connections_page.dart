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
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<DatabaseConnection> get _filteredConnections {
    final list = connectionRepository.connections;
    if (_searchQuery.isEmpty) return list;
    return list
        .where(
          (c) =>
              c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              c.host.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();
  }

  void _deleteConnection(DatabaseConnection conn) async {
    await connectionRepository.remove(conn);
  }

  void _editConnection(DatabaseConnection conn) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateConnectionPage(connectionToEdit: conn),
      ),
    );
  }

  void _openConnection(DatabaseConnection conn) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => WorkspacePage(connection: conn)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: connectionRepository,
      builder: (context, child) {
        final filteredList = _filteredConnections;

        return Scaffold(
          backgroundColor: const Color(0xFFFAF8F5), // Washi Cream Canvas
          appBar: AppBar(
            backgroundColor: const Color(0xFFFAF8F5),
            elevation: 0,
            shape: const Border(
              bottom: BorderSide(color: Color(0xFFE8E5DF), width: 0.5),
            ), // Divider Clay
            title: const Text(
              "CONNECTIONS",
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2D2D2D), // Sumi Ink
                letterSpacing: 1.0,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateConnectionPage(),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF2D2D2D), // Sumi Ink
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.add, size: 16, color: Color(0xFF2D2D2D)),
                    SizedBox(width: 6),
                    Text(
                      "ADD CONNECTION",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2D2D2D),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
          body: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: "Search connections...",
                          hintStyle: const TextStyle(
                            color: Color(0xFFC4C2BC),
                            fontSize: 13,
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            size: 16,
                            color: Color(0xFF73726F),
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear,
                                    size: 14,
                                    color: Color(0xFF73726F),
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 0,
                            horizontal: 12,
                          ),
                          fillColor: const Color(0xFFF3EFE9), // Kraft Sand
                          filled: true,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: const BorderSide(
                              color: Color(0xFFE8E5DF),
                              width: 0.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: const BorderSide(
                              color: Color(0xFF7F0019),
                              width: 1.0,
                            ),
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF2D2D2D),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                      ),
                    ),
                  ),
                  Expanded(
                    child: filteredList.isEmpty
                        ? const Center(
                            child: Text(
                              "No connections found.",
                              style: TextStyle(
                                color: Color(0xFF73726F), // Wood Ash
                                fontSize: 13,
                                letterSpacing: 0.5,
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            itemCount: filteredList.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final conn = filteredList[index];
                              bool isHovered = false;

                              return StatefulBuilder(
                                builder: (context, setState) {
                                  return MouseRegion(
                                    onEnter: (_) =>
                                        setState(() => isHovered = true),
                                    onExit: (_) =>
                                        setState(() => isHovered = false),
                                    child: Card(
                                      elevation: 0,
                                      color: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                        side: const BorderSide(
                                          color: Color(0xFFE8E5DF),
                                          width: 0.5,
                                        ),
                                      ),
                                      child: InkWell(
                                        onTap: () => _openConnection(conn),
                                        splashColor: Colors.transparent,
                                        highlightColor: Colors.transparent,
                                        hoverColor: const Color(
                                          0xFFF3EFE9,
                                        ), // Kraft Sand hover card backing!
                                        borderRadius: BorderRadius.circular(4),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 40,
                                                height: 40,
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFFAF8F5,
                                                  ), // Washi Cream icon backing
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                  border: Border.all(
                                                    color: const Color(
                                                      0xFFE8E5DF,
                                                    ),
                                                    width: 0.5,
                                                  ),
                                                ),
                                                child: const Icon(
                                                  Icons
                                                      .dns_outlined, // Cylinder Icon
                                                  size: 18,
                                                  color: Color(0xFF73726F),
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      conn.name,
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Color(
                                                          0xFF2D2D2D,
                                                        ), // Sumi Ink
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      "${conn.username}@${conn.host}:${conn.port}",
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color: Color(
                                                          0xFF73726F,
                                                        ), // Wood Ash
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Opacity(
                                                opacity: isHovered ? 1.0 : 0.0,
                                                child: IgnorePointer(
                                                  ignoring: !isHovered,
                                                  child: PopupMenuButton<String>(
                                                    icon: const Icon(
                                                      Icons.more_horiz,
                                                      color: Color(0xFF73726F),
                                                    ),
                                                    color: Colors.white,
                                                    elevation: 2,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                      side: const BorderSide(
                                                        color: Color(
                                                          0xFFE8E5DF,
                                                        ),
                                                        width: 0.5,
                                                      ),
                                                    ),
                                                    onSelected: (value) {
                                                      if (value == 'edit') {
                                                        _editConnection(conn);
                                                      } else if (value ==
                                                          'delete') {
                                                        _deleteConnection(conn);
                                                      }
                                                    },
                                                    itemBuilder: (context) => [
                                                      const PopupMenuItem(
                                                        value: 'edit',
                                                        child: Text(
                                                          "Edit",
                                                          style: TextStyle(
                                                            fontSize: 13,
                                                          ),
                                                        ),
                                                      ),
                                                      const PopupMenuItem(
                                                        value: 'delete',
                                                        child: Text(
                                                          "Delete",
                                                          style: TextStyle(
                                                            fontSize: 13,
                                                            color: Color(
                                                              0xFFAC6B62,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
