import 'package:flutter/material.dart';
import '../../../rust/api/simple.dart';
import 'inline_edit_cell.dart';

Widget buildDataGrid(
  BuildContext context, 
  QueryResult result, {
  Future<void> Function(String column, String oldValue, String newValue, Map<String, String> rowMap)? onSave,
  Set<int>? selectedIndices,
  Function(int, bool)? onSelectChanged,
  Function(bool?)? onSelectAll,
}) {
  if (result.columns.isEmpty) {
    return const Center(child: Text("0 rows returned.", style: TextStyle(color: Color(0xFF999999))));
  }

  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: DataTable(
            showCheckboxColumn: onSelectChanged != null,
            onSelectAll: onSelectAll,
            horizontalMargin: 16,
            columnSpacing: 28,
            dataRowMinHeight: 32,
            dataRowMaxHeight: 36,
            headingRowHeight: 38,
            headingRowColor: WidgetStateProperty.resolveWith((states) => const Color(0xFFF3EFE9)), // Kraft Sand Header
            dataRowColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const Color(0xFFFAF2F3); // Soft unbleached Muji Red Tint
              }
              return Colors.white;
            }),
            dividerThickness: 0.5,
            border: const TableBorder(
              horizontalInside: BorderSide(color: Color(0xFFE8E5DF), width: 0.5), // Divider Clay
              bottom: BorderSide(color: Color(0xFFE8E5DF), width: 0.5),
            ),
            columns: result.columns.map((col) => DataColumn(
              label: Text(
                col.toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 10, color: Color(0xFF73726F), letterSpacing: 1.0, fontFamily: 'monospace'),
              )
            )).toList(),
            rows: result.rows.asMap().entries.map((rowEntry) {
              final rowIndex = rowEntry.key;
              final row = rowEntry.value;
              Map<String, String>? rowMap;
              
              return DataRow(
                selected: selectedIndices?.contains(rowIndex) ?? false,
                onSelectChanged: onSelectChanged == null ? null : (selected) => onSelectChanged(rowIndex, selected ?? false),
                cells: row.asMap().entries.map((entry) {
                  final colIndex = entry.key;
                  final cell = entry.value;
                  final colName = result.columns[colIndex];
                  
                  final isNull = cell == 'NULL';
                  final isEmpty = cell.isEmpty;
                  final isSpecial = isNull || isEmpty;
                  
                  String displayValue = cell;
                  if (isEmpty) displayValue = 'EMPTY';

                  return DataCell(
                    InlineEditCell(
                      columnName: colName,
                      initialValue: cell,
                      displayValue: displayValue,
                      isSpecial: isSpecial,
                      onSave: onSave == null ? null : (newValue) async {
                        rowMap ??= {
                          for (var i = 0; i < result.columns.length; i++) result.columns[i]: row[i]
                        };
                        await onSave(colName, cell, newValue, rowMap!);
                      },
                    ),
                  );
              }).toList(),
            );
          }).toList(),
        ),
      ),
    ),
  );
}
