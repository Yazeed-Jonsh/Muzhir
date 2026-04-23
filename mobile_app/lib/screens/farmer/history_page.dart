import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:muzhir/core/api/api_service.dart';
import 'package:muzhir/core/utils/network_url_helper.dart';
import 'package:muzhir/core/utils/translation_helper.dart';
import 'package:muzhir/l10n/app_localizations.dart';
import 'package:muzhir/models/scan_history_item.dart';
import 'package:muzhir/providers/scan_history_provider.dart';
import 'package:muzhir/screens/farmer/diagnosis_result_detail_screen.dart';
import 'package:muzhir/theme/app_theme.dart';

/// Scan history backed by `GET /api/v1/history` (authenticated user only).
class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key, this.onScanDeleted});

  final VoidCallback? onScanDeleted;

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  Future<void> _loadHistory() async {
    ref.invalidate(scanHistoryProvider);
    await ref.read(scanHistoryProvider.future);
  }

  String _diagnosisLabel(ScanHistoryItem item, AppLocalizations l10n) {
    final name = item.diseaseName?.trim();
    if (name != null && name.isNotEmpty) return name;
    if (item.status == 'pending' || item.status == 'processing') {
      return l10n.analysisInProgress;
    }
    return l10n.noDiagnosisYet;
  }

  String _relativeTimestamp(DateTime t, AppLocalizations l10n) {
    return TranslationHelper.relativeScanTimeLabel(context, t, l10n);
  }

  String _messageFromDioException(DioException e, AppLocalizations l10n) {
    final data = e.response?.data;
    if (data is Map && data['detail'] != null) {
      final d = data['detail'];
      if (d is String) return d;
      if (d is List && d.isNotEmpty) return d.first.toString();
    }
    return e.message ?? l10n.couldNotLoadScan;
  }

  Future<bool> _confirmDeleteScan(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            l10n.deleteScan,
            style: GoogleFonts.lexend(fontWeight: FontWeight.w700),
          ),
          content: Text(
            l10n.deleteScanConfirm,
            style: GoogleFonts.lexend(fontWeight: FontWeight.w500),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                l10n.cancel,
                style: GoogleFonts.lexend(
                  fontWeight: FontWeight.w600,
                  color: MuzhirColors.mutedGrey,
                ),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: MuzhirColors.earthyClayRed,
                foregroundColor: MuzhirColors.cardWhite,
              ),
              child: Text(
                l10n.delete,
                style: GoogleFonts.lexend(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
    return confirmed == true;
  }

  Future<bool> _deleteScanFromHistory(
    BuildContext context,
    ScanHistoryItem item,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final shouldDelete = await _confirmDeleteScan(context);
    if (!shouldDelete) return false;

    try {
      await ApiService().deleteScan(item.scanId);
    } on DioException catch (e) {
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsetsDirectional.all(16),
          backgroundColor: MuzhirColors.earthyClayRed,
          content: Text(
            _messageFromDioException(e, l10n),
            style: GoogleFonts.lexend(
              color: MuzhirColors.cardWhite,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
      return false;
    } catch (e) {
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsetsDirectional.all(16),
          backgroundColor: MuzhirColors.earthyClayRed,
          content: Text(
            l10n.couldNotDeleteScan(e.toString()),
            style: GoogleFonts.lexend(
              color: MuzhirColors.cardWhite,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
      return false;
    }

    if (!context.mounted) return false;
    ref.invalidate(scanHistoryProvider);
    await ref.read(scanHistoryProvider.future);
    if (!context.mounted) return false;
    widget.onScanDeleted?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsetsDirectional.all(16),
        backgroundColor: MuzhirColors.forestGreen,
        content: Text(
          l10n.scanRemovedSuccessfully,
          style: GoogleFonts.lexend(
            color: MuzhirColors.cardWhite,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
    return true;
  }

  Future<void> _openDiagnosisDetail(
    BuildContext context,
    ScanHistoryItem item,
  ) async {
    final navigator = Navigator.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isAr = Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: MuzhirColors.forestGreen.withValues(alpha: 0.85),
        ),
      ),
    );
    try {
      final diagnosis = await ApiService().getScanDiagnosis(item.scanId);
      navigator.pop();
      if (!context.mounted) return;
      final deleted = await navigator.push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => DiagnosisResultDetailScreen(
            diagnosis: diagnosis,
            cropType: isAr ? item.cropNameAr : item.cropName,
          ),
        ),
      );
      if (!context.mounted || deleted != true) return;
      ref.invalidate(scanHistoryProvider);
      await ref.read(scanHistoryProvider.future);
      if (!context.mounted) return;
      widget.onScanDeleted?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsetsDirectional.all(16),
          backgroundColor: MuzhirColors.forestGreen,
          content: Text(
            l10n.scanRemovedSuccessfully,
            style: GoogleFonts.lexend(
              color: MuzhirColors.cardWhite,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    } on DioException catch (e) {
      if (context.mounted) {
        navigator.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsetsDirectional.all(16),
            backgroundColor: MuzhirColors.earthyClayRed,
            content: Text(
              _messageFromDioException(e, l10n),
              style: GoogleFonts.lexend(
                color: MuzhirColors.cardWhite,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        navigator.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsetsDirectional.all(16),
            backgroundColor: MuzhirColors.earthyClayRed,
            content: Text(
              l10n.couldNotOpenScan(e.toString()),
              style: GoogleFonts.lexend(
                color: MuzhirColors.cardWhite,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(scanHistoryProvider);
    final l10n = AppLocalizations.of(context)!;
    final isAr = Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    return ColoredBox(
      color: MuzhirColors.creamScaffold,
      child: historyAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: MuzhirColors.forestGreen.withValues(alpha: 0.85),
          ),
        ),
        error: (e, _) => _buildErrorState(context, e.toString()),
        data: (items) {
          if (items.isEmpty) {
            return _buildEmptyState(context);
          }
          return RefreshIndicator(
            color: MuzhirColors.forestGreen,
            onRefresh: _loadHistory,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 100),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final label = _diagnosisLabel(item, l10n);
                return Padding(
                  padding: const EdgeInsetsDirectional.only(bottom: 16),
                  child: Dismissible(
                    key: ValueKey<String>(item.scanId),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      decoration: BoxDecoration(
                        color: MuzhirColors.earthyClayRed,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      alignment: AlignmentDirectional.centerEnd,
                      padding: const EdgeInsetsDirectional.symmetric(horizontal: 22),
                      child: const Icon(
                        Icons.delete_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    confirmDismiss: (_) => _deleteScanFromHistory(context, item),
                    child: _HistoryListTile(
                      item: item,
                      cropName: isAr ? item.cropNameAr : item.cropName,
                      diagnosisLabel: label,
                      timeLabel: _relativeTimestamp(item.createdAt, l10n),
                      confidencePercent: item.confidencePercentDisplay,
                      isHealthy: item.isHealthy,
                      onTap: () => _openDiagnosisDetail(context, item),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String errorMessage) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 56,
              color: MuzhirColors.mutedGrey.withValues(alpha: 0.85),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.couldNotLoadHistory,
              textAlign: TextAlign.center,
              style: GoogleFonts.lexend(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: MuzhirColors.titleCharcoal,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: GoogleFonts.lexend(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: MuzhirColors.mutedGrey,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _loadHistory,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: Text(
                l10n.retry,
                style: GoogleFonts.lexend(fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: MuzhirColors.forestGreen,
                foregroundColor: MuzhirColors.cardWhite,
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_rounded,
              size: 72,
              color: MuzhirColors.coreLeafGreen.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.noScanHistoryYet,
              textAlign: TextAlign.center,
              style: GoogleFonts.lexend(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: MuzhirColors.titleCharcoal,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.historyEmptyDescription,
              textAlign: TextAlign.center,
              style: GoogleFonts.lexend(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: MuzhirColors.deepCharcoal.withValues(alpha: 0.6),
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryListTile extends StatelessWidget {
  const _HistoryListTile({
    required this.item,
    required this.cropName,
    required this.diagnosisLabel,
    required this.timeLabel,
    this.confidencePercent,
    required this.isHealthy,
    required this.onTap,
  });

  final ScanHistoryItem item;
  final String cropName;
  final String diagnosisLabel;
  final String timeLabel;
  /// Whole percent from API; null hides the badge.
  final int? confidencePercent;
  final bool isHealthy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = isHealthy
        ? MuzhirColors.coreLeafGreen
        : MuzhirColors.infectionSeriousOrange;
    final url = NetworkUrlHelper.normalizeRemoteUrl(item.imageUrl);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsetsDirectional.all(14),
          decoration: BoxDecoration(
            color: MuzhirColors.cardWhite,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: MuzhirColors.titleCharcoal.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: url.isEmpty
                      ? ColoredBox(
                          color: MuzhirColors.weatherIconCircle
                              .withValues(alpha: 0.65),
                          child: Icon(
                            Icons.local_florist_rounded,
                            color: MuzhirColors.forestGreen.withValues(alpha: 0.85),
                            size: 28,
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => ColoredBox(
                            color: MuzhirColors.weatherIconCircle
                                .withValues(alpha: 0.5),
                            child: Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: MuzhirColors.forestGreen
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                          ),
                          errorWidget: (_, imageUrl, error) {
                            debugPrint(
                              '[IMG_ERR] HistoryPage | $imageUrl | $error',
                            );
                            return ColoredBox(
                              color: MuzhirColors.weatherIconCircle
                                  .withValues(alpha: 0.65),
                              child: const Icon(
                                Icons.broken_image_outlined,
                                color: MuzhirColors.mutedGrey,
                                size: 26,
                              ),
                            );
                          },
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      TranslationHelper.getLocalizedText(context, cropName),
                      style: GoogleFonts.lexend(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: MuzhirColors.titleCharcoal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      TranslationHelper.getLocalizedText(context, diagnosisLabel),
                      style: GoogleFonts.lexend(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeLabel,
                      style: GoogleFonts.lexend(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: MuzhirColors.mutedGrey,
                      ),
                    ),
                  ],
                ),
              ),
              if (confidencePercent != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$confidencePercent%',
                    style: GoogleFonts.lexend(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: MuzhirColors.mutedGrey,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
