import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _userEmail;
  DateTime? _lastSentTime;
  
  User? get currentUser => _auth.currentUser;
  String? get userEmail => _userEmail;
  bool get isAuthenticated => currentUser != null;
  
  AuthService() {
    _auth.authStateChanges().listen((User? user) {
      notifyListeners();
    });
  }

  Future<bool> sendSignInLink(String email) async {
    try {
      _userEmail = email;
      _lastSentTime = DateTime.now();
      
      final actionCodeSettings = ActionCodeSettings(
        url: 'https://muzhir.page.link/auth',
        handleCodeInApp: true,
        androidPackageName: 'com.muzhir.app',
        androidInstallApp: true,
        androidMinimumVersion: '21',
        iOSBundleId: 'com.muzhir.app',
        dynamicLinkDomain: 'muzhir.page.link',
      );

      await _auth.sendSignInLinkToEmail(
        email: email,
        actionCodeSettings: actionCodeSettings,
      );
      
      if (kDebugMode) {
        print('Authentication link sent to $email');
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error sending authentication link: $e');
      }
      return false;
    }
  }

  Future<bool> resendSignInLink() async {
    if (_userEmail == null) {
      if (kDebugMode) {
        print('No email stored for resend');
      }
      return false;
    }
    
    final now = DateTime.now();
    if (_lastSentTime != null && now.difference(_lastSentTime!).inSeconds < 60) {
      if (kDebugMode) {
        print('Please wait before resending (rate limit)');
      }
      return false;
    }
    
    return await sendSignInLink(_userEmail!);
  }

  Future<bool> signInWithEmailLink(String email, String emailLink) async {
    try {
      if (!_auth.isSignInWithEmailLink(emailLink)) {
        if (kDebugMode) {
          print('Invalid email link');
        }
        return false;
      }

      final userCredential = await _auth.signInWithEmailLink(
        email: email,
        emailLink: emailLink,
      );

      if (userCredential.user != null) {
        _userEmail = null;
        _lastSentTime = null;
        notifyListeners();
        return true;
      }
      
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Error signing in with email link: $e');
      }
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
      _userEmail = null;
      _lastSentTime = null;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error signing out: $e');
      }
    }
  }

  bool canResendLink() {
    if (_lastSentTime == null) return true;
    final now = DateTime.now();
    return now.difference(_lastSentTime!).inSeconds >= 60;
  }

  int getSecondsUntilCanResend() {
    if (_lastSentTime == null) return 0;
    final now = DateTime.now();
    final elapsed = now.difference(_lastSentTime!).inSeconds;
    return (60 - elapsed).clamp(0, 60);
  }
}
