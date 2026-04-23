import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:muzhir/core/utils/translation_helper.dart';
import 'package:muzhir/l10n/app_localizations.dart';
import 'package:muzhir/theme/app_theme.dart';

/// Light green tint for the AI recommendation card (History inline + Diagnose modal).
const Color kRecommendationCardBackground = Color(0xFFF1F8E9);

/// Shared recommendation body: light green card, title, and readable body text.
class TreatmentRecommendationCardPanel extends StatelessWidget {
  const TreatmentRecommendationCardPanel({
    super.key,
    required this.recommendationText,
    this.showHeading = true,
    this.cardBackgroundColor,
  });

  final String recommendationText;
  final bool showHeading;
  /// When null, uses [kRecommendationCardBackground].
  final Color? cardBackgroundColor;

  static TextStyle bodyStyleFor(BuildContext context) {
    final isAr =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    final baseSize = Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14;
    return GoogleFonts.lexend(
      fontSize: baseSize,
      fontWeight: FontWeight.w500,
      color: MuzhirColors.mutedGrey,
      height: isAr ? 1.6 : 1.45,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final trimmed = recommendationText.trim();
    if (trimmed.isEmpty) return const SizedBox.shrink();

    final display = TranslationHelper.cleanArabicText(trimmed);
    final isAr =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';

    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.all(14),
      decoration: BoxDecoration(
        color: cardBackgroundColor ?? kRecommendationCardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.green.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeading) ...[
            Text(
              l10n.recommendation,
              style: GoogleFonts.lexend(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: MuzhirColors.titleCharcoal,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            display,
            textAlign: TextAlign.start,
            textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
            style: bodyStyleFor(context),
          ),
        ],
      ),
    );
  }
}
