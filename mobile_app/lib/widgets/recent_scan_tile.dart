import 'package:flutter/material.dart';
import 'package:muzhir/config/app_theme.dart';

/// Capture source for a scan entry.
enum ScanSource { mobile, drone }

/// Data model for a single recent scan entry (mock).
class RecentScan {
  const RecentScan({
    required this.plantName,
    required this.diseaseName,
    required this.confidencePercent,
    required this.timeAgo,
    required this.source,
    this.isHealthy = false,
  });

  final String plantName;
  final String diseaseName;
  final int confidencePercent;
  final String timeAgo;
  final ScanSource source;
  final bool isHealthy;
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
        healthy ? MuzhirColors.coreLeafGreen : const Color(0xFFD4790E);

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
          // Thumbnail placeholder
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: MuzhirColors.luminousLime.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.local_florist_rounded,
              color: MuzhirColors.coreLeafGreen,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),

          // Plant name, disease, time
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scan.plantName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  scan.diseaseName,
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
              // Confidence badge
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
              // Source indicator icon
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
          isMobile ? 'Mobile' : 'Drone',
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
