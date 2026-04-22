import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart'
    show StateNotifier, StateNotifierProvider;

import 'package:muzhir/services/inference_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────

sealed class InferenceState {
  const InferenceState();
}

/// No inference has been requested yet (or state was reset).
class InferenceIdle extends InferenceState {
  const InferenceIdle();
}

/// Model is loading or inference is running.
class InferenceLoading extends InferenceState {
  const InferenceLoading();
}

/// Inference completed successfully.
class InferenceSuccess extends InferenceState {
  const InferenceSuccess(this.result);

  final OnDeviceResult result;
}

/// Inference failed with an error.
class InferenceFailure extends InferenceState {
  const InferenceFailure(this.message);

  final String message;
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

class InferenceNotifier extends StateNotifier<InferenceState> {
  InferenceNotifier() : super(const InferenceIdle());

  /// Runs on-device inference on [imageFile] and updates state accordingly.
  Future<void> runInference(File imageFile) async {
    state = const InferenceLoading();
    try {
      final result = await InferenceService.instance.runInference(imageFile);
      state = InferenceSuccess(result);
    } catch (e, st) {
      state = InferenceFailure('On-device inference failed: $e\n$st');
    }
  }

  /// Resets to [InferenceIdle] — call when the user picks a new image or
  /// navigates away.
  void reset() => state = const InferenceIdle();
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

/// Global provider for on-device YOLO26n inference state.
///
/// Expose through [ProviderScope] at the app root (already present in
/// `main.dart`). Widgets watch this provider to react to loading / result /
/// error states without holding inference state themselves.
final inferenceProvider =
    StateNotifierProvider<InferenceNotifier, InferenceState>(
  (ref) => InferenceNotifier(),
);
