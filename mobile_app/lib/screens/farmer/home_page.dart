import 'package:flutter/material.dart';
import 'package:muzhir/config/app_theme.dart';

/// Placeholder for the Farmer Home Dashboard.
/// Will be fully built in Item 2 (Stats, Weather, Recent Scans).
class FarmerHomePage extends StatelessWidget {
  const FarmerHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.dashboard_rounded,
            size: 72,
            color: MuzhirColors.coreLeafGreen.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'Farmer Dashboard',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Stats, Weather & Recent Scans coming soon',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: MuzhirColors.deepCharcoal.withValues(alpha: 0.6),
                ),
          ),
        ],
      ),
    );
  }
}
