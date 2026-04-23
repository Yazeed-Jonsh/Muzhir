import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzhir/providers/user_stream_provider.dart';

final localeOverrideProvider = StateProvider<Locale?>((ref) => null);

/// Device locale (language code only). Matches typical [Platform.localeName]
/// behavior (e.g. `ar_SA` → Arabic) without requiring `dart:io` (web-safe).
Locale localeFromPlatformDispatcher() {
  final code =
      PlatformDispatcher.instance.locale.languageCode.toLowerCase().trim();
  if (code == 'ar') {
    return const Locale('ar');
  }
  return const Locale('en');
}

Locale effectiveAppLocale({
  required Locale? overrideLocale,
  required String preferredLanguageCode,
}) {
  if (overrideLocale != null) {
    return overrideLocale;
  }
  final normalized = preferredLanguageCode.trim().toLowerCase();
  if (normalized == 'ar' ||
      normalized == 'arabic' ||
      normalized.startsWith('ar_')) {
    return const Locale('ar');
  }
  if (normalized.isNotEmpty) {
    return const Locale('en');
  }
  return localeFromPlatformDispatcher();
}

/// Single source of truth for [MaterialApp.locale] (login shell through main app).
final appLocaleProvider = Provider<Locale>((ref) {
  final overrideLocale = ref.watch(localeOverrideProvider);
  final asyncUser = ref.watch(userStreamProvider);
  final preferredLanguageCode = asyncUser.maybeWhen(
    data: (snapshot) => snapshot.user?.preferredLanguage ?? '',
    orElse: () => '',
  );
  return effectiveAppLocale(
    overrideLocale: overrideLocale,
    preferredLanguageCode: preferredLanguageCode,
  );
});
