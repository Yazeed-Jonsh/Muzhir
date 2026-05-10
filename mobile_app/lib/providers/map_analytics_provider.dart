import 'package:flutter_riverpod/flutter_riverpod.dart';

enum MapTimePreset { last24Hours, last7Days, last30Days }

class MapAnalyticsState {
  const MapAnalyticsState({
    this.timePreset = MapTimePreset.last7Days,
    this.showHeatmap = false,
    this.compareWithPreviousWindow = false,
    this.comparisonSlider = 0.5,
    this.selectedDiseaseName,
    this.fakeModeEnabled = false,
    this.fakeTapInsertEnabled = false,
  });

  final MapTimePreset timePreset;
  final bool showHeatmap;
  final bool compareWithPreviousWindow;
  final double comparisonSlider;
  final String? selectedDiseaseName;
  final bool fakeModeEnabled;
  final bool fakeTapInsertEnabled;

  MapAnalyticsState copyWith({
    MapTimePreset? timePreset,
    bool? showHeatmap,
    bool? compareWithPreviousWindow,
    double? comparisonSlider,
    String? selectedDiseaseName,
    bool? fakeModeEnabled,
    bool? fakeTapInsertEnabled,
    bool clearDisease = false,
  }) {
    return MapAnalyticsState(
      timePreset: timePreset ?? this.timePreset,
      showHeatmap: showHeatmap ?? this.showHeatmap,
      compareWithPreviousWindow:
          compareWithPreviousWindow ?? this.compareWithPreviousWindow,
      comparisonSlider: comparisonSlider ?? this.comparisonSlider,
      selectedDiseaseName:
          clearDisease ? null : (selectedDiseaseName ?? this.selectedDiseaseName),
      fakeModeEnabled: fakeModeEnabled ?? this.fakeModeEnabled,
      fakeTapInsertEnabled: fakeTapInsertEnabled ?? this.fakeTapInsertEnabled,
    );
  }
}

class MapAnalyticsNotifier extends StateNotifier<MapAnalyticsState> {
  MapAnalyticsNotifier() : super(const MapAnalyticsState());

  void setTimePreset(MapTimePreset preset) {
    state = state.copyWith(timePreset: preset);
  }

  void setShowHeatmap(bool value) {
    state = state.copyWith(showHeatmap: value);
    if (!value) {
      state = state.copyWith(compareWithPreviousWindow: false);
    }
  }

  void setFakeModeEnabled(bool value) {
    state = state.copyWith(fakeModeEnabled: value);
    if (!value) {
      state = state.copyWith(fakeTapInsertEnabled: false);
    }
  }

  void setFakeTapInsertEnabled(bool value) {
    if (!state.fakeModeEnabled) return;
    state = state.copyWith(fakeTapInsertEnabled: value);
  }

  void setCompareWithPreviousWindow(bool value) {
    state = state.copyWith(compareWithPreviousWindow: value);
  }

  void setComparisonSlider(double value) {
    state = state.copyWith(comparisonSlider: value.clamp(0.0, 1.0));
  }

  void setSelectedDiseaseName(String? value) {
    if (value == null || value.trim().isEmpty) {
      state = state.copyWith(clearDisease: true);
      return;
    }
    state = state.copyWith(selectedDiseaseName: value.trim());
  }
}

final mapAnalyticsProvider =
    StateNotifierProvider<MapAnalyticsNotifier, MapAnalyticsState>(
  (ref) => MapAnalyticsNotifier(),
);
