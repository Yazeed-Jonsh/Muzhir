import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:muzhir/core/api/api_service.dart';
import 'package:muzhir/core/session/treatment_advice_visibility.dart';
import 'package:muzhir/l10n/app_localizations.dart';
import 'package:muzhir/models/diagnosis_response.dart';
import 'package:muzhir/theme/app_theme.dart';
import 'package:muzhir/widgets/diagnosis_result_card.dart';
import 'package:muzhir/widgets/recent_scan_tile.dart';
import 'package:muzhir/widgets/treatment_recommendation_section.dart';

/// Full-screen review of a past diagnosis (same content as the Diagnose flow result step).
///
/// Pass [diagnosis] when you already have the payload, or pass [scanId] to load it via
/// [ApiService.getScanDiagnosis] (same pattern as History).
class DiagnosisResultDetailScreen extends StatefulWidget {
  DiagnosisResultDetailScreen({
    super.key,
    this.diagnosis,
    this.scanId,
    this.onDeleted,
    required this.cropType,
    this.source = ScanSource.mobile,
  }) : assert(
          (diagnosis != null && scanId == null) ||
              (diagnosis == null && (scanId?.isNotEmpty ?? false)),
        );

  final DiagnosisResponse? diagnosis;
  final String? scanId;
  final Future<void> Function()? onDeleted;
  final String cropType;
  final ScanSource source;

  @override
  State<DiagnosisResultDetailScreen> createState() =>
      _DiagnosisResultDetailScreenState();
}

class _DiagnosisResultDetailScreenState extends State<DiagnosisResultDetailScreen> {
  DiagnosisResponse? _resolved;
  bool _loading = false;
  bool _deleting = false;
  String? _error;
  /// AI recommendation panel visibility (synced with [TreatmentAdviceVisibility] when [scanId] exists).
  bool _isRecommendationVisible = false;

  String _scanIdForPersistence() {
    final id = (widget.scanId ?? _resolved?.scanId ?? widget.diagnosis?.scanId ?? '')
        .trim();
    return id;
  }

  void _syncVisibilityFromSession() {
    _isRecommendationVisible =
        TreatmentAdviceVisibility.isExpanded(_scanIdForPersistence());
  }

  @override
  void initState() {
    super.initState();
    if (widget.diagnosis != null) {
      _resolved = widget.diagnosis;
      _syncVisibilityFromSession();
    } else {
      _loadFromApi();
    }
  }

  @override
  void didUpdateWidget(covariant DiagnosisResultDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.scanId != oldWidget.scanId ||
        widget.diagnosis != oldWidget.diagnosis) {
      setState(_syncVisibilityFromSession);
    }
  }

  Future<void> _loadFromApi() async {
    final id = widget.scanId?.trim() ?? '';
    if (id.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await ApiService().getScanDiagnosis(id);
      if (!mounted) return;
      setState(() {
        _resolved = d;
        _loading = false;
        _syncVisibilityFromSession();
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _messageFromDio(e, AppLocalizations.of(context)!);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  String _messageFromDio(DioException e, AppLocalizations l10n) {
    final data = e.response?.data;
    if (data is Map && data['detail'] != null) {
      final d = data['detail'];
      if (d is String) return d;
      if (d is List && d.isNotEmpty) return d.first.toString();
    }
    return e.message ?? l10n.couldNotLoadScan;
  }

  String? _activeScanId() {
    final id = (widget.scanId ?? _resolved?.scanId ?? '').trim();
    return id.isEmpty ? null : id;
  }

  Future<bool> _confirmDeleteScan() async {
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

  Future<void> _onDeletePressed() async {
    final l10n = AppLocalizations.of(context)!;
    final scanId = _activeScanId();
    if (scanId == null || _deleting) return;
    final confirmed = await _confirmDeleteScan();
    if (!confirmed || !mounted) return;

    setState(() => _deleting = true);
    try {
      await ApiService().deleteScan(scanId);
      await widget.onDeleted?.call();
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsetsDirectional.all(16),
          backgroundColor: MuzhirColors.earthyClayRed,
          content: Text(
            _messageFromDio(e, l10n),
            style: GoogleFonts.lexend(
              color: MuzhirColors.cardWhite,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsetsDirectional.all(16),
          backgroundColor: MuzhirColors.earthyClayRed,
          content: Text(
            l10n.couldNotDeleteScan(e.toString()),
            style: GoogleFonts.lexend(
              color: MuzhirColors.cardWhite,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  AppBar _buildAppBar() {
    final l10n = AppLocalizations.of(context)!;
    final canDelete = _activeScanId() != null;
    return AppBar(
      title: Text(
        l10n.diagnosis,
        style: GoogleFonts.lexend(fontWeight: FontWeight.w700),
      ),
      actions: [
        IconButton(
          onPressed: (canDelete && !_deleting) ? _onDeletePressed : null,
          icon: _deleting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.delete_outline),
          color: MuzhirColors.earthyClayRed,
          tooltip: l10n.deleteScanTooltip,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_loading) {
      return Scaffold(
        backgroundColor: MuzhirColors.creamScaffold,
        appBar: _buildAppBar(),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: MuzhirColors.creamScaffold,
        appBar: _buildAppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsetsDirectional.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lexend(
                    fontSize: 15,
                    color: MuzhirColors.titleCharcoal,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _error = null;
                      _resolved = null;
                    });
                    _loadFromApi();
                  },
                  child: Text(l10n.retry),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final diagnosis = _resolved;
    if (diagnosis == null) {
      return Scaffold(
        backgroundColor: MuzhirColors.creamScaffold,
        appBar: _buildAppBar(),
        body: Center(child: Text(l10n.noDiagnosisData)),
      );
    }

    final d = diagnosis.diagnosis;
    final confidencePct = (d.confidence * 100).round().clamp(0, 100);
    final isHealthy = d.isHealthy;
    final isAr =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    final recommendationText = isAr
        ? diagnosis.recommendation.textAr
        : diagnosis.recommendation.textEn;

    return Scaffold(
      backgroundColor: MuzhirColors.creamScaffold,
      appBar: _buildAppBar(),
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 32),
        children: [
          DiagnosisResultCard(
            cropType: widget.cropType,
            diseaseName: d.label,
            diseaseNameAr: d.labelAr,
            confidencePercent: confidencePct,
            source: widget.source,
            isHealthy: d.isHealthy,
            latitude: diagnosis.latitude,
            longitude: diagnosis.longitude,
          ),
          if (!isHealthy) ...[
            if (recommendationText.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              TreatmentRecommendationSection(
                expanded: _isRecommendationVisible,
                onToggle: () {
                  final id = _scanIdForPersistence();
                  setState(() {
                    _isRecommendationVisible = !_isRecommendationVisible;
                    TreatmentAdviceVisibility.setExpanded(
                      id,
                      _isRecommendationVisible,
                    );
                  });
                },
                recommendationText: recommendationText,
              ),
            ],
          ] else ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
              child: Text(
                l10n.healthyNoTreatment,
                textAlign: TextAlign.center,
                style: GoogleFonts.lexend(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: MuzhirColors.coreLeafGreen,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
