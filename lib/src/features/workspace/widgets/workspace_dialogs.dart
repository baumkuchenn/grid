import 'package:flutter/material.dart';

class WorkspaceDialogs {
  /// Shows a form dialog with a single text field (e.g. for creating/naming a database or table)
  static Future<String?> showForm({
    required BuildContext context,
    required String title,
    required String label,
    String initialValue = "",
  }) async {
    return showDialog<String>(
      context: context,
      builder: (context) =>
          _FormDialog(title: title, label: label, initialValue: initialValue),
    );
  }

  /// Shows the table clone dialog with the duplicate data option
  static Future<Map<String, dynamic>?> showCloneTable({
    required BuildContext context,
    required String table,
  }) async {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _CloneTableDialog(table: table),
    );
  }

  /// Shows a confirmation dialog (e.g. for drop database, drop table, truncate table)
  static Future<bool?> showConfirm({
    required BuildContext context,
    required String title,
    required String message,
    bool showFkCheckbox = false,
    String confirmText = "CONFIRM",
  }) async {
    bool disableFk = false;
    return showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: const Color(0xFFFAF8F5), // Washi Cream Sheet
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: const BorderSide(color: Color(0xFFE8E5DF), width: 0.5),
          ),
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFAC6B62), // Terracotta warning!
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF73726F), // Wood Ash
                    height: 1.5,
                  ),
                ),
                if (showFkCheckbox) ...[
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: disableFk,
                          onChanged: (v) =>
                              setState(() => disableFk = v ?? false),
                          activeColor: const Color(0xFFAC6B62),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          "Disable Foreign Key Checks",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF2D2D2D),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF73726F),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      child: const Text(
                        "CANCEL",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(
                        context,
                        showFkCheckbox ? disableFk : true,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(
                          0xFFAC6B62,
                        ), // Terracotta warning background
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                      ),
                      child: Text(
                        confirmText.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FormDialog extends StatefulWidget {
  final String title;
  final String label;
  final String initialValue;

  const _FormDialog({
    required this.title,
    required this.label,
    required this.initialValue,
  });

  @override
  State<_FormDialog> createState() => _FormDialogState();
}

class _FormDialogState extends State<_FormDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue)
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.initialValue.length,
      );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFFFAF8F5), // Washi Cream Sheet
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(color: Color(0xFFE8E5DF), width: 0.5),
      ),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title.toUpperCase(),
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w700,
                color: Color(0xFF2D2D2D), // Sumi Ink
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              widget.label.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF73726F), // Wood Ash
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              autofocus: true,
              controller: _controller,
              style: const TextStyle(fontSize: 13, color: Color(0xFF2D2D2D)),
              decoration: const InputDecoration(
                isDense: true,
                fillColor: Colors.white,
                filled: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFE8E5DF), width: 0.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF7F0019), width: 1.0),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF73726F),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    "CANCEL",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, _controller.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7F0019), // Muji Red
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                  ),
                  child: const Text(
                    "SAVE",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CloneTableDialog extends StatefulWidget {
  final String table;

  const _CloneTableDialog({required this.table});

  @override
  State<_CloneTableDialog> createState() => _CloneTableDialogState();
}

class _CloneTableDialogState extends State<_CloneTableDialog> {
  late final TextEditingController _controller;
  bool _duplicateData = true;

  @override
  void initState() {
    super.initState();
    final initialVal = "${widget.table}_copy";
    _controller = TextEditingController(text: initialVal)
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: initialVal.length,
      );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFFFAF8F5), // Washi Cream Sheet
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(color: Color(0xFFE8E5DF), width: 0.5),
      ),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "CLONE TABLE",
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w700,
                color: Color(0xFF2D2D2D), // Sumi Ink
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "NEW TABLE NAME",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF73726F), // Wood Ash
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              autofocus: true,
              controller: _controller,
              style: const TextStyle(fontSize: 13, color: Color(0xFF2D2D2D)),
              decoration: const InputDecoration(
                isDense: true,
                fillColor: Colors.white,
                filled: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFE8E5DF), width: 0.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF7F0019), width: 1.0),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _duplicateData,
                    onChanged: (v) =>
                        setState(() => _duplicateData = v ?? false),
                    activeColor: const Color(0xFF7F0019), // Muji Red
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  "Duplicate table data",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2D2D2D),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF73726F),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    "CANCEL",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, {
                    'name': _controller.text,
                    'data': _duplicateData,
                  }),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7F0019),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                  ),
                  child: const Text(
                    "CLONE",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
