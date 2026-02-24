import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:muzhir/config/app_theme.dart';
import 'package:muzhir/firebase_options.dart';
import 'package:muzhir/screens/main_scaffold.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
