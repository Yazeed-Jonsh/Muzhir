import 'dart:io';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:ultralytics_yolo/ultralytics_yolo.dart';

import 'package:muzhir/models/disease_detection.dart';
import 'package:muzhir/services/label_loader.dart';
import 'package:muzhir/services/output_mapper.dart';
import 'package:muzhir/services/preprocessor.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Result type
// ─────────────────────────────────────────────────────────────────────────────

/// Carries everything the UI (and debug screen) needs from one inference run.
class OnDeviceResult {
  const OnDeviceResult({
    required this.detections,
    required this.inferenceMs,
    required this.totalMs,
    required this.modelPath,
    required this.confidenceThreshold,
    required this.iouThreshold,
    required this.rawBoxCount,
    required this.inputBytesCount,
    required this.topRawPredictions,
    this.delegate = 'unknown',
  });

  /// Sorted (highest confidence first), filtered detections.
  final List<DiseaseDetection> detections;

  /// Native inference time reported by the YOLO plugin (ms).
  final double inferenceMs;

  /// Wall-clock time from bytes-ready to result-mapped (ms).
  final double totalMs;

  /// Model path actually loaded for this run.
  final String modelPath;

  /// Native confidence threshold passed to YOLO plugin.
  final double confidenceThreshold;

  /// Native IoU threshold passed to YOLO plugin.
  final double iouThreshold;

  /// Number of raw boxes returned by native inference before Dart filtering.
  final int rawBoxCount;

  /// Original image bytes length sent to plugin.
  final int inputBytesCount;

  /// Top raw predictions for quick parity debugging.
  final List<String> topRawPredictions;

  /// Hardware delegate actually used (e.g. "gpu", "nnapi", "cpu").
  final String delegate;

  bool get hasDetections => detections.isNotEmpty;

  DiseaseDetection? get topDetection =>
      detections.isEmpty ? null : detections.first;
}

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────

/// Lazily-initialised singleton wrapping the [YOLO] instance.
///
/// ## Threading
/// [YOLO] uses platform channels and must be called from the main Dart
/// isolate. However the native TFLite / CoreML inference runs on a background
/// thread inside the plugin, so awaiting [runInference] does NOT block the
/// Flutter UI thread.
///
/// ## iOS Setup (manual — M3)
/// The `.mlpackage` must be added directly to the Xcode Runner target so
/// Xcode can compile it into `.mlmodelc` at build time. The [modelPath] for
/// iOS is therefore just the bare name `'muzhir_ios_coreml'` (no extension).
///
/// ## Android Setup
/// The `.tflite` is placed in `android/app/src/main/assets/` (M2) so the
/// plugin's native Kotlin layer can open it via [AssetManager]. The
/// [modelPath] for Android is therefore just `'muzhir_fp16.tflite'`.
class InferenceService {
  InferenceService._();

  static final InferenceService instance = InferenceService._();

  YOLO? _yolo;
  String? _loadedModelPath;

  /// Whether `loadModel()` succeeded on this session.
  bool get isReady => _yolo != null;

  // ── Model path ─────────────────────────────────────────────────────────────

  String get _defaultModelPath {
    if (Platform.isIOS) {
      // CoreML model compiled by Xcode from muzhir_ios_coreml.mlpackage.
      // CoreML resolves the name to the .mlmodelc bundle inside the app.
      return 'muzhir_ios_coreml';
    }
    // Android: file lives in android/app/src/main/assets/
    return 'muzhir_fp16.tflite';
  }

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  /// Loads the model if not already loaded. Idempotent — safe to call
  /// multiple times. Throws on unrecoverable errors (missing file, etc.).
  Future<void> initialize({String? modelPath}) async {
    final resolvedModelPath = modelPath ?? _defaultModelPath;
    if (_yolo != null && _loadedModelPath == resolvedModelPath) return;

    // Keep native threshold aligned with OutputMapper to avoid confusing cases
    // where native returns weak boxes that are later dropped by Dart filtering.
    final yolo = YOLO(
      modelPath: resolvedModelPath,
      task: YOLOTask.detect,
      useGpu: false,
    );

    await yolo.loadModel();
    _yolo = yolo;
    _loadedModelPath = resolvedModelPath;
  }

  /// Disposes the current YOLO instance, allowing [initialize] to create a
  /// fresh one (e.g. when switching between fp16 / int8).
  void dispose() {
    _yolo = null;
    _loadedModelPath = null;
  }

  // ── Inference ───────────────────────────────────────────────────────────────

  /// Runs the full pipeline: init → preprocess → infer → map → sort.
  ///
  /// Always call this from the main Dart isolate. The native layer handles
  /// background threading; this method returns only when results are ready.
  Future<OnDeviceResult> runInference(
    File imageFile, {
    String? modelPath,
    double confidenceThreshold = 0.25,
    double iouThreshold = 0.7,
  }) async {
    await initialize(modelPath: modelPath);

    final sw = Stopwatch()..start();
    final imageBytes = await Preprocessor.prepareImageBytes(imageFile);

    final raw = await _yolo!.predict(
      imageBytes,
      confidenceThreshold: confidenceThreshold,
      iouThreshold: iouThreshold,
    );
    final wallMs = sw.elapsed.inMilliseconds.toDouble();

    final labels = await LabelLoader.load();
    final rawBoxes = raw['boxes'] as List<dynamic>? ?? [];
    final detections = OutputMapper.map(rawBoxes, labels);
    final topRawPredictions = _extractTopRawPredictions(rawBoxes, limit: 5);
    final resolvedModelPath = modelPath ?? _defaultModelPath;

    _logEvidence(
      modelPath: resolvedModelPath,
      delegate: raw['delegate'] as String? ?? 'unknown',
      confidenceThreshold: confidenceThreshold,
      iouThreshold: iouThreshold,
      rawBoxCount: rawBoxes.length,
      mappedCount: detections.length,
      inputBytesCount: imageBytes.lengthInBytes,
      inferenceMs: (raw['inferenceTime'] as num?)?.toDouble() ?? wallMs,
      wallMs: wallMs,
      topRawPredictions: topRawPredictions,
    );

    return OnDeviceResult(
      detections: detections,
      inferenceMs: (raw['inferenceTime'] as num?)?.toDouble() ?? wallMs,
      totalMs: wallMs,
      modelPath: resolvedModelPath,
      confidenceThreshold: confidenceThreshold,
      iouThreshold: iouThreshold,
      rawBoxCount: rawBoxes.length,
      inputBytesCount: imageBytes.lengthInBytes,
      topRawPredictions: topRawPredictions,
      delegate: raw['delegate'] as String? ?? 'unknown',
    );
  }

  static List<String> _extractTopRawPredictions(
    List<dynamic> rawBoxes, {
    int limit = 5,
  }) {
    final rows = <_RawPrediction>[];
    for (final raw in rawBoxes) {
      if (raw is! Map) continue;
      final box = Map<dynamic, dynamic>.from(raw);
      final confidence = _readDouble(box['confidence']) ?? -1.0;
      if (confidence < 0) continue;
      final classId = _readInt(box['classIndex']) ??
          _readInt(box['class']) ??
          _readInt(box['id']);
      final className =
          box['className']?.toString() ?? box['class']?.toString();
      rows.add(
        _RawPrediction(
            classId: classId, className: className, confidence: confidence),
      );
    }
    rows.sort((a, b) => b.confidence.compareTo(a.confidence));
    return rows
        .take(limit)
        .map(
          (r) => '[cls:${r.classId ?? "?"}] ${r.className ?? "unknown"} '
              '${(r.confidence * 100).toStringAsFixed(2)}%',
        )
        .toList();
  }

  static int? _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static double? _readDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  static void _logEvidence({
    required String modelPath,
    required String delegate,
    required double confidenceThreshold,
    required double iouThreshold,
    required int rawBoxCount,
    required int mappedCount,
    required int inputBytesCount,
    required double inferenceMs,
    required double wallMs,
    required List<String> topRawPredictions,
  }) {
    final payload = <String, Object>{
      'event': 'on_device_inference',
      'modelPath': modelPath,
      'delegate': delegate,
      'confidenceThreshold': confidenceThreshold,
      'iouThreshold': iouThreshold,
      'rawBoxCount': rawBoxCount,
      'mappedDetections': mappedCount,
      'inputBytesCount': inputBytesCount,
      'inferenceMs': inferenceMs,
      'wallMs': wallMs,
      'topRawPredictions': topRawPredictions,
    };
    developer.log(jsonEncode(payload), name: 'InferenceEvidence');
  }
}

class _RawPrediction {
  const _RawPrediction({
    required this.classId,
    required this.className,
    required this.confidence,
  });

  final int? classId;
  final String? className;
  final double confidence;
}
