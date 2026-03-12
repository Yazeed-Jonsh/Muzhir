import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Registers a new user with email and password.
  /// Returns the [User] on success, or null on failure.
  Future<User?> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': email,
          'name': name,
          'role': 'farmer',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      return user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        print('AuthService.signUp: weak-password - ${e.message}');
      } else if (e.code == 'email-already-in-use') {
        print('AuthService.signUp: email-already-in-use - ${e.message}');
      } else {
        print('AuthService.signUp: ${e.code} - ${e.message}');
      }
      rethrow;
    }
  }

  /// Signs in an existing user with email and password.
  /// Returns the [User] on success, or null on failure.
  Future<User?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        print('AuthService.signIn: user-not-found - ${e.message}');
      } else if (e.code == 'wrong-password') {
        print('AuthService.signIn: wrong-password - ${e.message}');
      } else {
        print('AuthService.signIn: ${e.code} - ${e.message}');
      }
      rethrow;
    }
  }

  /// Sends a password reset email to [email].
  /// Throws [FirebaseAuthException] on failure (e.g. user-not-found, invalid-email).
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        print('AuthService.sendPasswordReset: user-not-found - ${e.message}');
      } else if (e.code == 'invalid-email') {
        print('AuthService.sendPasswordReset: invalid-email - ${e.message}');
      } else {
        print('AuthService.sendPasswordReset: ${e.code} - ${e.message}');
      }
      rethrow;
    }
  }

  /// Signs out the current user.
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
