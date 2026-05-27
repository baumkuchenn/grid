import 'package:flutter/material.dart';

class InlineEditCell extends StatelessWidget {
  final String columnName;
  final String initialValue;
  final String displayValue;
  final bool isSpecial;
  final Future<void> Function(String newValue)? onSave;

  const InlineEditCell({
    super.key,
    required this.columnName,
    required this.initialValue,
    required this.displayValue,
    required this.isSpecial,
    this.onSave,
  });

  void _openEditPanel(BuildContext context) {
    if (onSave == null) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withValues(alpha: 0.1),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) {
        String currentValue = isSpecial ? "" : initialValue;
        bool isSaving = false;
        String? saveError;

        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: const Color(0xFFFAF8F5), // Washi Cream Sheet
            elevation: 0,
            child: Container(
              width: 400,
              height: double.infinity,
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(color: Color(0xFFE8E5DF), width: 0.5),
                ), // Divider Clay
              ),
              child: StatefulBuilder(
                builder: (context, setState) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 20,
                        ),
                        child: Text(
                          columnName.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF73726F),
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFE8E5DF)),

                      // Editor Memo Block
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "CELL VALUE MEMO",
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF73726F),
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(
                                    color: const Color(0xFFE8E5DF),
                                    width: 0.5,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                padding: const EdgeInsets.all(16),
                                child: TextFormField(
                                  initialValue: currentValue,
                                  maxLines: null,
                                  autofocus: true,
                                  onChanged: (val) {
                                    currentValue = val;
                                    if (saveError != null) {
                                      setState(() => saveError = null);
                                    }
                                  },
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isSpecial
                                        ? const Color(
                                            0xFF2D2D2D,
                                          ).withValues(alpha: 0.5)
                                        : const Color(0xFF2D2D2D),
                                    fontStyle: isSpecial
                                        ? FontStyle.italic
                                        : FontStyle.normal,
                                    height: 1.5,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: isSpecial
                                        ? displayValue
                                        : "Enter value...",
                                    hintStyle: const TextStyle(
                                      color: Color(0xFFC4C2BC),
                                    ),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                              if (saveError != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: Text(
                                    saveError!,
                                    style: const TextStyle(
                                      color: Color(0xFFAC6B62),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                      // Footer
                      const Divider(height: 1, color: Color(0xFFE8E5DF)),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF73726F),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                              child: const Text(
                                "CANCEL",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      if (currentValue == initialValue &&
                                          !isSpecial) {
                                        Navigator.pop(context);
                                        return;
                                      }
                                      setState(() {
                                        isSaving = true;
                                        saveError = null;
                                      });
                                      try {
                                        await onSave!(currentValue);
                                        if (context.mounted) {
                                          Navigator.pop(context);
                                        }
                                      } catch (e) {
                                        setState(() {
                                          isSaving = false;
                                          saveError = e.toString();
                                        });
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7F0019),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              child: isSaving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      "SAVE VALUE",
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position:
              Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openEditPanel(context),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 200, minWidth: 50),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          displayValue,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            color: isSpecial
                ? const Color(0xFFAC6B62).withValues(alpha: 0.75)
                : const Color(
                    0xFF2D2D2D,
                  ), // Terracotta for NULL/EMPTY indicators
            fontStyle: isSpecial ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ),
    );
  }
}
