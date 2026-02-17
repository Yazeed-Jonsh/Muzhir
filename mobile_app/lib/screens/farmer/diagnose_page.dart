import 'package:flutter/material.dart';
import 'package:muzhir/config/app_theme.dart';

/// Placeholder for the Diagnose Page.
/// Will be fully built in Item 3 (Camera, Gallery, Drone Import, Quality Feedback).
class DiagnosePage extends StatelessWidget {
  const DiagnosePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.document_scanner_rounded,
            size: 72,
            color: MuzhirColors.coreLeafGreen.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'Diagnose',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Capture & AI Analysis coming soon',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: MuzhirColors.deepCharcoal.withValues(alpha: 0.6),
                ),
          ),
        ],
      ),
    );
  }
}
