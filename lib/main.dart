import 'package:flutter/material.dart';
import 'src/rust/frb_generated.dart';
import 'src/features/connections/pages/connections_page.dart';
import 'src/features/connections/models/database_connection.dart';
import 'src/theme/muji_theme.dart';


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
      title: 'Grid',
      debugShowCheckedModeBanner: false,
      theme: MujiTheme.light,
      home: const ConnectionsPage(),
    );
  }
}