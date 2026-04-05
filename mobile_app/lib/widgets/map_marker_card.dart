import 'package:flutter/material.dart';
import 'package:muzhir/theme/app_theme.dart';

/// Bottom sheet content displayed when a map marker is tapped.
class MapMarkerCard extends StatelessWidget {
  const MapMarkerCard({
    super.key,
    required this.locationName,
    required this.cropType,
    required this.diseaseName,
    required this.timeAgo,
    this.isHealthy = false,
  });

  final String locationName;
  final String cropType;
  final String diseaseName;
  final String timeAgo;
  final bool isHealthy;

  @override
  Widget build(BuildContext context) {
    final Color statusColor =
        isHealthy ? MuzhirColors.darkOliveGreen : MuzhirColors.earthyClayRed;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      decoration: const BoxDecoration(
        color: MuzhirColors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: MuzhirColors.deepCharcoal.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Location Title
          Row(
            children: [
              const Icon(
                Icons.location_on_rounded,
                color: MuzhirColors.midnightTechGreen,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                locationName,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: MuzhirColors.titleCharcoal,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Details Container
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MuzhirColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: MuzhirColors.deepCharcoal.withValues(alpha: 0.05),
              ),
            ),
            child: Column(
              children: [
                _DetailRow(
                  icon: Icons.local_florist_rounded,
                  label: 'Crop',
                  value: cropType,
                  valueColor: MuzhirColors.deepCharcoal,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1),
                ),
                _DetailRow(
                  icon: Icons.coronavirus_rounded,
                  label: 'Status',
                  value: diseaseName,
                  valueColor: statusColor,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1),
                ),
                _DetailRow(
                  icon: Icons.access_time_rounded,
                  label: 'Reported',
                  value: timeAgo,
                  valueColor: MuzhirColors.deepCharcoal.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Action Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                // TODO: Navigate to full diagnosis details
              },
              icon: const Icon(Icons.info_outline_rounded),
              label: const Text('View Details'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
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
        Icon(icon, size: 18, color: MuzhirColors.coreLeafGreen),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: MuzhirColors.deepCharcoal.withValues(alpha: 0.55),
              ),
        ),
        const Spacer(),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
        ),
      ],
    );
  }
}
