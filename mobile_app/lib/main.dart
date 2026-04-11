import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzhir/models/muzhir_user.dart';
import 'package:muzhir/providers/user_stream_provider.dart';
import 'package:muzhir/theme/app_theme.dart';
import 'package:muzhir/firebase_options.dart';
import 'package:muzhir/screens/farmer/login_screen.dart';
import 'package:muzhir/screens/main_scaffold.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );
  runApp(
    const ProviderScope(
      child: MuzhirApp(),
    ),
  );
}

/// Root widget for the Muzhir application.
class MuzhirApp extends ConsumerWidget {
  const MuzhirApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncUser = ref.watch(userStreamProvider);
    final textDirection = asyncUser.maybeWhen(
      data: (snapshot) => _textDirectionForProfileUser(snapshot.user),
      orElse: () => TextDirection.ltr,
    );

    return MaterialApp(
      title: 'Muzhir مزهر',
      debugShowCheckedModeBanner: false,
      theme: MuzhirTheme.lightTheme,
      home: const AuthGate(),
      builder: (context, child) {
        return Directionality(
          textDirection: textDirection,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

/// Layout direction from Firestore [MuzhirUser.preferredLanguage] (and legacy `language` via model).
/// Signed-out, loading, errors, or missing profile default to LTR.
TextDirection _textDirectionForProfileUser(MuzhirUser? user) {
  if (user == null) return TextDirection.ltr;
  final code = user.preferredLanguage.trim().toLowerCase();
  if (code == 'ar' || code == 'arabic' || code.startsWith('ar_')) {
    return TextDirection.rtl;
  }
  return TextDirection.ltr;
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
