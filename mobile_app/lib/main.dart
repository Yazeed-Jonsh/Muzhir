import 'package:flutter/material.dart';
import 'package:muzhir/config/app_theme.dart';
import 'package:muzhir/screens/main_scaffold.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MuzhirApp());
}

/// Root widget for the Muzhir application.
class MuzhirApp extends StatelessWidget {
  const MuzhirApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Muzhir مزهر',
      debugShowCheckedModeBanner: false,
      theme: MuzhirTheme.lightTheme,
      home: const MainScaffold(),
    );
  }
}
