import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:muzhir/l10n/app_localizations.dart';
import 'package:muzhir/theme/app_theme.dart';

/// Greeting banner at the top of the Farmer Dashboard.
/// Shows a welcome message and the current date.
class GreetingHeader extends StatelessWidget {
  const GreetingHeader({super.key});

  String _greetingByHour(AppLocalizations l10n) {
    final hour = DateTime.now().hour;
    if (hour < 12) return l10n.goodMorning;
    if (hour < 17) return l10n.goodAfternoon;
    return l10n.goodEvening;
  }

  String _formattedDate(BuildContext context) {
    final now = DateTime.now();
    final languageCode = Localizations.localeOf(context).languageCode.toLowerCase();
    if (languageCode == 'ar') {
      return DateFormat('EEEE، d MMMM', 'ar').format(now);
    }
    return DateFormat('EEEE, MMM d', languageCode).format(now);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            MuzhirColors.midnightTechGreen,
            MuzhirColors.midnightTechGreen.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_greetingByHour(l10n)}, ${l10n.farmer}',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: MuzhirColors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formattedDate(context),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: MuzhirColors.luminousLime,
                        ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MuzhirColors.coreLeafGreen.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.eco_rounded,
                color: MuzhirColors.luminousLime,
                size: 32,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
