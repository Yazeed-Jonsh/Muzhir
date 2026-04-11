import 'package:cloud_firestore/cloud_firestore.dart';

/// App user profile stored at Firestore `users/{userId}`.
class MuzhirUser {
  const MuzhirUser({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.roleName,
    required this.preferredLanguage,
    required this.createdAt,
    required this.isActive,
    this.profilePictureUrl,
  });

  /// Firestore `userId` / `uid` when set; otherwise the document ID ([DocumentSnapshot.id]).
  final String userId;
  final String fullName;
  final String email;
  final String roleName;

  /// UI / layout language from Firestore `preferredLanguage`, with legacy `language` fallback.
  final String preferredLanguage;
  final Timestamp createdAt;
  final bool isActive;

  /// Public HTTPS URL for the profile image from Firestore `profilePictureUrl`.
  final String? profilePictureUrl;

  /// Parses a Firestore user document.
  ///
  /// Supports legacy fields from signup: `name` → [fullName], `role` → [roleName].
  factory MuzhirUser.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) {
      throw StateError('User document has no data');
    }

    final createdRaw = data['createdAt'];
    final Timestamp createdTs;
    if (createdRaw is Timestamp) {
      createdTs = createdRaw;
    } else {
      createdTs = Timestamp.fromDate(DateTime.fromMillisecondsSinceEpoch(0));
    }

    final picRaw = data['profilePictureUrl'];
    final String? profilePictureUrl;
    if (picRaw is String && picRaw.trim().isNotEmpty) {
      profilePictureUrl = picRaw.trim();
    } else {
      profilePictureUrl = null;
    }

    final explicitId = data['userId'] ?? data['uid'];
    final String resolvedUserId;
    if (explicitId != null && explicitId.toString().trim().isNotEmpty) {
      resolvedUserId = explicitId.toString().trim();
    } else {
      resolvedUserId = doc.id;
    }

    return MuzhirUser(
      userId: resolvedUserId,
      fullName: (data['fullName'] ?? data['name'] ?? '').toString().trim(),
      email: (data['email'] ?? '').toString(),
      roleName: (data['roleName'] ?? data['role'] ?? 'Farmer').toString(),
      preferredLanguage:
          (data['preferredLanguage'] ?? data['language'] ?? 'en').toString(),
      createdAt: createdTs,
      isActive: data['isActive'] is bool ? data['isActive'] as bool : true,
      profilePictureUrl: profilePictureUrl,
    );
  }

  /// Initials for avatar: first letter of first and last word when possible.
  String get initials {
    final name = fullName.trim();
    if (name.isEmpty) {
      if (email.isEmpty) return '?';
      final local = email.split('@').first;
      if (local.isEmpty) return '?';
      return local.length >= 2
          ? local.substring(0, 2).toUpperCase()
          : local[0].toUpperCase();
    }
    final parts =
        name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length == 1) {
      final w = parts.first;
      if (w.length >= 2) return w.substring(0, 2).toUpperCase();
      return w[0].toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  bool get isAdminRole {
    final r = roleName.trim().toLowerCase();
    return r == 'admin' || r == 'administrator';
  }
}
