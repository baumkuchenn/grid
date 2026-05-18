import 'package:flutter/material.dart';

class WorkspaceSidebar extends StatefulWidget {
  final bool isLoadingDatabases;
  final String errorMessage;
  final List<String> databases;
  final Map<String, List<String>> databaseTables;
  final VoidCallback onRetryDatabases;
  final VoidCallback onOpenQueryTab;
  final Function(String db, String table) onOpenTableTab;
  
  // Database actions
  final VoidCallback onCreateDatabase;
  final Function(String db) onRenameDatabase;
  final Function(String db) onDropDatabase;
  final Function(String db) onCreateTable;
  
  // Table actions
  final Function(String db, String table) onCloneTable;
  final Function(String db, String table) onTruncateTable;
  final Function(String db, String table) onDropTable;
  
  // External focus node to support keyboard shortcuts
  final FocusNode searchFocusNode;

  const WorkspaceSidebar({
    super.key,
    required this.isLoadingDatabases,
    required this.errorMessage,
    required this.databases,
    required this.databaseTables,
    required this.onRetryDatabases,
    required this.onOpenQueryTab,
    required this.onOpenTableTab,
    required this.onCreateDatabase,
    required this.onRenameDatabase,
    required this.onDropDatabase,
    required this.onCreateTable,
    required this.onCloneTable,
    required this.onTruncateTable,
    required this.onDropTable,
    required this.searchFocusNode,
  });

  @override
  State<WorkspaceSidebar> createState() => _WorkspaceSidebarState();
}

class _WorkspaceSidebarState extends State<WorkspaceSidebar> {
  final TextEditingController _searchController = TextEditingController();
  String _unifiedSearchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoadingDatabases) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF7F0019), strokeWidth: 2));
    }

    if (widget.errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Color(0xFFAC6B62), size: 32),
              const SizedBox(height: 12),
              Text(widget.errorMessage, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Color(0xFF73726F))),
              const SizedBox(height: 12),
              TextButton(onPressed: widget.onRetryDatabases, child: const Text("RETRY"))
            ],
          ),
        ),
      );
    }

    String q = _unifiedSearchQuery.trim().toLowerCase();
    List<String> filteredDatabases = widget.databases.where((db) {
      if (q.isEmpty) return true;
      final dbMatches = db.toLowerCase().contains(q);
      final tables = widget.databaseTables[db] ?? [];
      final hasMatchingTable = tables.any((t) => t.toLowerCase().contains(q));
      return dbMatches || hasMatchingTable;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Beautiful minimal Search Bar in Washi Cream
              SizedBox(
                height: 36,
                child: TextField(
                  controller: _searchController,
                  focusNode: widget.searchFocusNode,
                  decoration: InputDecoration(
                    hintText: "Search databases or tables...",
                    hintStyle: const TextStyle(color: Color(0xFFC4C2BC), fontSize: 13),
                    prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF73726F)),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 14, color: Color(0xFF73726F)),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _unifiedSearchQuery = '';
                              });
                            },
                          )
                        : UnconstrainedBox(
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8E5DF), // Divider Clay
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                "/",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF73726F), // Wood Ash
                                ),
                              ),
                            ),
                          ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                    fillColor: const Color(0xFFFAF8F5), // Washi Cream
                    filled: true,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: Color(0xFFE8E5DF), width: 0.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: Color(0xFF7F0019), width: 1),
                    ),
                  ),
                  style: const TextStyle(fontSize: 13, color: Color(0xFF2D2D2D)),
                  onChanged: (val) {
                    setState(() {
                      _unifiedSearchQuery = val;
                    });
                  },
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: widget.onOpenQueryTab,
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                hoverColor: const Color(0xFFFAF8F5), // Washi Cream
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.terminal_outlined, size: 16, color: Color(0xFF73726F)),
                      const SizedBox(width: 12),
                      const Text(
                        "New Query", 
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2D2D2D), letterSpacing: 0.2),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "DATABASES",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF73726F), // Wood Ash
                      letterSpacing: 1.0,
                    ),
                  ),
                  InkWell(
                    onTap: widget.onCreateDatabase,
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: const Padding(
                      padding: EdgeInsets.all(4.0),
                      child: Icon(Icons.add, size: 16, color: Color(0xFF73726F)),
                    ),
                  )
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
              hoverColor: const Color(0xFFFAF8F5), // Washi Cream Hover
            ),
            child: ListView.builder(
              itemCount: filteredDatabases.length,
              itemBuilder: (context, index) {
                final db = filteredDatabases[index];
                final allTables = widget.databaseTables[db] ?? [];
                
                final tables = allTables.where((t) {
                  if (q.isEmpty) return true;
                  return db.toLowerCase().contains(q) || t.toLowerCase().contains(q);
                }).toList();
  
                bool isDbHovered = false;
                return ExpansionTile(
                  key: PageStorageKey('db_${db}_${q.isNotEmpty}'),
                  initiallyExpanded: q.isNotEmpty,
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: StatefulBuilder(
                    builder: (context, setState) {
                      return MouseRegion(
                        onEnter: (_) => setState(() => isDbHovered = true),
                        onExit: (_) => setState(() => isDbHovered = false),
                        child: Row(
                          children: [
                            const Icon(Icons.dns_outlined, size: 16, color: Color(0xFF73726F)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                db, 
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2D2D2D)),
                              ),
                            ),
                            Opacity(
                              opacity: isDbHovered ? 1.0 : 0.0,
                              child: IgnorePointer(
                                ignoring: !isDbHovered,
                                child: PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, size: 16, color: Color(0xFF73726F)),
                                  padding: EdgeInsets.zero,
                                  onSelected: (val) {
                                    if (val == 'rename') widget.onRenameDatabase(db);
                                    if (val == 'drop') widget.onDropDatabase(db);
                                    if (val == 'create_table') widget.onCreateTable(db);
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(value: 'create_table', child: Text("Create Table", style: TextStyle(fontSize: 13))),
                                    const PopupMenuItem(value: 'rename', child: Text("Rename Database", style: TextStyle(fontSize: 13))),
                                    const PopupMenuItem(value: 'drop', child: Text("Drop Database", style: TextStyle(fontSize: 13, color: Color(0xFFAC6B62)))),
                                  ]
                                ),
                              ),
                            )
                          ],
                        ),
                      );
                    }
                  ),
                  iconColor: const Color(0xFF2D2D2D),
                  collapsedIconColor: const Color(0xFF73726F),
                  shape: const Border(),
                  childrenPadding: EdgeInsets.zero,
                  children: [
                    // List of tables
                    ...tables.map((table) {
                      bool isHovered = false;
                      return StatefulBuilder(
                        builder: (context, setState) {
                          return MouseRegion(
                            onEnter: (_) => setState(() => isHovered = true),
                            onExit: (_) => setState(() => isHovered = false),
                            child: InkWell(
                              key: ValueKey('table_btn_${db}_$table'),
                              onTap: () => widget.onOpenTableTab(db, table),
                              splashColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                              hoverColor: const Color(0xFFFAF8F5), // Washi Cream
                              child: Container(
                                padding: const EdgeInsets.only(left: 48, right: 16, top: 4, bottom: 4),
                                color: isHovered ? const Color(0xFFFAF8F5) : Colors.transparent,
                                child: Row(
                                  children: [
                                    const Icon(Icons.table_chart_outlined, size: 16, color: Color(0xFF73726F)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        table, 
                                        style: const TextStyle(fontSize: 13, color: Color(0xFF2D2D2D), height: 1.2), 
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Opacity(
                                      opacity: isHovered ? 1.0 : 0.0,
                                      child: IgnorePointer(
                                        ignoring: !isHovered,
                                        child: PopupMenuButton<String>(
                                          icon: const Icon(Icons.more_horiz, size: 16, color: Color(0xFF73726F)),
                                          padding: EdgeInsets.zero,
                                          onSelected: (val) {
                                            if (val == 'clone') widget.onCloneTable(db, table);
                                            if (val == 'truncate') widget.onTruncateTable(db, table);
                                            if (val == 'drop') widget.onDropTable(db, table);
                                          },
                                          itemBuilder: (context) => [
                                            const PopupMenuItem(value: 'clone', child: Text("Clone Table", style: TextStyle(fontSize: 13))),
                                            const PopupMenuItem(value: 'truncate', child: Text("Truncate Data", style: TextStyle(fontSize: 13))),
                                            const PopupMenuItem(value: 'drop', child: Text("Drop Table", style: TextStyle(fontSize: 13, color: Color(0xFFAC6B62)))),
                                          ]
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            ),
                          );
                        }
                      );
                    }),
                    // Show message if no tables match
                    if (tables.isEmpty && allTables.isNotEmpty)
                      Padding(
                        key: ValueKey('no_tables_$db'),
                        padding: const EdgeInsets.fromLTRB(48, 8, 16, 16),
                        child: const Text("No tables match filter.", style: TextStyle(fontSize: 12, color: Color(0xFFC4C2BC))),
                      )
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
