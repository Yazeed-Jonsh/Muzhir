import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:muzhir/core/api/api_service.dart';
import 'package:muzhir/models/scan_history_item.dart';
import 'package:muzhir/screens/farmer/diagnosis_result_detail_screen.dart';
import 'package:muzhir/theme/app_theme.dart';

/// Scan history backed by `GET /api/v1/history` (authenticated user only).
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  bool _loading = true;
  String? _error;
  List<ScanHistoryItem> _items = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ApiService().getScanHistory();
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  String _diagnosisLabel(ScanHistoryItem item) {
    final name = item.diseaseName?.trim();
    if (name != null && name.isNotEmpty) return name;
    if (item.status == 'pending' || item.status == 'processing') {
      return 'Analysis in progress';
    }
    return 'No diagnosis yet';
  }

  String _relativeTimestamp(DateTime t) {
    final now = DateTime.now();
    final d = now.difference(t);
    if (d.isNegative) return 'Just now';
    if (d.inSeconds < 45) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} hours ago';
    if (d.inDays < 7) return '${d.inDays} days ago';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[t.month - 1]} ${t.day}, ${t.year}';
  }

  bool _isHealthyLabel(String label) {
    final l = label.toLowerCase();
    return l.contains('healthy') ||
        l.contains('no disease') ||
        l.contains('no disease detected');
  }

  String _messageFromDioException(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['detail'] != null) {
      final d = data['detail'];
      if (d is String) return d;
      if (d is List && d.isNotEmpty) return d.first.toString();
    }
    return e.message ?? 'Could not load scan details.';
  }

  Future<void> _openDiagnosisDetail(
    BuildContext context,
    ScanHistoryItem item,
  ) async {
    final navigator = Navigator.of(context);
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
      await navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => DiagnosisResultDetailScreen(
            diagnosis: diagnosis,
            cropType: item.cropName,
          ),
        ),
      );
    } on DioException catch (e) {
      if (context.mounted) {
        navigator.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            backgroundColor: MuzhirColors.earthyClayRed,
            content: Text(
              _messageFromDioException(e),
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
            margin: const EdgeInsets.all(16),
            backgroundColor: MuzhirColors.earthyClayRed,
            content: Text(
              'Could not open scan: $e',
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
    return ColoredBox(
      color: MuzhirColors.creamScaffold,
      child: _loading
          ? Center(
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: MuzhirColors.forestGreen.withValues(alpha: 0.85),
              ),
            )
          : _error != null
              ? _buildErrorState(context)
              : _items.isEmpty
                  ? _buildEmptyState(context)
                  : RefreshIndicator(
                      color: MuzhirColors.forestGreen,
                      onRefresh: _loadHistory,
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          final label = _diagnosisLabel(item);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _HistoryListTile(
                              item: item,
                              diagnosisLabel: label,
                              timeLabel: _relativeTimestamp(item.createdAt),
                              isHealthy: _isHealthyLabel(label),
                              onTap: () => _openDiagnosisDetail(context, item),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
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
              'Could not load history',
              textAlign: TextAlign.center,
              style: GoogleFonts.lexend(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: MuzhirColors.titleCharcoal,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
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
                'Retry',
                style: GoogleFonts.lexend(fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: MuzhirColors.forestGreen,
                foregroundColor: MuzhirColors.cardWhite,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
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
              'No scan history yet',
              textAlign: TextAlign.center,
              style: GoogleFonts.lexend(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: MuzhirColors.titleCharcoal,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Your completed diagnoses will show up here. Open the Diagnose tab to analyze a plant.',
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
    required this.diagnosisLabel,
    required this.timeLabel,
    required this.isHealthy,
    required this.onTap,
  });

  final ScanHistoryItem item;
  final String diagnosisLabel;
  final String timeLabel;
  final bool isHealthy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = isHealthy
        ? MuzhirColors.coreLeafGreen
        : MuzhirColors.infectionSeriousOrange;
    final url = item.imageUrl.trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(14),
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
                          errorWidget: (_, __, ___) => ColoredBox(
                            color: MuzhirColors.weatherIconCircle
                                .withValues(alpha: 0.65),
                            child: const Icon(
                              Icons.broken_image_outlined,
                              color: MuzhirColors.mutedGrey,
                              size: 26,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.cropName,
                      style: GoogleFonts.lexend(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: MuzhirColors.titleCharcoal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      diagnosisLabel,
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
