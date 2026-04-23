import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzhir/core/utils/translation_helper.dart';
import 'package:muzhir/l10n/app_localizations.dart';
import 'package:muzhir/models/scan_history_item.dart';
import 'package:muzhir/providers/scan_history_provider.dart';
import 'package:muzhir/theme/app_theme.dart';
import 'package:muzhir/widgets/greeting_header.dart';
import 'package:muzhir/widgets/recent_scan_tile.dart';
import 'package:muzhir/widgets/stat_card.dart';
import 'package:muzhir/widgets/weather_card.dart';

/// Farmer Home Dashboard.
/// Displays greeting, quick stats, weather, and recent scan history.
class FarmerHomePage extends ConsumerStatefulWidget {
  const FarmerHomePage({super.key, this.onViewAllHistory});

  /// Switches [MainScaffold] bottom nav to the History tab.
  final VoidCallback? onViewAllHistory;

  @override
  ConsumerState<FarmerHomePage> createState() => _FarmerHomePageState();
}

class _FarmerHomePageState extends ConsumerState<FarmerHomePage> {
  String _localizedDiagnosisLabel(ScanHistoryItem item, AppLocalizations l10n) {
    final isAr = Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    final localizedName = isAr ? item.diseaseNameAr : item.diseaseName;
    final fallbackName = isAr ? item.diseaseName : item.diseaseNameAr;
    final name = (localizedName ?? fallbackName ?? '').trim();
    if (name.isNotEmpty) return name;
    if (item.status == 'pending' || item.status == 'processing') {
      return l10n.analysisInProgress;
    }
    return l10n.noDiagnosisYet;
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(scanHistoryProvider);
    final l10n = AppLocalizations.of(context)!;
    final isAr = Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';

    final items = historyAsync.asData?.value ?? <ScanHistoryItem>[];
    final totalScans = items.length;
    final healthyScans = items.where((e) => e.isHealthy).length;
    final diseasedScans = totalScans - healthyScans;
    final recentScans = items.take(4).toList();

    final loading = historyAsync.isLoading && !historyAsync.hasValue;

    return ListView(
      padding: EdgeInsets.zero,
      shrinkWrap: false,
      physics: const ClampingScrollPhysics(),
      children: [
        const GreetingHeader(),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
          child: Row(
            children: [
              StatCard(
                icon: Icons.center_focus_strong,
                value: '$totalScans',
                label: l10n.totalScans,
                iconColor: MuzhirColors.coreLeafGreen,
              ),
              const SizedBox(width: 12),
              StatCard(
                icon: Icons.eco_rounded,
                value: '$healthyScans',
                label: l10n.healthy,
                iconColor: MuzhirColors.coreLeafGreen,
                iconBackgroundColor: MuzhirColors.statHealthyIconWell,
              ),
              const SizedBox(width: 12),
              StatCard(
                icon: Icons.coronavirus_outlined,
                value: '$diseasedScans',
                label: l10n.diseased,
                iconColor: MuzhirColors.infectionSeriousOrange,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Padding(
          padding: EdgeInsetsDirectional.symmetric(horizontal: 16),
          child: WeatherCard(),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.recentScans,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              TextButton(
                onPressed: widget.onViewAllHistory,
                child: Text(
                  l10n.viewAll,
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
        if (loading)
          const Padding(
            padding: EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (historyAsync.hasError)
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.couldNotLoadHistory,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: MuzhirColors.mutedGrey,
                      ),
                ),
                TextButton(
                  onPressed: () => ref.invalidate(scanHistoryProvider),
                  child: Text(l10n.retry),
                ),
              ],
            ),
          )
        else if (recentScans.isEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              l10n.noRecentScans,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: MuzhirColors.mutedGrey,
                  ),
            ),
          )
        else
          for (final scan in recentScans)
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
              child: RecentScanTile(
                scan: RecentScan(
                  plantName: isAr ? scan.cropNameAr : scan.cropName,
                  diseaseName: _localizedDiagnosisLabel(scan, l10n),
                  confidencePercent: scan.confidencePercentDisplay,
                  timeAgo: TranslationHelper.relativeScanTimeLabel(
                    context,
                    scan.createdAt,
                    l10n,
                  ),
                  source: ScanSource.mobile,
                  isHealthy: scan.isHealthy,
                  imageUrl: scan.imageUrl,
                ),
              ),
            ),
        const SizedBox(height: 100),
      ],
    );
  }
}
