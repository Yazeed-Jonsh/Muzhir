import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:muzhir/l10n/app_localizations.dart';

/// Maps backend / English technical labels to Arabic display strings.
/// For non-Arabic locales (or unknown keys), returns the original [key].
class TranslationHelper {
  TranslationHelper._();

  static const Map<String, String> _crops = {
    'tomato': 'طماطم',
    'corn': 'ذرة',
    'potato': 'بطاطس',
    'wheat': 'قمح',
  };

  static const Map<String, String> _diseases = {
    'Early Blight': 'لفحة مبكرة',
    'Late Blight': 'لفحة متأخرة',
    'Tomato_Mildiou': 'البياض الزغبي',
    'Healthy': 'سليم',
    'No disease detected': 'لم يتم اكتشاف مرض',
  };

  /// Short UI labels (English key → Arabic).
  static const Map<String, String> _labels = {
    'Status': 'الحالة الصحية',
  };

  static const Map<String, String> _status = {
    'Unhealthy': 'غير سليم',
  };

  static const Map<String, String> _sources = {
    'Mobile': 'الجوال',
    'Drone': 'الدرون',
    'IoT': 'حساسات',
  };

  /// Returns Arabic mapping when locale is Arabic and [key] matches a known entry;
  /// otherwise returns [key] unchanged (English or unknown).
  static String getLocalizedText(BuildContext context, String key) {
    final trimmed = key.trim();
    if (trimmed.isEmpty) return key;

    final code = Localizations.localeOf(context).languageCode.toLowerCase();
    if (code != 'ar') return trimmed;

    if (_labels.containsKey(trimmed)) {
      return _labels[trimmed]!;
    }
    if (_diseases.containsKey(trimmed)) {
      return _diseases[trimmed]!;
    }
    if (_status.containsKey(trimmed)) {
      return _status[trimmed]!;
    }

    final cropKey = trimmed.toLowerCase();
    if (_crops.containsKey(cropKey)) {
      return _crops[cropKey]!;
    }
    if (_crops.containsKey(trimmed)) {
      return _crops[trimmed]!;
    }

    if (_sources.containsKey(trimmed)) {
      return _sources[trimmed]!;
    }

    return trimmed;
  }

  /// Post-processes Arabic AI recommendation text (ميلديو, kontrol, etc.).
  static String cleanArabicText(String text) {
    if (text.isEmpty) return text;
    var s = text;
    s = s.replaceAll('الميلديو', 'البياض الزغبي');
    s = s.replaceAll('ميلديو', 'البياض الزغبي');
    s = s.replaceAllMapped(
      RegExp('kontrol', caseSensitive: false),
      (_) => 'التحكم',
    );
    return s;
  }

  /// Relative time for scan lists (Home, History): [AppLocalizations] + [intl] calendar dates.
  static String relativeScanTimeLabel(
    BuildContext context,
    DateTime time,
    AppLocalizations l10n,
  ) {
    final now = DateTime.now();
    final d = now.difference(time);
    if (d.isNegative || d.inSeconds < 45) return l10n.justNow;
    if (d.inMinutes < 60) return l10n.minutesAgo(d.inMinutes);
    if (d.inHours < 24) return l10n.hoursAgo(d.inHours);
    if (d.inDays == 1) return l10n.yesterday;
    if (d.inDays < 7) return l10n.daysAgo(d.inDays);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    return DateFormat.yMMMd(localeTag).format(time);
  }
}
