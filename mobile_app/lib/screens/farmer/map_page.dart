import 'package:flutter/material.dart';
import 'package:muzhir/config/app_theme.dart';

/// Placeholder for the Interactive Disease Map.
/// Will be fully built in Item 4 (Google Maps, Saudi Arabia mock markers).
class MapPage extends StatelessWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.map_rounded,
            size: 72,
            color: MuzhirColors.coreLeafGreen.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'Disease Map',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Geospatial Visualization coming soon',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: MuzhirColors.deepCharcoal.withValues(alpha: 0.6),
                ),
          ),
        ],
      ),
    );
  }
}
