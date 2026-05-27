import 'package:flutter/material.dart';

class MujiTheme {
  // Organic design palette
  static const Color washiCream = Color(0xFFFAF8F5);
  static const Color kraftSand = Color(0xFFF3EFE9);
  static const Color sumiInk = Color(0xFF2D2D2D);
  static const Color woodAsh = Color(0xFF73726F);
  static const Color mujiRed = Color(0xFF7F0019);
  static const Color mossGreen = Color(0xFF5A6B5C);
  static const Color terracotta = Color(0xFFAC6B62);
  static const Color dividerClay = Color(0xFFE8E5DF);

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: washiCream,
      primaryColor: mujiRed,
      colorScheme: const ColorScheme.light(
        primary: mujiRed,
        secondary: woodAsh,
        surface: Colors.white,
        error: terracotta,
      ),

      // Clean Typography
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: sumiInk, fontSize: 14, letterSpacing: 0.2),
        bodyMedium: TextStyle(color: sumiInk, fontSize: 13, letterSpacing: 0.2),
        labelLarge: TextStyle(
          color: woodAsh,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),

      // Minimalist AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: washiCream,
        foregroundColor: sumiInk,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: sumiInk, size: 20),
        titleTextStyle: TextStyle(
          color: sumiInk,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        ),
        shape: Border(bottom: BorderSide(color: dividerClay, width: 0.5)),
      ),

      // Tactile Cards
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: dividerClay, width: 0.5),
        ),
      ),

      // Organic Text Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: dividerClay, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: dividerClay, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: mujiRed, width: 1.2),
        ),
        labelStyle: const TextStyle(color: woodAsh, fontSize: 13),
        hintStyle: const TextStyle(color: Color(0xFFC4C2BC), fontSize: 13),
      ),

      // Elevated Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: mujiRed,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // Text Buttons
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: woodAsh,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),

      // Floating Action Buttons
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: mujiRed,
        foregroundColor: Colors.white,
        elevation: 1,
      ),

      iconTheme: const IconThemeData(color: woodAsh),
    );
  }
}
