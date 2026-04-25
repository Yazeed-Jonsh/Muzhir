import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:muzhir/core/utils/translation_helper.dart';
import 'package:muzhir/l10n/app_localizations.dart';
import 'package:muzhir/theme/app_theme.dart';
import 'package:muzhir/widgets/recent_scan_tile.dart';

/// Text-only diagnosis result card.
/// Displays crop, disease name, confidence bar, and capture source.
/// No bounding boxes or segmentation masks.
class DiagnosisResultCard extends StatelessWidget {
  const DiagnosisResultCard({
    super.key,
    required this.cropType,
    required this.diseaseName,
    this.diseaseNameAr,
    required this.confidencePercent,
    required this.source,
    this.isHealthy = false,
    this.latitude,
    this.longitude,
  });

  final String cropType;
  final String diseaseName;

  /// When set (e.g. from class map or API [labelAr]), used for Arabic locale.
  final String? diseaseNameAr;
  final int confidencePercent;
  final ScanSource source;
  final bool isHealthy;
  /// Capture location from geolocator at scan time, if available.
  final double? latitude;
  final double? longitude;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cropDisplay = TranslationHelper.getLocalizedText(context, cropType);
    final diseaseDisplay = TranslationHelper.localizedDiseaseName(
      context,
      diseaseName,
      diseaseNameAr,
    );
    final sourceKey = source == ScanSource.mobile ? 'Mobile' : 'Drone';
    final sourceDisplay = TranslationHelper.getLocalizedText(context, sourceKey);
    final Color statusColor =
        isHealthy ? MuzhirColors.coreLeafGreen : MuzhirColors.infectionSeriousOrange;
    final bool isMobile = source == ScanSource.mobile;

    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.all(20),
      decoration: BoxDecoration(
        color: MuzhirColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: MuzhirColors.deepCharcoal.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(
                Icons.biotech_rounded,
                color: MuzhirColors.coreLeafGreen,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.diagnosisResult,
                style: GoogleFonts.lexend(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: MuzhirColors.titleCharcoal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _ResultRow(
            icon: Icons.health_and_safety_outlined,
            label: TranslationHelper.getLocalizedText(context, 'Status'),
            value: TranslationHelper.getLocalizedText(
              context,
              isHealthy ? 'Healthy' : 'Unhealthy',
            ),
            valueColor: statusColor,
          ),
          const SizedBox(height: 12),

          // Crop name (value is localized crop type)
          _ResultRow(
            icon: Icons.local_florist_rounded,
            label: l10n.labelCropName,
            value: cropDisplay,
            valueColor: MuzhirColors.deepCharcoal,
          ),
          const SizedBox(height: 12),

          // Disease name
          _ResultRow(
            icon: Icons.coronavirus_rounded,
            label: l10n.disease,
            value: diseaseDisplay,
            valueColor: statusColor,
          ),
          const SizedBox(height: 16),

          // Confidence bar
          Text(
            l10n.confidence,
            textAlign: TextAlign.start,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: MuzhirColors.deepCharcoal.withValues(alpha: 0.55),
                  fontSize: 13,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: confidencePercent / 100,
                    minHeight: 10,
                    backgroundColor:
                        MuzhirColors.deepCharcoal.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$confidencePercent%',
                textAlign: TextAlign.start,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Divider
          Divider(
            color: MuzhirColors.deepCharcoal.withValues(alpha: 0.08),
          ),
          const SizedBox(height: 12),

          // Source indicator
          Row(
            children: [
              Icon(
                isMobile ? Icons.smartphone_rounded : Icons.flight_rounded,
                size: 18,
                color: isMobile
                    ? MuzhirColors.vividSprout
                    : MuzhirColors.coreLeafGreen,
              ),
              const SizedBox(width: 8),
              Text(
                '${l10n.source}: $sourceDisplay',
                textAlign: TextAlign.start,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: MuzhirColors.deepCharcoal.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
          if (latitude != null && longitude != null) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: MuzhirColors.coreLeafGreen.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${l10n.location}: ${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}',
                    textAlign: TextAlign.start,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: MuzhirColors.deepCharcoal.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: MuzhirColors.coreLeafGreen.withValues(alpha: 0.7)),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          textAlign: TextAlign.start,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: MuzhirColors.deepCharcoal.withValues(alpha: 0.55),
              ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.start,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: valueColor,
                ),
          ),
        ),
      ],
    );
  }
}
