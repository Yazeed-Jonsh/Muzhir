import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzhir/models/muzhir_user.dart';

/// Firestore profile snapshot for the signed-in user, including cache metadata.
class UserProfileSnapshot {
  const UserProfileSnapshot({
    this.user,
    required this.isFromCache,
    this.documentId = '',
  });

  final MuzhirUser? user;

  /// Firestore document ID for `users/{documentId}` (must match signed-in UID).
  final String documentId;

  /// True when this snapshot was read from local persistence (no server yet).
  final bool isFromCache;
}

/// Real-time profile for the signed-in user from `users/{uid}`.
///
/// With [Settings.persistenceEnabled], snapshots may be served from the local
/// cache while offline; [UserProfileSnapshot.isFromCache] reflects that.
final userStreamProvider = StreamProvider<UserProfileSnapshot>((ref) {
  return FirebaseAuth.instance.authStateChanges().asyncExpand((user) {
    if (user == null) {
      return Stream<UserProfileSnapshot>.value(
        const UserProfileSnapshot(
          user: null,
          isFromCache: false,
          documentId: '',
        ),
      );
    }
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots(includeMetadataChanges: true)
        .map((DocumentSnapshot<Map<String, dynamic>> snap) {
      final fromCache = snap.metadata.isFromCache;
      if (!snap.exists) {
        return UserProfileSnapshot(
          user: null,
          isFromCache: fromCache,
          documentId: snap.id,
        );
      }
      return UserProfileSnapshot(
        user: MuzhirUser.fromFirestore(snap),
        isFromCache: fromCache,
        documentId: snap.id,
      );
    });
  });
});
