import 'dart:io';

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
    this.delegate = 'unknown',
  });

  /// Sorted (highest confidence first), filtered detections.
  final List<DiseaseDetection> detections;

  /// Native inference time reported by the YOLO plugin (ms).
  final double inferenceMs;

  /// Wall-clock time from bytes-ready to result-mapped (ms).
  final double totalMs;

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

  /// Whether `loadModel()` succeeded on this session.
  bool get isReady => _yolo != null;

  // ── Model path ─────────────────────────────────────────────────────────────

  String get _modelPath {
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
  Future<void> initialize() async {
    if (_yolo != null) return;

    // ultralytics_yolo 0.3.0: thresholds are not ctor args; we filter in
    // [OutputMapper] after [predict] (see confidenceThreshold there).
    final yolo = YOLO(
      modelPath: _modelPath,
      task: YOLOTask.detect,
      useGpu: true,
    );

    await yolo.loadModel();
    _yolo = yolo;
  }

  /// Disposes the current YOLO instance, allowing [initialize] to create a
  /// fresh one (e.g. when switching between fp16 / int8).
  void dispose() => _yolo = null;

  // ── Inference ───────────────────────────────────────────────────────────────

  /// Runs the full pipeline: init → preprocess → infer → map → sort.
  ///
  /// Always call this from the main Dart isolate. The native layer handles
  /// background threading; this method returns only when results are ready.
  Future<OnDeviceResult> runInference(File imageFile) async {
    await initialize();

    final sw = Stopwatch()..start();
    final imageBytes = await Preprocessor.prepareImageBytes(imageFile);

    final raw = await _yolo!.predict(imageBytes);
    final wallMs = sw.elapsed.inMilliseconds.toDouble();

    final labels = await LabelLoader.load();
    final rawBoxes = raw['boxes'] as List<dynamic>? ?? [];
    final detections = OutputMapper.map(rawBoxes, labels);

    return OnDeviceResult(
      detections: detections,
      inferenceMs: (raw['inferenceTime'] as num?)?.toDouble() ?? wallMs,
      totalMs: wallMs,
      delegate: raw['delegate'] as String? ?? 'unknown',
    );
  }
}
