import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:muzhir/l10n/app_localizations.dart';
import 'package:muzhir/theme/app_theme.dart';
import 'package:muzhir/widgets/treatment_recommendation_card_panel.dart';

/// History / scan detail: inline expand/collapse with [TreatmentRecommendationCardPanel] below.
class TreatmentRecommendationSection extends StatelessWidget {
  const TreatmentRecommendationSection({
    super.key,
    required this.expanded,
    required this.onToggle,
    required this.recommendationText,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final String recommendationText;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final trimmed = recommendationText.trim();
    if (trimmed.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: onToggle,
            style: OutlinedButton.styleFrom(
              foregroundColor: MuzhirColors.forestGreen,
              side: BorderSide(
                color: MuzhirColors.forestGreen.withValues(alpha: 0.45),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              minimumSize: const Size(double.infinity, 52),
              alignment: Alignment.center,
              tapTargetSize: MaterialTapTargetSize.padded,
            ),
            child: SizedBox(
              width: double.infinity,
              child: Align(
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      expanded
                          ? l10n.hideTreatmentAdvice
                          : l10n.getTreatmentAdvice,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.lexend(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (expanded) ...[
          const SizedBox(height: 12),
          TreatmentRecommendationCardPanel(
            recommendationText: trimmed,
          ),
        ],
      ],
    );
  }
}
