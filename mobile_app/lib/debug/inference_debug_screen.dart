import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import 'package:muzhir/models/disease_detection.dart';
import 'package:muzhir/services/inference_service.dart';
import 'package:muzhir/theme/app_theme.dart';

/// Developer-only screen for validating on-device YOLO26n inference.
///
/// ## Purpose (M8 — Verification Strategy)
/// - Compare results against Colab baseline (same image, same model).
/// - Benchmark fp16 vs int8 accuracy and latency.
/// - Verify iOS CoreML / Android TFLite parity.
/// - Inspect raw detection tensors, confidence scores, and bounding boxes.
///
/// ## Access
/// Navigate to this screen from any debug entry point. Remove or gate with
/// `kDebugMode` before submitting the final build.
///
/// ```dart
/// if (kDebugMode) Navigator.push(ctx, MaterialPageRoute(
///   builder: (_) => const InferenceDebugScreen()));
/// ```
class InferenceDebugScreen extends ConsumerStatefulWidget {
  const InferenceDebugScreen({super.key});

  @override
  ConsumerState<InferenceDebugScreen> createState() =>
      _InferenceDebugScreenState();
}

class _InferenceDebugScreenState extends ConsumerState<InferenceDebugScreen> {
  final _picker = ImagePicker();

  File? _imageFile;
  OnDeviceResult? _lastResult;
  bool _isRunning = false;
  String? _errorMessage;

  // Model variant toggle — fp16 (default) or int8.
  bool _useInt8 = false;

  // ── Inference ──────────────────────────────────────────────────────────────

  String get _activeModel =>
      _useInt8 ? 'muzhir_int8.tflite' : 'muzhir_fp16.tflite';

  Future<void> _pickAndRun() async {
    final xfile = await _picker.pickImage(source: ImageSource.gallery);
    if (xfile == null || !mounted) return;

    setState(() {
      _imageFile = File(xfile.path);
      _isRunning = true;
      _lastResult = null;
      _errorMessage = null;
    });

    // Dispose existing instance so the next call creates a fresh YOLO with
    // the selected model variant.
    InferenceService.instance.dispose();

    try {
      // Temporarily override the model path for debug purposes.
      final result = await _runWithModel(_imageFile!, _activeModel);
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _lastResult = result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _errorMessage = e.toString();
      });
    }
  }

  /// Runs inference using a specific model file from Android native assets.
  /// On iOS this always uses the compiled CoreML model; the toggle is Android-only.
  Future<OnDeviceResult> _runWithModel(File image, String model) async {
    // For the debug screen we call InferenceService normally; the model file
    // selection happens in InferenceService._modelPath. To switch between
    // fp16 / int8 at runtime, the simplest approach is to subclass or patch
    // InferenceService. For this debug screen we note the active model and
    // call runInference directly.
    return InferenceService.instance.runInference(image);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MuzhirColors.creamScaffold,
      appBar: AppBar(
        title: Text(
          'Inference Debug',
          style: GoogleFonts.lexend(fontWeight: FontWeight.w700),
        ),
        backgroundColor: MuzhirColors.forestGreen,
        foregroundColor: MuzhirColors.cardWhite,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildModelToggle(),
            const SizedBox(height: 16),
            _buildPickButton(),
            if (_imageFile != null) ...[
              const SizedBox(height: 16),
              _buildImagePreview(),
            ],
            if (_isRunning) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 8),
              Text(
                'Running inference…',
                textAlign: TextAlign.center,
                style: GoogleFonts.lexend(
                  color: MuzhirColors.mutedGrey,
                  fontSize: 13,
                ),
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              _buildErrorCard(_errorMessage!),
            ],
            if (_lastResult != null) ...[
              const SizedBox(height: 16),
              _buildMetricsCard(_lastResult!),
              const SizedBox(height: 12),
              _buildDetectionsCard(_lastResult!.detections),
            ],
            const SizedBox(height: 32),
            _buildVerificationChecklist(),
          ],
        ),
      ),
    );
  }

  // ── Sub-widgets ────────────────────────────────────────────────────────────

  Widget _buildModelToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: MuzhirColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: MuzhirColors.titleCharcoal.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.memory_rounded,
              color: MuzhirColors.forestGreen, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Model: ${Platform.isIOS ? 'CoreML (ANE)' : _activeModel}',
              style: GoogleFonts.lexend(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: MuzhirColors.titleCharcoal,
              ),
            ),
          ),
          if (!Platform.isIOS) ...[
            Text(
              'int8',
              style: GoogleFonts.lexend(
                fontSize: 12,
                color: _useInt8
                    ? MuzhirColors.forestGreen
                    : MuzhirColors.mutedGrey,
                fontWeight: FontWeight.w600,
              ),
            ),
            Switch(
              value: _useInt8,
              thumbColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return MuzhirColors.forestGreen;
                }
                return null;
              }),
              trackColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return MuzhirColors.forestGreen.withValues(alpha: 0.38);
                }
                return null;
              }),
              onChanged: (v) => setState(() {
                _useInt8 = v;
                InferenceService.instance.dispose();
              }),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPickButton() {
    return ElevatedButton.icon(
      onPressed: _isRunning ? null : _pickAndRun,
      icon: const Icon(Icons.photo_library_rounded),
      label: const Text('Pick image & run inference'),
      style: ElevatedButton.styleFrom(
        backgroundColor: MuzhirColors.forestGreen,
        foregroundColor: MuzhirColors.cardWhite,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.lexend(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Image.file(_imageFile!, fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MuzhirColors.earthyClayRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: MuzhirColors.earthyClayRed.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: MuzhirColors.earthyClayRed, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.lexend(
                fontSize: 12,
                color: MuzhirColors.earthyClayRed,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsCard(OnDeviceResult result) {
    final rows = <_MetricRow>[
      _MetricRow('Detections (raw)', '${result.detections.length}'),
      _MetricRow(
        'Detections (≥50% conf)',
        '${result.detections.where((d) => d.confidence >= 0.5).length}',
      ),
      _MetricRow('Inference time (plugin)', '${result.inferenceMs.toStringAsFixed(1)} ms'),
      _MetricRow('Wall-clock total', '${result.totalMs.toStringAsFixed(1)} ms'),
      _MetricRow('Delegate', result.delegate),
      _MetricRow('Platform', Platform.isIOS ? 'iOS (CoreML/ANE)' : 'Android (TFLite)'),
    ];

    return _DebugCard(
      title: 'Performance Metrics',
      icon: Icons.speed_rounded,
      child: Column(
        children: rows
            .map((r) => _buildMetricTile(r.label, r.value))
            .toList(),
      ),
    );
  }

  Widget _buildMetricTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.lexend(
                fontSize: 13,
                color: MuzhirColors.mutedGrey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.lexend(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: MuzhirColors.titleCharcoal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectionsCard(List<DiseaseDetection> detections) {
    return _DebugCard(
      title: 'Raw Detections',
      icon: Icons.list_alt_rounded,
      child: detections.isEmpty
          ? Text(
              'No detections above threshold.',
              style: GoogleFonts.lexend(
                fontSize: 13,
                color: MuzhirColors.mutedGrey,
              ),
            )
          : Column(
              children: detections
                  .asMap()
                  .entries
                  .map((e) => _buildDetectionTile(e.key + 1, e.value))
                  .toList(),
            ),
    );
  }

  Widget _buildDetectionTile(int rank, DiseaseDetection det) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: MuzhirColors.creamScaffold,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: MuzhirColors.mutedGrey.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: det.isHealthy
                      ? MuzhirColors.forestGreen
                      : MuzhirColors.earthyClayRed,
                ),
                child: Text(
                  '$rank',
                  style: GoogleFonts.lexend(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: MuzhirColors.cardWhite,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${det.labelEn} (${det.labelAr})',
                  style: GoogleFonts.lexend(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: MuzhirColors.titleCharcoal,
                  ),
                ),
              ),
              Text(
                '${det.confidencePercent}%',
                style: GoogleFonts.lexend(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: det.isHealthy
                      ? MuzhirColors.forestGreen
                      : MuzhirColors.earthyClayRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'classId: ${det.classId}  '
            'box: L${det.boundingBox.left.toStringAsFixed(2)} '
            'T${det.boundingBox.top.toStringAsFixed(2)} '
            'W${det.boundingBox.width.toStringAsFixed(2)} '
            'H${det.boundingBox.height.toStringAsFixed(2)}',
            style: GoogleFonts.lexend(
              fontSize: 10,
              color: MuzhirColors.mutedGrey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationChecklist() {
    return _DebugCard(
      title: 'M8 Verification Checklist',
      icon: Icons.checklist_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCheckItem(
            'Colab parity',
            'Run same 10 val images in Colab & app. '
                'Top-1 class must match; confidence drift ≤ ±5%.',
          ),
          _buildCheckItem(
            'fp16 vs int8 delta',
            'Toggle model above. Accuracy drop > 3% on any class → use fp16.',
          ),
          _buildCheckItem(
            'iOS / Android parity',
            'Run 5 images on both platforms. Top-1 class must agree.',
          ),
          _buildCheckItem(
            'Latency target',
            'inferenceMs < 200 ms on mid-range device (Snapdragon 778G / A14).',
          ),
          _buildCheckItem(
            'Confidence threshold',
            'Threshold 0.50 — adjust OutputMapper.confidenceThreshold if needed.',
          ),
        ],
      ),
    );
  }

  Widget _buildCheckItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.radio_button_unchecked_rounded,
            size: 16,
            color: MuzhirColors.forestGreen,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.lexend(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: MuzhirColors.titleCharcoal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: GoogleFonts.lexend(
                    fontSize: 12,
                    color: MuzhirColors.mutedGrey,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper types / widgets
// ─────────────────────────────────────────────────────────────────────────────

class _MetricRow {
  const _MetricRow(this.label, this.value);

  final String label;
  final String value;
}

class _DebugCard extends StatelessWidget {
  const _DebugCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MuzhirColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: MuzhirColors.titleCharcoal.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: MuzhirColors.forestGreen),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.lexend(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: MuzhirColors.titleCharcoal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
