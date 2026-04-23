import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:muzhir/l10n/app_localizations.dart';
import 'package:muzhir/providers/locale_provider.dart';
import 'package:muzhir/theme/app_theme.dart';
import 'package:muzhir/firebase_options.dart';
import 'package:muzhir/screens/farmer/login_screen.dart';
import 'package:muzhir/screens/main_scaffold.dart';

void main() {
  // ALL initialization must be inside the runWithClient zone so that
  // WidgetsFlutterBinding.ensureInitialized() and runApp() share the same
  // zone.  Splitting them across zones triggers a fatal "Zone mismatch"
  // assertion on every hot restart and silently breaks the IOClient override.
  http.runWithClient(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      // Allow google_fonts to fetch fonts at runtime; if DNS is broken the
      // errors will be visible and help diagnose connectivity issues.
      GoogleFonts.config.allowRuntimeFetching = true;
      try {
        await dotenv.load(fileName: '.env');
      } catch (_) {
        // Keep startup resilient in local/dev; EnvConfig falls back to dart-define/default.
      }
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
      );
      // Connectivity probe – fires once at startup so we can see in the
      // console whether external HTTPS DNS resolution is actually working.
      unawaited(_probeConnectivity());
      runApp(const ProviderScope(child: MuzhirApp()));
    },
    () => IOClient(HttpClient()),
  );
}

/// Probes three external HTTPS endpoints and prints the result.
/// Output lets us distinguish DNS failure, timeout, or 4xx/5xx errors.
Future<void> _probeConnectivity() async {
  const probes = [
    'https://tile.openstreetmap.org',
    'https://res.cloudinary.com',
    'https://www.google.com',
  ];
  for (final url in probes) {
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));
      debugPrint('[NET_PROBE] $url → HTTP ${response.statusCode}');
    } catch (e) {
      debugPrint('[NET_PROBE] $url → ERROR: $e');
    }
  }
}

/// Root widget for the Muzhir application.
class MuzhirApp extends ConsumerWidget {
  const MuzhirApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(appLocaleProvider);

    return MaterialApp(
      title: 'Muzhir',
      debugShowCheckedModeBanner: false,
      theme: MuzhirTheme.lightTheme,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
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
