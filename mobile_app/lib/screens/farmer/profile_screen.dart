import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:muzhir/models/muzhir_user.dart';
import 'package:muzhir/providers/connectivity_provider.dart';
import 'package:muzhir/providers/user_stream_provider.dart';
import 'package:muzhir/screens/farmer/login_screen.dart';
import 'package:muzhir/services/auth_service.dart';
import 'package:muzhir/theme/app_theme.dart';
import 'package:shimmer/shimmer.dart';

/// Profile with live Firestore sync via [userStreamProvider].
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static const double _headerHeight = 208;
  static const double _headerCurve = 36;
  static const double _avatarRadius = 52;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final asyncUser = ref.watch(userStreamProvider);

    return Scaffold(
      backgroundColor: MuzhirColors.creamScaffold,
      body: asyncUser.when(
        loading: () => const _ProfileLoadingView(
          headerHeight: _headerHeight,
          headerCurve: _headerCurve,
          avatarRadius: _avatarRadius,
        ),
        error: (error, stackTrace) {
          // Temporary: surface provider/Firestore failures in the console while debugging.
          print('ProfileScreen userStreamProvider error: $error');
          print('ProfileScreen userStreamProvider stackTrace:\n$stackTrace');
          return _ProfileErrorView(
            message: error.toString(),
            headerHeight: _headerHeight,
            headerCurve: _headerCurve,
            avatarRadius: _avatarRadius,
            onRetry: () => ref.invalidate(userStreamProvider),
          );
        },
        data: (snapshot) {
          final user = snapshot.user;
          if (user == null) {
            return _ProfileErrorView(
              message:
                  'We could not find your profile. It may still be syncing, or your account data is missing.',
              headerHeight: _headerHeight,
              headerCurve: _headerCurve,
              avatarRadius: _avatarRadius,
              onRetry: () => ref.invalidate(userStreamProvider),
            );
          }
          if (!_profileIdentityAuthorized(
            authUid: authUser.uid,
            documentId: snapshot.documentId,
            user: user,
          )) {
            return _ProfileErrorView(
              message:
                  'Security Mismatch: Unauthorized access detected.',
              headerHeight: _headerHeight,
              headerCurve: _headerCurve,
              avatarRadius: _avatarRadius,
              onRetry: () => ref.invalidate(userStreamProvider),
            );
          }
          return _ProfileLoadedView(
            user: user,
            isFromCache: snapshot.isFromCache,
            headerHeight: _headerHeight,
            headerCurve: _headerCurve,
            avatarRadius: _avatarRadius,
            editingEnabled: user.isActive,
            onLanguageChanged: (newLang) =>
                _updateLanguage(context, ref, newLang),
          );
        },
      ),
    );
  }
}

/// Ensures the Firestore document path and stored user id match the signed-in account.
bool _profileIdentityAuthorized({
  required String authUid,
  required String documentId,
  required MuzhirUser user,
}) {
  if (documentId.isEmpty || documentId != authUid) return false;
  if (user.userId != authUid) return false;
  return true;
}

bool _refIndicatesOffline(WidgetRef ref) {
  return ref.read(isOfflineProvider).maybeWhen(
        data: (offline) => offline,
        orElse: () => false,
      );
}

void _showOfflinePersistenceNotice(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      backgroundColor: MuzhirColors.titleCharcoal,
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.cloud_off_outlined,
            color: MuzhirColors.cardWhite.withValues(alpha: 0.95),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'You are currently offline. Changes will be saved locally and synced once you are back online.',
              style: GoogleFonts.lexend(
                color: MuzhirColors.cardWhite,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Persists [newLang] (`ar` | `en`) to Firestore `preferredLanguage` for the signed-in user.
Future<void> _updateLanguage(
  BuildContext context,
  WidgetRef ref,
  String newLang,
) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;

  if (_refIndicatesOffline(ref)) {
    _showOfflinePersistenceNotice(context);
  }

  await FirebaseFirestore.instance.collection('users').doc(uid).update({
    'preferredLanguage': newLang,
  });

  if (!context.mounted) return;
  final label = newLang == 'ar' ? 'Arabic' : 'English';
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: MuzhirColors.forestGreen,
      content: Text(
        'Language updated to $label',
        style: GoogleFonts.lexend(
          color: MuzhirColors.cardWhite,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

/// Persists [newName] to Firestore `fullName` and shows connectivity-aware feedback.
Future<void> _updateName(
  BuildContext context,
  WidgetRef ref,
  String newName,
) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;

  final wasOffline = _refIndicatesOffline(ref);

  await FirebaseFirestore.instance.collection('users').doc(uid).update({
    'fullName': newName,
  });

  if (!context.mounted) return;

  final message = wasOffline
      ? 'You are offline. Name updated locally and will sync later.'
      : 'Name updated successfully!';

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      backgroundColor: wasOffline
          ? MuzhirColors.titleCharcoal
          : MuzhirColors.forestGreen,
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (wasOffline) ...[
            Icon(
              Icons.cloud_off_outlined,
              color: MuzhirColors.cardWhite.withValues(alpha: 0.95),
              size: 22,
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.lexend(
                color: MuzhirColors.cardWhite,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> _showEditFullNameDialog(
  BuildContext context,
  WidgetRef ref,
  MuzhirUser user, {
  required bool allowSave,
}) async {
  if (!allowSave) return;
  final newName = await showDialog<String>(
    context: context,
    builder: (ctx) => _EditFullNameDialog(
      initialName: user.fullName.trim(),
      allowSave: allowSave,
    ),
  );
  if (newName == null || !context.mounted) return;
  if (newName == user.fullName.trim()) return;

  await _updateName(context, ref, newName);
}

String _segmentLanguageCode(String raw) {
  final c = raw.trim().toLowerCase();
  if (c == 'ar' || c == 'arabic' || c.startsWith('ar_')) return 'ar';
  return 'en';
}

String? _nonEmptyProfilePictureUrl(String? raw) {
  if (raw == null) return null;
  final t = raw.trim();
  return t.isEmpty ? null : t;
}

void _showAvatarChangeRequiresOnline(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      backgroundColor: MuzhirColors.titleCharcoal,
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.wifi_off_rounded,
            color: MuzhirColors.cardWhite.withValues(alpha: 0.95),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Connect to the internet to change or remove your profile photo.',
              style: GoogleFonts.lexend(
                color: MuzhirColors.cardWhite,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

String _formatMemberSince(Timestamp ts) {
  final date = ts.toDate();
  if (date.year <= 1971) return '—';
  const months = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[date.month - 1]} ${date.year}';
}

String _displayRoleLabel(String roleName) {
  final t = roleName.trim();
  if (t.isEmpty) return 'Member';
  return '${t[0].toUpperCase()}${t.length > 1 ? t.substring(1).toLowerCase() : ''}';
}

void _showAccountDisabledNotice(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      backgroundColor: MuzhirColors.earthyClayRed,
      content: Text(
        'Your account has been disabled. You cannot change this.',
        style: GoogleFonts.lexend(
          color: MuzhirColors.cardWhite,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
      ),
    ),
  );
}

/// Pinned red banner for disabled accounts (below status bar).
class _DisabledAccountBannerDelegate extends SliverPersistentHeaderDelegate {
  _DisabledAccountBannerDelegate({required this.topPadding});

  final double topPadding;

  static const double _bodyHeight = 52;

  @override
  double get minExtent => topPadding + _bodyHeight;

  @override
  double get maxExtent => topPadding + _bodyHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: MuzhirColors.earthyClayRed,
      elevation: overlapsContent ? 3 : 0,
      shadowColor: Colors.black26,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, topPadding + 8, 16, 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '⚠️ Your account has been disabled. Please contact support.',
            style: GoogleFonts.lexend(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: MuzhirColors.cardWhite,
              height: 1.35,
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _DisabledAccountBannerDelegate oldDelegate) {
    return oldDelegate.topPadding != topPadding;
  }
}

class _CachedProfileDataBanner extends StatelessWidget {
  const _CachedProfileDataBanner();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: MuzhirColors.navIndicatorFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: MuzhirColors.weatherIconCircle.withValues(alpha: 0.55),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 20,
              color: MuzhirColors.forestGreen.withValues(alpha: 0.85),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'You are viewing a saved copy from this device. Reconnect to refresh from the cloud.',
                style: GoogleFonts.lexend(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                  color: MuzhirColors.titleCharcoal.withValues(alpha: 0.82),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditFullNameDialog extends StatefulWidget {
  const _EditFullNameDialog({
    required this.initialName,
    required this.allowSave,
  });

  final String initialName;
  final bool allowSave;

  @override
  State<_EditFullNameDialog> createState() => _EditFullNameDialogState();
}

class _EditFullNameDialogState extends State<_EditFullNameDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allowSave = widget.allowSave;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        allowSave ? 'Edit Name' : 'Name',
        style: GoogleFonts.lexend(
          fontWeight: FontWeight.w700,
          color: MuzhirColors.titleCharcoal,
        ),
      ),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          readOnly: !allowSave,
          textCapitalization: TextCapitalization.words,
          autofocus: allowSave,
          style: GoogleFonts.lexend(
            fontSize: 15,
            color: allowSave
                ? MuzhirColors.titleCharcoal
                : MuzhirColors.mutedGrey,
          ),
          decoration: InputDecoration(
            labelText: 'Full name',
            filled: !allowSave,
            fillColor: !allowSave
                ? MuzhirColors.mutedGrey.withValues(alpha: 0.12)
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: allowSave
                    ? MuzhirColors.forestGreen
                    : MuzhirColors.mutedGrey.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Enter your name';
            return null;
          },
        ),
      ),
      actions: [
        if (allowSave) ...[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.lexend(
                fontWeight: FontWeight.w600,
                color: MuzhirColors.mutedGrey,
              ),
            ),
          ),
          FilledButton(
            onPressed: () {
              if (_formKey.currentState?.validate() ?? false) {
                Navigator.pop(context, _controller.text.trim());
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: MuzhirColors.forestGreen,
              foregroundColor: MuzhirColors.cardWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text(
              'Save',
              style: GoogleFonts.lexend(fontWeight: FontWeight.w700),
            ),
          ),
        ] else
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.lexend(
                fontWeight: FontWeight.w600,
                color: MuzhirColors.mutedGrey,
              ),
            ),
          ),
      ],
    );
  }
}

class _ProfileLoadedView extends ConsumerStatefulWidget {
  const _ProfileLoadedView({
    required this.user,
    required this.isFromCache,
    required this.headerHeight,
    required this.headerCurve,
    required this.avatarRadius,
    required this.editingEnabled,
    required this.onLanguageChanged,
  });

  final MuzhirUser user;
  final bool isFromCache;
  final double headerHeight;
  final double headerCurve;
  final double avatarRadius;
  final bool editingEnabled;
  final Future<void> Function(String newLang) onLanguageChanged;

  @override
  ConsumerState<_ProfileLoadedView> createState() => _ProfileLoadedViewState();
}

class _ProfileLoadedViewState extends ConsumerState<_ProfileLoadedView> {
  bool _uploadingAvatar = false;

  Widget _buildAvatarFace() {
    final user = widget.user;
    final radius = widget.avatarRadius;
    final diameter = radius * 2;
    final url = _nonEmptyProfilePictureUrl(user.profilePictureUrl);
    final initials = Text(
      user.initials,
      style: GoogleFonts.lexend(
        fontSize: radius * 0.9,
        fontWeight: FontWeight.w700,
        color: MuzhirColors.forestGreen,
        height: 1,
      ),
    );

    final Widget core;
    if (url != null) {
      core = CachedNetworkImage(
        imageUrl: url,
        width: diameter,
        height: diameter,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 200),
        placeholder: (context, _) => Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: MuzhirColors.forestGreen.withValues(alpha: 0.75),
            ),
          ),
        ),
        errorWidget: (context, _, __) => Center(child: initials),
      );
    } else {
      core = Center(child: initials);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        core,
        if (_uploadingAvatar)
          ColoredBox(
            color: MuzhirColors.cardWhite.withValues(alpha: 0.72),
            child: const Center(
              child: SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: MuzhirColors.forestGreen,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCameraAccessory({
    required bool isOffline,
    required bool editingEnabled,
  }) {
    final disabled = isOffline || !editingEnabled;
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Material(
        elevation: 3,
        shadowColor: Colors.black26,
        color: MuzhirColors.cardWhite,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            if (!editingEnabled) {
              _showAccountDisabledNotice(context);
              return;
            }
            if (isOffline) {
              _showAvatarChangeRequiresOnline(context);
              return;
            }
            _showAvatarPicker(context);
          },
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              Icons.photo_camera_rounded,
              size: 20,
              color: disabled
                  ? MuzhirColors.mutedGrey
                  : MuzhirColors.forestGreen,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAvatarPicker(BuildContext context) async {
    if (!widget.editingEnabled) {
      _showAccountDisabledNotice(context);
      return;
    }
    final user = widget.user;
    final hasPhoto = _nonEmptyProfilePictureUrl(user.profilePictureUrl) != null;

    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: MuzhirColors.cardWhite,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                  bottom: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: MuzhirColors.mutedGrey.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 18, 8, 8),
                    child: Text(
                      'Profile photo',
                      style: GoogleFonts.lexend(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: MuzhirColors.titleCharcoal,
                      ),
                    ),
                  ),
                  _AvatarSheetTile(
                    icon: Icons.photo_camera_outlined,
                    label: 'Take Photo',
                    onTap: () => Navigator.of(sheetContext).pop('camera'),
                  ),
                  _AvatarSheetTile(
                    icon: Icons.photo_library_outlined,
                    label: 'Choose from Gallery',
                    onTap: () => Navigator.of(sheetContext).pop('gallery'),
                  ),
                  if (hasPhoto)
                    _AvatarSheetTile(
                      icon: Icons.delete_outline_rounded,
                      label: 'Remove Photo',
                      isDestructive: true,
                      onTap: () => Navigator.of(sheetContext).pop('remove'),
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (!context.mounted || choice == null) return;

    if (choice == 'remove') {
      if (_refIndicatesOffline(ref)) {
        _showAvatarChangeRequiresOnline(context);
        return;
      }
      await _removeProfilePhoto(context);
      return;
    }

    final source =
        choice == 'camera' ? ImageSource.camera : ImageSource.gallery;
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 88,
    );
    if (!context.mounted || picked == null) return;

    if (_refIndicatesOffline(ref)) {
      _showAvatarChangeRequiresOnline(context);
      return;
    }

    await _uploadProfilePicture(context, picked);
  }

  Future<void> _uploadProfilePicture(
    BuildContext context,
    XFile xFile,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _uploadingAvatar = true);
    try {
      final file = File(xFile.path);
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('users')
          .child(uid)
          .child('profile_pic.jpg');

      final contentType = xFile.mimeType ?? 'image/jpeg';
      await storageRef.putFile(
        file,
        SettableMetadata(contentType: contentType),
      );
      final downloadUrl = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'profilePictureUrl': downloadUrl,
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: MuzhirColors.forestGreen,
            content: Text(
              'Profile photo updated',
              style: GoogleFonts.lexend(
                color: MuzhirColors.cardWhite,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        final scheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: scheme.error,
            content: Text(
              'Could not upload photo. Please try again.',
              style: GoogleFonts.lexend(
                color: scheme.onError,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _removeProfilePhoto(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _uploadingAvatar = true);
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('users')
          .child(uid)
          .child('profile_pic.jpg');
      try {
        await storageRef.delete();
      } catch (_) {
        // Object may be missing; still clear Firestore.
      }

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'profilePictureUrl': FieldValue.delete(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: MuzhirColors.forestGreen,
            content: Text(
              'Profile photo removed',
              style: GoogleFonts.lexend(
                color: MuzhirColors.cardWhite,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        final scheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: scheme.error,
            content: Text(
              'Could not remove photo. Please try again.',
              style: GoogleFonts.lexend(
                color: scheme.onError,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final nameStyle = GoogleFonts.lexend(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: MuzhirColors.titleCharcoal,
      height: 1.2,
    );
    final emailStyle = GoogleFonts.lexend(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: MuzhirColors.mutedGrey,
      height: 1.35,
    );

    final displayName =
        user.fullName.trim().isNotEmpty ? user.fullName.trim() : 'Muzhir user';
    final emailLine =
        user.email.trim().isNotEmpty ? user.email.trim() : 'No email on file';

    final selectedLang = _segmentLanguageCode(user.preferredLanguage);

    final offlineAsync = ref.watch(isOfflineProvider);
    final isOffline = offlineAsync.maybeWhen(
      data: (offline) => offline,
      orElse: () => false,
    );

    final topSafe = MediaQuery.paddingOf(context).top;
    final editingEnabled = widget.editingEnabled;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        if (!user.isActive)
          SliverPersistentHeader(
            pinned: true,
            delegate: _DisabledAccountBannerDelegate(topPadding: topSafe),
          ),
        SliverToBoxAdapter(
          child: _CurvedHeaderBlock(
            headerHeight: widget.headerHeight,
            headerCurve: widget.headerCurve,
            avatarRadius: widget.avatarRadius,
            avatarChild: _buildAvatarFace(),
            avatarAccessory: _buildCameraAccessory(
              isOffline: isOffline,
              editingEnabled: editingEnabled,
            ),
            topBar: _HeaderBackBar(
              onBack: () => Navigator.of(context).maybePop(),
            ),
            // Red disabled banner already reserves the status bar; avoid double inset.
            omitTopSafePadding: !user.isActive,
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            _horizontalPagePadding(context),
            20,
            _horizontalPagePadding(context),
            32,
          ),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: nameStyle.copyWith(
                              color: editingEnabled
                                  ? MuzhirColors.titleCharcoal
                                  : MuzhirColors.mutedGrey,
                            ),
                          ),
                        ),
                        if (editingEnabled)
                          IconButton(
                            tooltip: 'Edit Name',
                            onPressed: () => _showEditFullNameDialog(
                              context,
                              ref,
                              user,
                              allowSave: true,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 40,
                              minHeight: 40,
                            ),
                            icon: Icon(
                              Icons.edit_outlined,
                              size: 22,
                              color: MuzhirColors.forestGreen.withValues(
                                alpha: 0.9,
                              ),
                            ),
                          ),
                        if (user.isActive) ...[
                          const SizedBox(width: 4),
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: MuzhirColors.forestGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Tooltip(
                      message:
                          'Email is managed by your account and cannot be changed here.',
                      child: Text(
                        emailLine,
                        textAlign: TextAlign.center,
                        style: emailStyle,
                      ),
                    ),
                    if (widget.isFromCache) ...[
                      const SizedBox(height: 14),
                      const _CachedProfileDataBanner(),
                    ],
                    const SizedBox(height: 28),
                    _AccountInfoCard(
                      roleLabel: _displayRoleLabel(user.roleName),
                      selectedLanguageCode: selectedLang,
                      onLanguageChanged: widget.onLanguageChanged,
                      memberSince: _formatMemberSince(user.createdAt),
                      editingEnabled: editingEnabled,
                    ),
                    const SizedBox(height: 20),
                    const _SettingsActionsCard(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AvatarSheetTile extends StatelessWidget {
  const _AvatarSheetTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent =
        isDestructive ? scheme.error : MuzhirColors.forestGreen;
    final titleColor =
        isDestructive ? scheme.error : MuzhirColors.titleCharcoal;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: accent, size: 26),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.lexend(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileLoadingView extends StatelessWidget {
  const _ProfileLoadingView({
    required this.headerHeight,
    required this.headerCurve,
    required this.avatarRadius,
  });

  final double headerHeight;
  final double headerCurve;
  final double avatarRadius;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: _CurvedHeaderBlock(
            headerHeight: headerHeight,
            headerCurve: headerCurve,
            avatarRadius: avatarRadius,
            avatarChild: _shimmerCircle(context, radius: avatarRadius),
            topBar: _HeaderBackBar(
              onBack: () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            _horizontalPagePadding(context),
            20,
            _horizontalPagePadding(context),
            32,
          ),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  children: [
                    _shimmerBar(context, width: 220, height: 24),
                    const SizedBox(height: 12),
                    _shimmerBar(context, width: 180, height: 16),
                    const SizedBox(height: 18),
                    _shimmerBar(context, width: 96, height: 32, radius: 20),
                    const SizedBox(height: 28),
                    _accountCardSkeleton(context),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _shimmerBar(
    BuildContext context, {
    required double width,
    required double height,
    double radius = 8,
  }) {
    return _wrapShimmer(
      context,
      Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: MuzhirColors.cardWhite,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }

  Widget _shimmerCircle(BuildContext context, {required double radius}) {
    return _wrapShimmer(
      context,
      Container(
        width: radius * 2,
        height: radius * 2,
        decoration: const BoxDecoration(
          color: MuzhirColors.cardWhite,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _wrapShimmer(BuildContext context, Widget child) {
    return Shimmer.fromColors(
      baseColor: MuzhirColors.mutedGrey.withValues(alpha: 0.18),
      highlightColor: MuzhirColors.cardWhite,
      period: const Duration(milliseconds: 1200),
      child: child,
    );
  }

  Widget _accountCardSkeleton(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        color: MuzhirColors.cardWhite,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _shimmerBar(context, width: 140, height: 14),
          const SizedBox(height: 18),
          _shimmerBar(context, width: double.infinity, height: 48, radius: 14),
          const SizedBox(height: 16),
          _shimmerBar(context, width: 160, height: 14),
          const SizedBox(height: 18),
          _shimmerBar(context, width: double.infinity, height: 48, radius: 14),
        ],
      ),
    );
  }
}

class _ProfileErrorView extends StatelessWidget {
  const _ProfileErrorView({
    required this.message,
    required this.headerHeight,
    required this.headerCurve,
    required this.avatarRadius,
    required this.onRetry,
  });

  final String message;
  final double headerHeight;
  final double headerCurve;
  final double avatarRadius;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: _CurvedHeaderBlock(
            headerHeight: headerHeight,
            headerCurve: headerCurve,
            avatarRadius: avatarRadius,
            avatarChild: Icon(
              Icons.person_outline_rounded,
              size: avatarRadius * 1.15,
              color: MuzhirColors.forestGreen.withValues(alpha: 0.45),
            ),
            topBar: _HeaderBackBar(
              onBack: () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: _horizontalPagePadding(context),
              vertical: 24,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: MuzhirColors.cardWhite,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: MuzhirColors.weatherIconCircle,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cloud_off_outlined,
                        size: 48,
                        color: MuzhirColors.forestGreen.withValues(alpha: 0.85),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Let’s try that again',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.lexend(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: MuzhirColors.titleCharcoal,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Temporary: shows raw [message] (e.g. error.toString()) for debugging.
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight:
                              MediaQuery.sizeOf(context).height * 0.4,
                        ),
                        child: SingleChildScrollView(
                          child: SelectableText(
                            message,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.lexend(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              height: 1.45,
                              color: MuzhirColors.mutedGrey,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: onRetry,
                          child: const Text('Retry'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CurvedHeaderBlock extends StatelessWidget {
  const _CurvedHeaderBlock({
    required this.headerHeight,
    required this.headerCurve,
    required this.avatarRadius,
    required this.avatarChild,
    required this.topBar,
    this.avatarAccessory,
    this.omitTopSafePadding = false,
  });

  /// Green area height below the status bar (not including safe-area inset).
  final double headerHeight;
  final double headerCurve;
  final double avatarRadius;
  final Widget avatarChild;
  final Widget? avatarAccessory;
  final Widget topBar;

  /// When true, [MediaQuery.padding.top] is not added (e.g. a pinned banner above
  /// already consumed the status bar).
  final bool omitTopSafePadding;

  @override
  Widget build(BuildContext context) {
    final topInset =
        omitTopSafePadding ? 0.0 : MediaQuery.paddingOf(context).top;
    final greenPaintedHeight = topInset + headerHeight;
    final stackHeight = greenPaintedHeight + avatarRadius + 12;

    return SizedBox(
      height: stackHeight,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: greenPaintedHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: MuzhirColors.forestGreen,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(headerCurve),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.only(top: topInset),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    topBar,
                    const Spacer(),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: greenPaintedHeight - avatarRadius,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: avatarRadius * 2,
                height: avatarRadius * 2,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: avatarRadius * 2,
                      height: avatarRadius * 2,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: MuzhirColors.cardWhite,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x1A000000),
                            blurRadius: 20,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: ClipOval(child: Center(child: avatarChild)),
                    ),
                    if (avatarAccessory != null)
                      PositionedDirectional(
                        end: -2,
                        bottom: -2,
                        child: avatarAccessory!,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderBackBar extends StatelessWidget {
  const _HeaderBackBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: MuzhirColors.cardWhite,
          style: IconButton.styleFrom(
            foregroundColor: MuzhirColors.cardWhite,
          ),
        ),
      ),
    );
  }
}

class _AccountInfoCard extends StatelessWidget {
  const _AccountInfoCard({
    required this.roleLabel,
    required this.selectedLanguageCode,
    required this.onLanguageChanged,
    required this.memberSince,
    required this.editingEnabled,
  });

  final String roleLabel;
  final String selectedLanguageCode;
  final Future<void> Function(String newLang) onLanguageChanged;
  final String memberSince;
  final bool editingEnabled;

  @override
  Widget build(BuildContext context) {
    final languageControl = SegmentedButton<String>(
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        backgroundColor: MuzhirColors.creamScaffold,
        foregroundColor: MuzhirColors.titleCharcoal,
        selectedForegroundColor: MuzhirColors.cardWhite,
        selectedBackgroundColor: MuzhirColors.forestGreen,
        side: BorderSide(
          color: MuzhirColors.weatherIconCircle.withValues(alpha: 0.9),
        ),
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: GoogleFonts.lexend(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      segments: const [
        ButtonSegment<String>(
          value: 'ar',
          label: Text('🇸🇦'),
          tooltip: 'Arabic',
        ),
        ButtonSegment<String>(
          value: 'en',
          label: Text('🇬🇧'),
          tooltip: 'English',
        ),
      ],
      selected: {selectedLanguageCode},
      onSelectionChanged: (Set<String> next) {
        if (next.isEmpty) return;
        final lang = next.first;
        if (lang == selectedLanguageCode) return;
        onLanguageChanged(lang);
      },
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      decoration: BoxDecoration(
        color: MuzhirColors.cardWhite,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
            child: Text(
              'Account',
              style: GoogleFonts.lexend(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: MuzhirColors.titleCharcoal,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Language',
                  style: GoogleFonts.lexend(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: MuzhirColors.mutedGrey,
                  ),
                ),
                const SizedBox(height: 10),
                AbsorbPointer(
                  absorbing: !editingEnabled,
                  child: Opacity(
                    opacity: editingEnabled ? 1 : 0.45,
                    child: Align(
                      alignment: Alignment.center,
                      child: editingEnabled
                          ? languageControl
                          : Tooltip(
                              message:
                                  'Your account has been disabled. Language cannot be changed.',
                              child: languageControl,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE8EDE4)),
          _AccountRow(
            leading: Icon(
              Icons.badge_outlined,
              color: editingEnabled
                  ? MuzhirColors.forestGreen
                  : MuzhirColors.mutedGrey,
              size: 26,
            ),
            title: 'Role',
            value: roleLabel,
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE8EDE4)),
          _AccountRow(
            leading: Icon(
              Icons.calendar_month_outlined,
              color: editingEnabled
                  ? MuzhirColors.forestGreen
                  : MuzhirColors.mutedGrey,
              size: 26,
            ),
            title: 'Member since',
            value: memberSince,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SettingsActionsCard extends StatelessWidget {
  const _SettingsActionsCard();

  Future<void> _onSignOut(BuildContext context) async {
    await AuthService().signOut();
    if (!context.mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      decoration: BoxDecoration(
        color: MuzhirColors.cardWhite,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
            child: Text(
              'Settings & Actions',
              style: GoogleFonts.lexend(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: MuzhirColors.titleCharcoal,
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _onSignOut(context),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 40,
                      child: Center(
                        child: Icon(
                          Icons.logout_rounded,
                          color: Colors.redAccent,
                          size: 26,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Sign Out',
                        style: GoogleFonts.lexend(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: MuzhirColors.titleCharcoal,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: MuzhirColors.mutedGrey,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.leading,
    required this.title,
    required this.value,
  });

  final Widget leading;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: 40, child: Center(child: leading)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.lexend(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: MuzhirColors.mutedGrey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.lexend(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: MuzhirColors.titleCharcoal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

double _horizontalPagePadding(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (w >= 900) return 48;
  if (w >= 600) return 32;
  return 20;
}
