import 'package:flutter/material.dart';

class SqlTextEditingController extends TextEditingController {
  static final RegExp _sqlRegex = RegExp(
    r'(\b(?:SELECT|FROM|WHERE|INSERT|INTO|UPDATE|SET|DELETE|CREATE|TABLE|DATABASE|DROP|ALTER|TRUNCATE|JOIN|LEFT|RIGHT|INNER|OUTER|ON|AND|OR|NOT|LIMIT|OFFSET|ORDER|BY|GROUP|HAVING|VALUES|INDEX|PRIMARY|KEY)\b)|'
    r"('[^']*')|"
    r'(\b\d+\b)|'
    r'(#.*|--.*|/\*[\s\S]*?\*/)',
    caseSensitive: false,
  );

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final List<TextSpan> children = [];
    final text = this.text;

    int lastIndex = 0;
    
    _sqlRegex.allMatches(text).forEach((match) {
      if (match.start > lastIndex) {
        children.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: style,
        ));
      }
      
      final String matchText = text.substring(match.start, match.end);
      
      if (match.group(1) != null) {
        children.add(TextSpan(
          text: matchText,
          style: style?.copyWith(
            color: const Color(0xFF4A4A4A),
            fontWeight: FontWeight.w700,
          ),
        ));
      } else if (match.group(2) != null) {
        children.add(TextSpan(
          text: matchText,
          style: style?.copyWith(
            color: const Color(0xFF5D7A68),
          ),
        ));
      } else if (match.group(3) != null) {
        children.add(TextSpan(
          text: matchText,
          style: style?.copyWith(
            color: const Color(0xFFB88B5C),
          ),
        ));
      } else if (match.group(4) != null) {
        children.add(TextSpan(
          text: matchText,
          style: style?.copyWith(
            color: const Color(0xFFCCCCCC),
            fontStyle: FontStyle.italic,
          ),
        ));
      } else {
        children.add(TextSpan(
          text: matchText,
          style: style,
        ));
      }
      
      lastIndex = match.end;
    });

    if (lastIndex < text.length) {
      children.add(TextSpan(
        text: text.substring(lastIndex),
        style: style,
      ));
    }

    return TextSpan(style: style, children: children);
  }
}
