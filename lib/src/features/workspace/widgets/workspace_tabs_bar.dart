import 'package:flutter/material.dart';
import '../models/workspace_tab.dart';

class WorkspaceTabsBar extends StatelessWidget {
  final List<WorkspaceTab> tabs;
  final String? activeTabId;
  final ValueChanged<String> onTabSelected;
  final ValueChanged<String> onTabClosed;

  const WorkspaceTabsBar({
    super.key,
    required this.tabs,
    required this.activeTabId,
    required this.onTabSelected,
    required this.onTabClosed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: Color(0xFFF3EFE9), // Kraft Sand tab track
        border: Border(
          bottom: BorderSide(color: Color(0xFFE8E5DF), width: 0.5),
        ), // Divider Clay
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        itemBuilder: (context, index) {
          final tab = tabs[index];
          final isActive = tab.id == activeTabId;

          return InkWell(
            onTap: () => onTabSelected(tab.id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFFFAF8F5)
                    : Colors
                          .transparent, // Active tab matches Washi Cream sheet below it!
                border: Border(
                  top: BorderSide(
                    color: isActive
                        ? const Color(0xFF7F0019)
                        : Colors.transparent, // Muji Red Signature
                    width: 3, // Premium thicker rule
                  ),
                  right: const BorderSide(color: Color(0xFFE8E5DF), width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    tab.tableName == null
                        ? Icons.terminal_outlined
                        : Icons.table_chart_outlined,
                    size: 14,
                    color: isActive
                        ? const Color(0xFF2D2D2D)
                        : const Color(0xFF73726F),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tab.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      color: isActive
                          ? const Color(0xFF2D2D2D)
                          : const Color(0xFF73726F),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => onTabClosed(tab.id),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(
                        Icons.close,
                        size: 14,
                        color: isActive
                            ? const Color(0xFF2D2D2D)
                            : const Color(0xFF73726F),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
