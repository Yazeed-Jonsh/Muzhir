import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../firebase_options.dart';

/// Temporary Firebase Health Check entry point.
///
/// Run with: flutter run -t lib/debug/firebase_test.dart
///
/// This verifies:
/// 1. Firebase initialization
/// 2. Firestore write to connection_verify collection
/// 3. Prints success (doc_id) or specific Firebase error
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(FirebaseHealthCheckApp());
}

class FirebaseHealthCheckApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Firebase Health Check',
      home: FirebaseHealthCheckScreen(),
    );
  }
}

class FirebaseHealthCheckScreen extends StatefulWidget {
  @override
  State<FirebaseHealthCheckScreen> createState() =>
      _FirebaseHealthCheckScreenState();
}

class _FirebaseHealthCheckScreenState extends State<FirebaseHealthCheckScreen> {
  String _status = 'Starting...';
  String _details = '';

  @override
  void initState() {
    super.initState();
    _runHealthCheck();
  }

  Future<void> _runHealthCheck() async {
    try {
      setState(() {
        _status = 'Initializing Firebase...';
        _details = '';
      });

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      if (!mounted) return;
      setState(() {
        _status = 'Writing test document...';
      });

      final docRef = await FirebaseFirestore.instance
          .collection('connection_verify')
          .add(<String, dynamic>{
        'timestamp': FieldValue.serverTimestamp(),
        'test': true,
        'source': 'muzhir_health_check',
      });

      if (!mounted) return;
      setState(() {
        _status = 'SUCCESS';
        _details = 'Document ID: ${docRef.id}';
      });

      if (kDebugMode) {
        debugPrint('[Firebase Health Check] SUCCESS - doc_id: ${docRef.id}');
      }
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'Firebase Error';
        _details = 'Code: ${e.code}\nMessage: ${e.message}';
      });
      if (kDebugMode) {
        debugPrint(
            '[Firebase Health Check] FAILED - ${e.code}: ${e.message}');
      }
    } catch (e, stack) {
      if (!mounted) return;
      setState(() {
        _status = 'Error';
        _details = e.toString();
      });
      if (kDebugMode) {
        debugPrint('[Firebase Health Check] FAILED - $e\n$stack');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSuccess = _status == 'SUCCESS';
    return Scaffold(
      appBar: AppBar(title: const Text('Firebase Health Check')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error_outline,
              size: 80,
              color: isSuccess ? Colors.green : Colors.orange,
            ),
            const SizedBox(height: 24),
            Text(
              _status,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isSuccess ? Colors.green : Colors.black87,
                  ),
              textAlign: TextAlign.center,
            ),
            if (_details.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  _details,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
