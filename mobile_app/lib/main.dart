import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:muzhir/config/app_theme.dart';
import 'package:muzhir/firebase_options.dart';
import 'package:muzhir/screens/auth/login_screen.dart';
import 'package:muzhir/screens/main_scaffold.dart';
import 'package:muzhir/services/auth_service.dart';
import 'package:provider/provider.dart';

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
    return ChangeNotifierProvider(
      create: (_) => AuthService(),
      child: MaterialApp(
        title: 'Muzhir مزهر',
        debugShowCheckedModeBanner: false,
        theme: MuzhirTheme.lightTheme,
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    
    if (authService.isAuthenticated) {
      return const MainScaffold();
    } else {
      return const LoginScreen();
    }
  }
}
