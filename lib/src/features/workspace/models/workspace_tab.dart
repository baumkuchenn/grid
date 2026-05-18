class WorkspaceTab {
  final String id;
  final String title;
  final String databaseName;
  final String? tableName; // null if it's a query tab

  WorkspaceTab({
    required this.id,
    required this.title,
    required this.databaseName,
    this.tableName,
  });
}
