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
    required this.cropType,
    this.source = ScanSource.mobile,
  }) : assert(
          (diagnosis != null && scanId == null) ||
              (diagnosis == null && (scanId?.isNotEmpty ?? false)),
        );

  final DiagnosisResponse? diagnosis;
  final String? scanId;
  final String cropType;
  final ScanSource source;

  @override
  State<DiagnosisResultDetailScreen> createState() =>
      _DiagnosisResultDetailScreenState();
}

class _DiagnosisResultDetailScreenState extends State<DiagnosisResultDetailScreen> {
  DiagnosisResponse? _resolved;
  bool _loading = false;
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: MuzhirColors.creamScaffold,
        appBar: AppBar(
          title: Text(
            'Diagnosis',
            style: GoogleFonts.lexend(fontWeight: FontWeight.w700),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: MuzhirColors.creamScaffold,
        appBar: AppBar(
          title: Text(
            'Diagnosis',
            style: GoogleFonts.lexend(fontWeight: FontWeight.w700),
          ),
        ),
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
        appBar: AppBar(
          title: Text(
            'Diagnosis',
            style: GoogleFonts.lexend(fontWeight: FontWeight.w700),
          ),
        ),
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
      appBar: AppBar(
        title: Text(
          'Diagnosis',
          style: GoogleFonts.lexend(fontWeight: FontWeight.w700),
        ),
      ),
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
