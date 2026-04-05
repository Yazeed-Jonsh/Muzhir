import 'package:flutter/material.dart';
import 'package:muzhir/theme/app_theme.dart';
import 'package:muzhir/widgets/greeting_header.dart';
import 'package:muzhir/widgets/stat_card.dart';
import 'package:muzhir/widgets/weather_card.dart';
import 'package:muzhir/widgets/recent_scan_tile.dart';

/// Farmer Home Dashboard.
/// Displays greeting, quick stats, weather, and recent scan history.
class FarmerHomePage extends StatelessWidget {
  const FarmerHomePage({super.key});

  // ── Mock data ───────────────────────────────────────────────────────
  static const List<RecentScan> _mockScans = [
    RecentScan(
      plantName: 'Tomato',
      diseaseName: 'Early Blight',
      confidencePercent: 94,
      timeAgo: '2 hours ago',
      source: ScanSource.mobile,
    ),
    RecentScan(
      plantName: 'Wheat',
      diseaseName: 'Leaf Rust',
      confidencePercent: 87,
      timeAgo: 'Yesterday',
      source: ScanSource.drone,
    ),
    RecentScan(
      plantName: 'Date Palm',
      diseaseName: 'Healthy',
      confidencePercent: 98,
      timeAgo: '2 days ago',
      source: ScanSource.mobile,
      isHealthy: true,
    ),
    RecentScan(
      plantName: 'Cucumber',
      diseaseName: 'Powdery Mildew',
      confidencePercent: 79,
      timeAgo: '3 days ago',
      source: ScanSource.drone,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      shrinkWrap: false,
      physics: const ClampingScrollPhysics(),
      children: [
        const GreetingHeader(),
        const SizedBox(height: 20),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              StatCard(
                icon: Icons.center_focus_strong,
                value: '12',
                label: 'Total Scans',
                iconColor: MuzhirColors.coreLeafGreen,
              ),
              SizedBox(width: 12),
              StatCard(
                icon: Icons.eco_rounded,
                value: '9',
                label: 'Healthy',
                iconColor: MuzhirColors.coreLeafGreen,
                iconBackgroundColor: MuzhirColors.statHealthyIconWell,
              ),
              SizedBox(width: 12),
              StatCard(
                icon: Icons.coronavirus_outlined,
                value: '3',
                label: 'Diseased',
                iconColor: MuzhirColors.infectionSeriousOrange,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: WeatherCard(),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Scans',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              TextButton(
                onPressed: () {
                  // TODO: Navigate to full history (Item 5)
                },
                child: Text(
                  'View All',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: MuzhirColors.titleCharcoal,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        for (final scan in _mockScans)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: RecentScanTile(scan: scan),
          ),
        const SizedBox(height: 100),
      ],
    );
  }
}
