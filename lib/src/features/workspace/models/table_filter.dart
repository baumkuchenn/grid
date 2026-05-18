class TableFilter {
  String columnName;
  String operator;
  String value;

  TableFilter({
    required this.columnName,
    this.operator = 'contains',
    this.value = '',
  });

  String toSql() {
    final escapedValue = value.replaceAll("'", "''");
    switch (operator) {
      case 'equals':
        return '`$columnName` = \'$escapedValue\'';
      case 'not_equals':
        return '`$columnName` != \'$escapedValue\'';
      case 'contains':
        return '`$columnName` LIKE \'%$escapedValue%\'';
      case 'not_contains':
        return '`$columnName` NOT LIKE \'%$escapedValue%\'';
      case 'starts_with':
        return '`$columnName` LIKE \'$escapedValue%\'';
      case 'ends_with':
        return '`$columnName` LIKE \'%$escapedValue\'';
      case 'greater_than':
        return '`$columnName` > \'$escapedValue\'';
      case 'less_than':
        return '`$columnName` < \'$escapedValue\'';
      case 'greater_equals':
        return '`$columnName` >= \'$escapedValue\'';
      case 'less_equals':
        return '`$columnName` <= \'$escapedValue\'';
      case 'is_null':
        return '`$columnName` IS NULL';
      case 'is_not_null':
        return '`$columnName` IS NOT NULL';
      default:
        return '1 = 1';
    }
  }

  static const List<Map<String, String>> operators = [
    {'value': 'contains', 'label': 'contains'},
    {'value': 'not_contains', 'label': 'does not contain'},
    {'value': 'equals', 'label': 'equals'},
    {'value': 'not_equals', 'label': 'does not equal'},
    {'value': 'starts_with', 'label': 'starts with'},
    {'value': 'ends_with', 'label': 'ends with'},
    {'value': 'greater_than', 'label': '>'},
    {'value': 'less_than', 'label': '<'},
    {'value': 'greater_equals', 'label': '>='},
    {'value': 'less_equals', 'label': '<='},
    {'value': 'is_null', 'label': 'is empty'},
    {'value': 'is_not_null', 'label': 'is not empty'},
  ];
}
