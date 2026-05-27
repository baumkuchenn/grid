import 'sql_identifier.dart';

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
    final quotedColumn = quoteMysqlIdentifier(columnName);
    switch (operator) {
      case 'equals':
        return '$quotedColumn = \'$escapedValue\'';
      case 'not_equals':
        return '$quotedColumn != \'$escapedValue\'';
      case 'contains':
        return '$quotedColumn LIKE \'%$escapedValue%\'';
      case 'not_contains':
        return '$quotedColumn NOT LIKE \'%$escapedValue%\'';
      case 'starts_with':
        return '$quotedColumn LIKE \'$escapedValue%\'';
      case 'ends_with':
        return '$quotedColumn LIKE \'%$escapedValue\'';
      case 'greater_than':
        return '$quotedColumn > \'$escapedValue\'';
      case 'less_than':
        return '$quotedColumn < \'$escapedValue\'';
      case 'greater_equals':
        return '$quotedColumn >= \'$escapedValue\'';
      case 'less_equals':
        return '$quotedColumn <= \'$escapedValue\'';
      case 'is_null':
        return '$quotedColumn IS NULL';
      case 'is_not_null':
        return '$quotedColumn IS NOT NULL';
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
