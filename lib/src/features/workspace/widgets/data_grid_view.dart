import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

import '../../../rust/api/simple.dart';
import 'inline_edit_cell.dart';

const _gridHeaderColor = Color(0xFFF3EFE9);
const _gridSelectedColor = Color(0xFFFAF2F3);
const _gridDividerColor = Color(0xFFE8E5DF);
const _gridMutedTextColor = Color(0xFF73726F);
const _gridSelectionColumnWidth = 48.0;
const _gridMinColumnWidth = 96.0;
const _gridMaxColumnWidth = 280.0;
const _gridHeaderHeight = 38.0;
const _gridRowHeight = 36.0;

Widget buildDataGrid(
  BuildContext context,
  QueryResult result, {
  Future<void> Function(
    String column,
    String oldValue,
    String newValue,
    Map<String, String> rowMap,
  )?
  onSave,
  Set<int>? selectedIndices,
  Function(int, bool)? onSelectChanged,
  Function(bool?)? onSelectAll,
  int? sortColumnIndex,
  bool sortAscending = true,
  Function(int columnIndex)? onSortColumn,
}) {
  if (result.columns.isEmpty) {
    return const Center(
      child: Text(
        "0 rows returned.",
        style: TextStyle(color: Color(0xFF999999)),
      ),
    );
  }

  return _VirtualDataGrid(
    result: result,
    onSave: onSave,
    selectedIndices: selectedIndices,
    onSelectChanged: onSelectChanged,
    onSelectAll: onSelectAll,
    sortColumnIndex: sortColumnIndex,
    sortAscending: sortAscending,
    onSortColumn: onSortColumn,
  );
}

class _VirtualDataGrid extends StatelessWidget {
  final QueryResult result;
  final Future<void> Function(
    String column,
    String oldValue,
    String newValue,
    Map<String, String> rowMap,
  )?
  onSave;
  final Set<int>? selectedIndices;
  final Function(int, bool)? onSelectChanged;
  final Function(bool?)? onSelectAll;
  final int? sortColumnIndex;
  final bool sortAscending;
  final Function(int columnIndex)? onSortColumn;

  const _VirtualDataGrid({
    required this.result,
    required this.onSave,
    required this.selectedIndices,
    required this.onSelectChanged,
    required this.onSelectAll,
    required this.sortColumnIndex,
    required this.sortAscending,
    required this.onSortColumn,
  });

  bool get _hasSelection => onSelectChanged != null;

  @override
  Widget build(BuildContext context) {
    final columnWidths = _calculateColumnWidths(result);
    final columnCount = result.columns.length + (_hasSelection ? 1 : 0);
    final rowCount = result.rows.length + 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: TableView.builder(
        columnCount: columnCount,
        rowCount: rowCount,
        columnBuilder: (index) {
          final width = _hasSelection && index == 0
              ? _gridSelectionColumnWidth
              : columnWidths[_dataColumnIndex(index)];
          return TableSpan(extent: FixedTableSpanExtent(width));
        },
        rowBuilder: (index) {
          final rowIndex = index - 1;
          final isSelected =
              rowIndex >= 0 && (selectedIndices?.contains(rowIndex) ?? false);
          return TableSpan(
            extent: FixedTableSpanExtent(
              index == 0 ? _gridHeaderHeight : _gridRowHeight,
            ),
            backgroundDecoration: TableSpanDecoration(
              color: index == 0
                  ? _gridHeaderColor
                  : isSelected
                  ? _gridSelectedColor
                  : Colors.white,
            ),
            foregroundDecoration: const TableSpanDecoration(
              border: TableSpanBorder(
                trailing: BorderSide(color: _gridDividerColor, width: 0.5),
              ),
            ),
          );
        },
        cellBuilder: (context, vicinity) {
          if (vicinity.row == 0) {
            return TableViewCell(child: _buildHeaderCell(vicinity.column));
          }
          return TableViewCell(
            child: _buildBodyCell(
              rowIndex: vicinity.row - 1,
              columnIndex: vicinity.column,
            ),
          );
        },
      ),
    );
  }

  int _dataColumnIndex(int tableColumnIndex) {
    return _hasSelection ? tableColumnIndex - 1 : tableColumnIndex;
  }

  List<double> _calculateColumnWidths(QueryResult result) {
    const textScale = 8.0;
    const horizontalPadding = 32.0;
    final sampleCount = math.min(result.rows.length, 30);

    return List<double>.generate(result.columns.length, (columnIndex) {
      var longest = result.columns[columnIndex].length;
      for (var rowIndex = 0; rowIndex < sampleCount; rowIndex++) {
        if (columnIndex < result.rows[rowIndex].length) {
          longest = math.max(
            longest,
            result.rows[rowIndex][columnIndex].length,
          );
        }
      }
      final width = longest * textScale + horizontalPadding;
      return width.clamp(_gridMinColumnWidth, _gridMaxColumnWidth).toDouble();
    });
  }

  Widget _buildHeaderCell(int tableColumnIndex) {
    if (_hasSelection && tableColumnIndex == 0) {
      final selectedCount = selectedIndices?.length ?? 0;
      final rowCount = result.rows.length;
      final bool? value = rowCount == 0 || selectedCount == 0
          ? false
          : selectedCount >= rowCount
          ? true
          : null;

      return Center(
        child: Checkbox(
          tristate: true,
          value: value,
          onChanged: onSelectAll,
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    final columnIndex = _dataColumnIndex(tableColumnIndex);
    final isSorted = sortColumnIndex == columnIndex;
    final header = result.columns[columnIndex].toUpperCase();
    final label = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            header,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 10,
              color: _gridMutedTextColor,
              letterSpacing: 1.0,
              fontFamily: 'monospace',
            ),
          ),
        ),
        if (isSorted) ...[
          const SizedBox(width: 4),
          Icon(
            sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
            size: 11,
            color: _gridMutedTextColor,
          ),
        ],
      ],
    );

    return InkWell(
      onTap: onSortColumn == null ? null : () => onSortColumn!(columnIndex),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Align(alignment: Alignment.centerLeft, child: label),
      ),
    );
  }

  Widget _buildBodyCell({required int rowIndex, required int columnIndex}) {
    if (_hasSelection && columnIndex == 0) {
      return Center(
        child: Checkbox(
          value: selectedIndices?.contains(rowIndex) ?? false,
          onChanged: (selected) {
            onSelectChanged?.call(rowIndex, selected ?? false);
          },
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    final dataColumnIndex = _dataColumnIndex(columnIndex);
    final row = result.rows[rowIndex];
    final cell = dataColumnIndex < row.length ? row[dataColumnIndex] : '';
    final colName = result.columns[dataColumnIndex];
    final isNull = cell == 'NULL';
    final isEmpty = cell.isEmpty;
    final isSpecial = isNull || isEmpty;
    final displayValue = isEmpty ? 'EMPTY' : cell;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: InlineEditCell(
          columnName: colName,
          initialValue: cell,
          displayValue: displayValue,
          isSpecial: isSpecial,
          onSave: onSave == null
              ? null
              : (newValue) async {
                  final rowMap = {
                    for (var i = 0; i < result.columns.length; i++)
                      result.columns[i]: i < row.length ? row[i] : '',
                  };
                  await onSave!(colName, cell, newValue, rowMap);
                },
        ),
      ),
    );
  }
}
