import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:muzhir/core/api/api_service.dart';
import 'package:muzhir/models/diagnosis_response.dart';
import 'package:muzhir/theme/app_theme.dart';
import 'package:muzhir/widgets/diagnosis_result_card.dart';
import 'package:muzhir/widgets/recent_scan_tile.dart';
import 'package:muzhir/widgets/treatment_advice_dialog.dart';

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

  @override
  void initState() {
    super.initState();
    if (widget.diagnosis != null) {
      _resolved = widget.diagnosis;
    } else {
      _loadFromApi();
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
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _messageFromDio(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  String _messageFromDio(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['detail'] != null) {
      final d = data['detail'];
      if (d is String) return d;
      if (d is List && d.isNotEmpty) return d.first.toString();
    }
    return e.message ?? 'Could not load scan.';
  }

  String? _activeScanId() {
    final id = (widget.scanId ?? _resolved?.scanId ?? '').trim();
    return id.isEmpty ? null : id;
  }

  Future<bool> _confirmDeleteScan() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            'Delete scan',
            style: GoogleFonts.lexend(fontWeight: FontWeight.w700),
          ),
          content: Text(
            'Are you sure you want to delete this scan?',
            style: GoogleFonts.lexend(fontWeight: FontWeight.w500),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancel',
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
                'Delete',
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
          margin: const EdgeInsets.all(16),
          backgroundColor: MuzhirColors.earthyClayRed,
          content: Text(
            _messageFromDio(e),
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
          margin: const EdgeInsets.all(16),
          backgroundColor: MuzhirColors.earthyClayRed,
          content: Text(
            'Could not delete scan: $e',
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
    final canDelete = _activeScanId() != null;
    return AppBar(
      title: Text(
        'Diagnosis',
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
          tooltip: 'Delete scan',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
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
            padding: const EdgeInsets.all(24),
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
                  child: const Text('Retry'),
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
        body: const Center(child: Text('No diagnosis data.')),
      );
    }

    final d = diagnosis.diagnosis;
    final confidencePct = (d.confidence * 100).round().clamp(0, 100);
    final isHealthy = d.isHealthy;
    final isAr =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';

    return Scaffold(
      backgroundColor: MuzhirColors.creamScaffold,
      appBar: _buildAppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          DiagnosisResultCard(
            cropType: widget.cropType,
            diseaseName: d.label,
            confidencePercent: confidencePct,
            source: widget.source,
            isHealthy: d.isHealthy,
            latitude: diagnosis.latitude,
            longitude: diagnosis.longitude,
          ),
          if (!isHealthy) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () =>
                    presentTreatmentAdviceDialog(context, diagnosis),
                icon: const Icon(Icons.lightbulb_outline_rounded),
                label: Text(
                  isAr ? 'عرض نصائح العلاج' : 'Get Treatment Advice',
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                isAr
                    ? 'نباتك بصحة جيدة! لا حاجة للعلاج.'
                    : 'Your plant is healthy! No treatment needed.',
                textAlign: TextAlign.center,
                textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
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
