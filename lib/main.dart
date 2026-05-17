import 'package:flutter/material.dart';
import 'src/rust/frb_generated.dart';
import 'src/features/connections/pages/connections_page.dart';
import 'src/features/connections/models/database_connection.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  await loadSavedConnections();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Grid DB',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        primaryColor: const Color(0xFF7F0019), // Muji Red
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF7F0019),
          secondary: Color(0xFF5C6670),
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF333333),
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: Color(0xFF333333)),
          titleTextStyle: TextStyle(
            color: Color(0xFF333333),
            fontSize: 16,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.0,
          ),
          shape: Border(bottom: BorderSide(color: Color(0xFFEAEAEA), width: 1)),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: const BorderSide(color: Color(0xFFEAEAEA)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Color(0xFFEAEAEA)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Color(0xFFEAEAEA)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Color(0xFF7F0019), width: 1.5),
          ),
          labelStyle: const TextStyle(color: Color(0xFF888888)),
          hintStyle: const TextStyle(color: Color(0xFFCCCCCC)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7F0019),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.5),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF5C6670),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF7F0019),
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        iconTheme: const IconThemeData(
          color: Color(0xFF5C6670),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFF333333)),
          bodyMedium: TextStyle(color: Color(0xFF555555)),
        ),
      ),
      home: const ConnectionsPage(),
    );
  }
}