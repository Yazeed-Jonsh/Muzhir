import 'package:flutter/material.dart';
import 'package:muzhir/l10n/app_localizations.dart';
import 'package:muzhir/theme/app_theme.dart';
import 'package:muzhir/widgets/treatment_recommendation_card_panel.dart';

/// Diagnose flow (new scan): show recommendation in a rounded dialog with lightbulb + close.
Future<void> showTreatmentRecommendationModal(
  BuildContext context, {
  required String recommendationText,
}) async {
  final trimmed = recommendationText.trim();
  if (trimmed.isEmpty) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      final l10n = AppLocalizations.of(ctx)!;
      final maxH = MediaQuery.sizeOf(ctx).height * 0.72;

      final scrollMax = maxH * 0.52;

      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        backgroundColor: kRecommendationCardBackground,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 400, maxHeight: maxH),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 12, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: AlignmentDirectional.topEnd,
                  child: IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: l10n.close,
                    color: MuzhirColors.mutedGrey,
                  ),
                ),
                Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 44,
                  color: MuzhirColors.forestGreen.withValues(alpha: 0.9),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: scrollMax),
                  child: SingleChildScrollView(
                    child: TreatmentRecommendationCardPanel(
                      recommendationText: trimmed,
                      showHeading: true,
                      cardBackgroundColor: MuzhirColors.cardWhite,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
