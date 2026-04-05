import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:muzhir/theme/app_theme.dart';
import 'package:muzhir/firebase_options.dart';
import 'package:muzhir/screens/farmer/login_screen.dart';
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
      home: const AuthGate(),
    );
  }
}

/// Decides whether to show login or the home screen based on auth state.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return const MainScaffold();
        }
        return const LoginScreen();
      },
    );
  }
}
