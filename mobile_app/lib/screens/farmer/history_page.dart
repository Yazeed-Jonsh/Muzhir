import 'package:flutter/material.dart';
import 'package:muzhir/theme/app_theme.dart';

/// Placeholder for the Scan History Page.
/// Will be fully built in Item 5 (Hive persistence, sync indicators).
class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_rounded,
            size: 72,
            color: MuzhirColors.coreLeafGreen.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'Scan History',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'History & Local Storage coming soon',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: MuzhirColors.deepCharcoal.withValues(alpha: 0.6),
                ),
          ),
        ],
      ),
    );
  }
}
