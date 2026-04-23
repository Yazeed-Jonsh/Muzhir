import 'package:flutter/material.dart';
import 'package:muzhir/core/utils/translation_helper.dart';
import 'package:muzhir/theme/app_theme.dart';
import 'package:muzhir/widgets/recent_scan_thumbnail.dart';

/// Capture source for a scan entry.
enum ScanSource { mobile, drone }

/// Data model for a single recent scan entry (mock).
class RecentScan {
  const RecentScan({
    required this.plantName,
    required this.diseaseName,
    this.confidencePercent,
    required this.timeAgo,
    required this.source,
    this.isHealthy = false,
    this.imageUrl,
  });

  final String plantName;
  final String diseaseName;
  /// Whole percent (0–100); when null the confidence badge is hidden.
  final int? confidencePercent;
  final String timeAgo;
  final ScanSource source;
  final bool isHealthy;
  /// Thumbnail URL from API; placeholder if null or empty.
  final String? imageUrl;
}

/// Displays a single recent scan row with:
///   thumbnail placeholder | plant + disease | confidence | source icon
class RecentScanTile extends StatelessWidget {
  const RecentScanTile({super.key, required this.scan});

  final RecentScan scan;

  @override
  Widget build(BuildContext context) {
    final bool healthy = scan.isHealthy;
    final Color statusColor =
        healthy ? MuzhirColors.coreLeafGreen : MuzhirColors.infectionSeriousOrange;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MuzhirColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: MuzhirColors.deepCharcoal.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          RecentScanThumbnail(imageUrl: scan.imageUrl),
          const SizedBox(width: 14),

          // Plant name, disease, time
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  TranslationHelper.getLocalizedText(context, scan.plantName),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  TranslationHelper.getLocalizedText(context, scan.diseaseName),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  scan.timeAgo,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: MuzhirColors.deepCharcoal.withValues(alpha: 0.45),
                        fontSize: 12,
                      ),
                ),
              ],
            ),
          ),

          // Confidence + source indicator column
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (scan.confidencePercent != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${scan.confidencePercent}%',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              _SourceIndicator(source: scan.source),
            ],
          ),
        ],
      ),
    );
  }
}

/// Small icon + label indicating whether the image was captured via Mobile or Drone.
class _SourceIndicator extends StatelessWidget {
  const _SourceIndicator({required this.source});

  final ScanSource source;

  @override
  Widget build(BuildContext context) {
    final bool isMobile = source == ScanSource.mobile;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isMobile ? Icons.smartphone_rounded : Icons.flight_rounded,
          size: 14,
          color: isMobile
              ? MuzhirColors.vividSprout
              : MuzhirColors.coreLeafGreen,
        ),
        const SizedBox(width: 4),
        Text(
          TranslationHelper.getLocalizedText(
            context,
            isMobile ? 'Mobile' : 'Drone',
          ),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: MuzhirColors.deepCharcoal.withValues(alpha: 0.5),
              ),
        ),
      ],
    );
  }
}
