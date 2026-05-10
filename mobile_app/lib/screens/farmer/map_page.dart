import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:muzhir/core/api/api_service.dart';
import 'package:muzhir/core/utils/translation_helper.dart';
import 'package:muzhir/l10n/app_localizations.dart';
import 'package:muzhir/models/diagnosis_response.dart';
import 'package:muzhir/providers/connectivity_provider.dart';
import 'package:muzhir/providers/map_analytics_provider.dart';
import 'package:muzhir/providers/scan_history_provider.dart';
import 'package:muzhir/screens/farmer/diagnosis_result_detail_screen.dart';
import 'package:muzhir/services/pending_upload_store.dart';
import 'package:muzhir/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

enum _MapHealthFilter { all, infected, healthy }

/// Farmer Disease Map Page.
/// Displays an OpenStreetMap view with markers from [ApiService.getMapMarkers]
/// and the user's current position when available.
class MapPage extends ConsumerStatefulWidget {
  const MapPage({super.key, this.isTabVisible = false});

  /// When true, this tab is visible in the root [IndexedStack] (refresh location).
  final bool isTabVisible;

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> {
  /// Fallback center (Jeddah) while GPS is loading or unavailable.
  static const LatLng _defaultCenter = LatLng(21.5433, 39.1728);
  static const double _initialZoom = 11.0;
  /// Street-level zoom when centering on the user (My Location FAB & first GPS fix).
  static const double _userLocationZoom = 15.5;

  late final MapController _mapController;

  LatLng? _userLocation;
  bool _locationLoading = false;
  bool _didAutoCenterOnUser = false;

  List<DiagnosisResponse> _scanMarkers = [];
  List<DiagnosisResponse> _windowCurrentMarkers = [];
  List<DiagnosisResponse> _windowPreviousMarkers = [];
  List<FakeHeatmapPoint> _fakeHeatmapPoints = [];
  bool _markersLoading = true;
  String? _markersError;
  _MapHealthFilter _selectedHealthFilter = _MapHealthFilter.all;

  List<PendingUpload> _pendingUploads = [];
  bool _isDrainingQueue = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _loadMapMarkers(analyticsOverride: ref.read(mapAnalyticsProvider));
    _loadFakeHeatmapPoints();
    _loadPendingUploads();
    if (widget.isTabVisible) {
      _refreshUserLocation(autoCenterOnFirstFix: true);
    }
  }

  @override
  void didUpdateWidget(covariant MapPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTabVisible && !oldWidget.isTabVisible) {
      _refreshUserLocation(autoCenterOnFirstFix: !_didAutoCenterOnUser);
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  /// Pin color: green when healthy, red when diseased (design spec).
  Color _getMarkerColor(bool isHealthy) {
    return isHealthy ? MuzhirColors.coreLeafGreen : MuzhirColors.earthyClayRed;
  }

  Future<void> _loadMapMarkers({MapAnalyticsState? analyticsOverride}) async {
    final MapAnalyticsState analytics =
        analyticsOverride ?? ref.read(mapAnalyticsProvider);
    final currentWindow = _windowRange(
      previousWindow: false,
      analytics: analytics,
    );
    final previousWindow = _windowRange(
      previousWindow: true,
      analytics: analytics,
    );
    if (!mounted) return;
    setState(() {
      _markersLoading = true;
      _markersError = null;
      _scanMarkers = [];
      _windowCurrentMarkers = [];
      _windowPreviousMarkers = [];
    });
    try {
      final currentList = await ApiService().getMapMarkers(
        startAt: currentWindow.start,
        endAt: currentWindow.end,
      );
      final previousList = analytics.compareWithPreviousWindow
          ? await ApiService().getMapMarkers(
              startAt: previousWindow.start,
              endAt: previousWindow.end,
            )
          : const <DiagnosisResponse>[];
      final combined = <DiagnosisResponse>[
        ...currentList,
        ...previousList,
      ];
      // Persist for offline use.
      await PendingUploadStore.saveMarkers(
          combined.map((d) => d.toMap()).toList());
      if (!mounted) return;
      setState(() {
        _windowCurrentMarkers = currentList;
        _windowPreviousMarkers = previousList;
        _scanMarkers = combined;
        _markersLoading = false;
      });
      _fitAllMarkersVisible(currentList);
    } on DioException catch (e) {
      if (!mounted) return;
      final cached = await _loadCachedMarkers();
      if (!mounted) return;
      setState(() {
        _markersLoading = false;
        _markersError = cached.isEmpty ? _messageFromDio(e) : null;
        _scanMarkers = cached;
        _windowCurrentMarkers = cached;
        _windowPreviousMarkers = const [];
      });
      if (cached.isNotEmpty) _fitAllMarkersVisible();
    } catch (e) {
      if (!mounted) return;
      final cached = await _loadCachedMarkers();
      if (!mounted) return;
      setState(() {
        _markersLoading = false;
        _markersError = cached.isEmpty ? e.toString() : null;
        _scanMarkers = cached;
        _windowCurrentMarkers = cached;
        _windowPreviousMarkers = const [];
      });
      if (cached.isNotEmpty) _fitAllMarkersVisible();
    }
  }

  Future<List<DiagnosisResponse>> _loadCachedMarkers() async {
    final raw = await PendingUploadStore.loadMarkers();
    if (raw.isEmpty) return const [];
    final result = <DiagnosisResponse>[];
    for (final m in raw) {
      try {
        result.add(DiagnosisResponse.fromJson(m));
      } catch (_) {}
    }
    return result;
  }

  Future<void> _loadPendingUploads() async {
    final uploads = await PendingUploadStore.loadQueue();
    if (!mounted) return;
    setState(() => _pendingUploads = uploads);
  }

  Future<void> _loadFakeHeatmapPoints() async {
    final points = await PendingUploadStore.loadFakeHeatmapPoints();
    if (!mounted) return;
    setState(() => _fakeHeatmapPoints = points);
  }

  Future<void> _saveFakeHeatmapPoints() async {
    await PendingUploadStore.saveFakeHeatmapPoints(_fakeHeatmapPoints);
  }

  Future<void> _clearFakeHeatmapPoints() async {
    await PendingUploadStore.clearFakeHeatmapPoints();
    if (!mounted) return;
    setState(() => _fakeHeatmapPoints = []);
  }

  Future<void> _seedFakeSaudiHotspots() async {
    final now = DateTime.now().toUtc();
    final seeded = <FakeHeatmapPoint>[
      // Riyadh cluster
      FakeHeatmapPoint(
        latitude: 24.7136,
        longitude: 46.6753,
        diseaseName: 'Early blight',
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      FakeHeatmapPoint(
        latitude: 24.7202,
        longitude: 46.6827,
        diseaseName: 'Early blight',
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      FakeHeatmapPoint(
        latitude: 24.7064,
        longitude: 46.6681,
        diseaseName: 'Late blight',
        createdAt: now.subtract(const Duration(days: 6)),
      ),
      // Jeddah cluster
      FakeHeatmapPoint(
        latitude: 21.5433,
        longitude: 39.1728,
        diseaseName: 'Leaf spot',
        createdAt: now.subtract(const Duration(days: 4)),
      ),
      FakeHeatmapPoint(
        latitude: 21.5319,
        longitude: 39.1613,
        diseaseName: 'Leaf spot',
        createdAt: now.subtract(const Duration(days: 8)),
      ),
      FakeHeatmapPoint(
        latitude: 21.5537,
        longitude: 39.1829,
        diseaseName: 'Leaf spot',
        createdAt: now.subtract(const Duration(days: 10)),
      ),
      // Dammam cluster
      FakeHeatmapPoint(
        latitude: 26.4207,
        longitude: 50.0888,
        diseaseName: 'Rust',
        createdAt: now.subtract(const Duration(days: 3)),
      ),
      FakeHeatmapPoint(
        latitude: 26.4119,
        longitude: 50.1031,
        diseaseName: 'Rust',
        createdAt: now.subtract(const Duration(days: 11)),
      ),
      FakeHeatmapPoint(
        latitude: 26.4294,
        longitude: 50.0746,
        diseaseName: 'Rust',
        createdAt: now.subtract(const Duration(days: 15)),
      ),
    ];
    if (!mounted) return;
    setState(() => _fakeHeatmapPoints = seeded);
    await _saveFakeHeatmapPoints();
  }

  Future<void> _addFakePointFromTap(
    LatLng point,
    MapAnalyticsState analytics,
  ) async {
    final fallbackDisease = analytics.selectedDiseaseName ?? 'Early blight';
    final next = FakeHeatmapPoint(
      latitude: point.latitude,
      longitude: point.longitude,
      diseaseName: fallbackDisease,
      createdAt: DateTime.now().toUtc(),
    );
    if (!mounted) return;
    setState(() {
      _fakeHeatmapPoints = [..._fakeHeatmapPoints, next];
    });
    await _saveFakeHeatmapPoints();
  }

  /// Uploads all queued offline scans and refreshes markers on success.
  /// Each entry is removed from the queue regardless of outcome to avoid
  /// retrying permanently-broken items (e.g. deleted image files).
  Future<void> _drainPendingUploads() async {
    if (_isDrainingQueue || _pendingUploads.isEmpty) return;
    setState(() => _isDrainingQueue = true);
    try {
      final uploads = List<PendingUpload>.from(_pendingUploads);
      for (final upload in uploads) {
        try {
          await ApiService().uploadImageForDiagnosis(
            upload.imageFile,
            cropId: upload.cropId,
            overrideLatitude: upload.latitude,
            overrideLongitude: upload.longitude,
          );
        } catch (_) {
          // Remove from queue even on failure — avoids infinite retry loops.
        }
      }
      await PendingUploadStore.clearQueue();
      if (!mounted) return;
      setState(() => _pendingUploads = []);
      await _loadMapMarkers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsetsDirectional.all(16),
          backgroundColor: MuzhirColors.forestGreen,
          content: Text(
            AppLocalizations.of(context)!.offlineScansUploaded,
            style: GoogleFonts.lexend(
              color: MuzhirColors.cardWhite,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isDrainingQueue = false);
    }
  }

  String _messageFromDio(DioException e) {
    final l10n = AppLocalizations.of(context)!;
    final data = e.response?.data;
    if (data is Map && data['detail'] != null) {
      final d = data['detail'];
      if (d is String) return d;
      if (d is List && d.isNotEmpty) return d.first.toString();
    }
    return e.message ?? l10n.couldNotLoadMapMarkers;
  }

  void _onHealthFilterSelected(_MapHealthFilter filter) {
    if (filter == _selectedHealthFilter) return;
    setState(() => _selectedHealthFilter = filter);
  }

  String _healthFilterLabel(_MapHealthFilter filter, AppLocalizations l10n) {
    switch (filter) {
      case _MapHealthFilter.infected:
        return l10n.diseased;
      case _MapHealthFilter.healthy:
        return l10n.healthy;
      case _MapHealthFilter.all:
        return l10n.all;
    }
  }

  Widget _buildHealthFilterBar() {
    final l10n = AppLocalizations.of(context)!;
    const filters = _MapHealthFilter.values;
    return Material(
      color: MuzhirColors.creamScaffold,
      elevation: 1,
      shadowColor: MuzhirColors.deepCharcoal.withValues(alpha: 0.08),
      child: SizedBox(
        height: 52,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: filters.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final filter = filters[i];
            final selected = filter == _selectedHealthFilter;
            return ChoiceChip(
              label: Text(_healthFilterLabel(filter, l10n)),
              selected: selected,
              showCheckmark: false,
              onSelected: (value) {
                if (value) _onHealthFilterSelected(filter);
              },
              selectedColor: MuzhirColors.forestGreen,
              backgroundColor: MuzhirColors.cardWhite,
              side: BorderSide(
                color: selected
                    ? MuzhirColors.forestGreen
                    : MuzhirColors.deepCharcoal.withValues(alpha: 0.12),
              ),
              labelStyle: TextStyle(
                color: selected ? MuzhirColors.cardWhite : MuzhirColors.titleCharcoal,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            );
          },
        ),
      ),
    );
  }

  Duration _durationForPreset(MapTimePreset preset) {
    switch (preset) {
      case MapTimePreset.last24Hours:
        return const Duration(hours: 24);
      case MapTimePreset.last7Days:
        return const Duration(days: 7);
      case MapTimePreset.last30Days:
        return const Duration(days: 30);
    }
  }

  String _timePresetLabel(MapTimePreset preset, AppLocalizations l10n) {
    switch (preset) {
      case MapTimePreset.last24Hours:
        return l10n.last24h;
      case MapTimePreset.last7Days:
        return l10n.last7d;
      case MapTimePreset.last30Days:
        return l10n.last30d;
    }
  }

  DateTimeRange _windowRange({
    required bool previousWindow,
    required MapAnalyticsState analytics,
  }) {
    final now = DateTime.now().toUtc();
    final duration = _durationForPreset(analytics.timePreset);
    if (!previousWindow) {
      return DateTimeRange(start: now.subtract(duration), end: now);
    }
    final end = now.subtract(duration);
    return DateTimeRange(start: end.subtract(duration), end: end);
  }

  bool _matchesDiseaseFilter(DiagnosisResponse scan, MapAnalyticsState analytics) {
    final selected = analytics.selectedDiseaseName;
    if (selected == null || selected.isEmpty) return true;
    return scan.diagnosis.label.toLowerCase() == selected.toLowerCase();
  }

  List<DiagnosisResponse> _heatmapWindowPoints({
    required bool previousWindow,
    required MapAnalyticsState analytics,
  }) {
    final source = previousWindow ? _windowPreviousMarkers : _windowCurrentMarkers;
    return source.where((scan) {
      if (scan.latitude == null || scan.longitude == null) return false;
      if (scan.diagnosis.isHealthy) return false;
      if (!_matchesDiseaseFilter(scan, analytics)) return false;
      return true;
    }).toList();
  }

  List<DiagnosisResponse> _fakeWindowPoints({
    required bool previousWindow,
    required MapAnalyticsState analytics,
  }) {
    final window = _windowRange(previousWindow: previousWindow, analytics: analytics);
    final filtered = _fakeHeatmapPoints.where((point) {
      final at = point.createdAt.toUtc();
      final inWindow = !at.isBefore(window.start) && !at.isAfter(window.end);
      if (!inWindow) return false;
      final selected = analytics.selectedDiseaseName;
      if (selected == null || selected.isEmpty) return true;
      return point.diseaseName.toLowerCase() == selected.toLowerCase();
    }).toList();
    return filtered
        .asMap()
        .entries
        .map((entry) => _toFakeDiagnosisResponse(entry.value, entry.key))
        .toList();
  }

  DiagnosisResponse _toFakeDiagnosisResponse(FakeHeatmapPoint point, int index) {
    return DiagnosisResponse(
      scanId: 'fake_${point.createdAt.microsecondsSinceEpoch}_$index',
      imageUrl: '',
      diagnosis: DiagnosisSection(
        label: point.diseaseName,
        confidence: 1.0,
        isHealthy: false,
      ),
      recommendation: const RecommendationSection(textAr: '', textEn: ''),
      latitude: point.latitude,
      longitude: point.longitude,
      cropType: 'Fake',
      scannedAt: point.createdAt.toUtc(),
    );
  }

  Widget _buildAnalyticsBar(
    List<String> diseaseNames,
    MapAnalyticsState analytics,
    MapAnalyticsNotifier analyticsNotifier,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: MuzhirColors.creamScaffold,
      elevation: 1,
      shadowColor: MuzhirColors.deepCharcoal.withValues(alpha: 0.08),
      child: SizedBox(
        height: 56,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: [
            FilterChip(
              label: Text(l10n.heatmap),
              selected: analytics.showHeatmap,
              onSelected: analyticsNotifier.setShowHeatmap,
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: Text(l10n.compare),
              selected: analytics.compareWithPreviousWindow,
              onSelected: analytics.showHeatmap
                  ? analyticsNotifier.setCompareWithPreviousWindow
                  : null,
            ),
            const SizedBox(width: 8),
            Container(
              width: 170,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: MuzhirColors.deepCharcoal.withValues(alpha: 0.16),
                ),
                color: MuzhirColors.cardWhite,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: analytics.selectedDiseaseName ?? l10n.allDiseases,
                  isExpanded: true,
                  items: <String>[l10n.allDiseases, ...diseaseNames]
                      .map((name) => DropdownMenuItem<String>(
                            value: name,
                            child: Text(
                              name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    analyticsNotifier.setSelectedDiseaseName(
                      value == l10n.allDiseases ? null : value,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            ...MapTimePreset.values.map((preset) {
              final selected = preset == analytics.timePreset;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(_timePresetLabel(preset, l10n)),
                  selected: selected,
                  onSelected: (v) {
                    if (!v) return;
                    analyticsNotifier.setTimePreset(preset);
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDeveloperFakeBar(
    MapAnalyticsState analytics,
    MapAnalyticsNotifier analyticsNotifier,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: MuzhirColors.creamScaffold,
      elevation: 1,
      shadowColor: MuzhirColors.deepCharcoal.withValues(alpha: 0.08),
      child: SizedBox(
        height: 56,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: [
            FilterChip(
              label: Text(l10n.devFakeMode),
              selected: analytics.fakeModeEnabled,
              onSelected: (value) {
                analyticsNotifier.setFakeModeEnabled(value);
              },
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: Text(l10n.tapToAdd),
              selected: analytics.fakeTapInsertEnabled,
              onSelected: analytics.fakeModeEnabled
                  ? analyticsNotifier.setFakeTapInsertEnabled
                  : null,
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: analytics.fakeModeEnabled ? _seedFakeSaudiHotspots : null,
              icon: const Icon(Icons.auto_fix_high_outlined),
              label: Text(l10n.seedSaudiPoints),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: analytics.fakeModeEnabled ? _clearFakeHeatmapPoints : null,
              icon: const Icon(Icons.delete_outline),
              label: Text(l10n.clearFakeData),
            ),
            const SizedBox(width: 8),
            Chip(
              label: Text(l10n.fakeDataCount(_fakeHeatmapPoints.length)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshUserLocation({bool autoCenterOnFirstFix = false}) async {
    if (!mounted) return;
    setState(() => _locationLoading = true);

    LatLng? next;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        next = null;
      } else {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          next = null;
        } else {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          );
          next = LatLng(position.latitude, position.longitude);
        }
      }
    } catch (_) {
      next = null;
    }

    if (!mounted) return;
    setState(() {
      _userLocation = next;
      _locationLoading = false;
    });

    if (next != null &&
        autoCenterOnFirstFix &&
        mounted &&
        !_didAutoCenterOnUser) {
      _didAutoCenterOnUser = true;
      _animateMapTo(next, zoom: _userLocationZoom);
    }
  }

  void _animateMapTo(LatLng center, {required double zoom}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final impl = _mapController as MapControllerImpl;
        impl.moveAnimatedRaw(
          center,
          zoom,
          duration: const Duration(milliseconds: 550),
          curve: Curves.easeInOutCubic,
          hasGesture: false,
          source: MapEventSource.mapController,
        );
      } catch (_) {
        try {
          _mapController.move(center, zoom);
        } catch (_) {}
      }
    });
  }

  Future<void> _onRecenterOnUserPressed() async {
    if (_userLocation == null) {
      await _refreshUserLocation(autoCenterOnFirstFix: false);
      if (!mounted || _userLocation == null) return;
    }
    _animateMapTo(_userLocation!, zoom: _userLocationZoom);
  }

  /// Fits all scan pins in view (with padding for FAB / chrome).
  void _fitAllMarkersVisible([List<DiagnosisResponse>? markers]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final source = markers ?? _scanMarkers;
      final points = source
          .where((d) => d.latitude != null && d.longitude != null)
          .map((d) => LatLng(d.latitude!, d.longitude!))
          .toList();
      if (points.isEmpty) return;
      try {
        if (points.length == 1) {
          _mapController.move(points.first, 13);
          return;
        }
        _mapController.fitCamera(
          CameraFit.coordinates(
            coordinates: points,
            padding: const EdgeInsets.fromLTRB(40, 40, 40, 100),
            minZoom: 3,
            maxZoom: 18,
          ),
        );
      } catch (_) {}
    });
  }

  DiagnosisResponse? _markerSummaryForScanId(String scanId) {
    for (final m in _scanMarkers) {
      if (m.scanId == scanId) return m;
    }
    return null;
  }

  String _formatMarkerTimestamp(DateTime? t) {
    if (t == null) return '—';
    final d = t.toLocal();
    final locale = Localizations.localeOf(context).toLanguageTag();
    return DateFormat.yMMMd(locale).add_Hm().format(d);
  }

  Future<void> _openWalkingDirections(double lat, double lon) async {
    final l10n = AppLocalizations.of(context)!;
    final geo = Uri.parse('geo:$lat,$lon?q=$lat,$lon');
    try {
      if (await canLaunchUrl(geo)) {
        await launchUrl(geo, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}
    final googleMaps = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lon&travelmode=walking',
    );
    try {
      await launchUrl(googleMaps, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.couldNotOpenMaps,
            style: GoogleFonts.lexend(fontWeight: FontWeight.w600),
          ),
        ),
      );
    }
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

  Future<void> _deleteMarkerFromMap({
    required String scanId,
    required BuildContext sheetContext,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final shouldDelete = await _confirmDeleteScan();
    if (!shouldDelete) return;

    try {
      await ApiService().deleteScan(scanId);
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsetsDirectional.all(16),
          backgroundColor: MuzhirColors.earthyClayRed,
          content: Text(
            _messageFromDio(e),
            style: GoogleFonts.lexend(
              color: MuzhirColors.cardWhite,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
      return;
    } catch (e) {
      if (!mounted) return;
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
      return;
    }

    if (!mounted || !sheetContext.mounted) return;
    Navigator.of(sheetContext).pop();
    setState(() {
      _scanMarkers.removeWhere((s) => s.scanId == scanId);
    });
    ref.invalidate(scanHistoryProvider);
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
  }

  void _onPendingMarkerTapped(BuildContext context, AppLocalizations l10n) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: MuzhirColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: MuzhirColors.mutedGrey.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.cloud_upload_outlined,
                      color: Colors.orange, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    l10n.pendingScanMarker,
                    style: GoogleFonts.lexend(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: MuzhirColors.titleCharcoal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                l10n.pendingScanWillSync,
                style: GoogleFonts.lexend(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: MuzhirColors.titleCharcoal.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: MuzhirColors.forestGreen,
                    foregroundColor: MuzhirColors.cardWhite,
                  ),
                  child: Text(
                    l10n.close,
                    style: GoogleFonts.lexend(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onMarkerTapped(String scanId) {
    final l10n = AppLocalizations.of(context)!;
    final summary = _markerSummaryForScanId(scanId);
    if (summary == null) return;

    final navigator = Navigator.of(context);
    final lat = summary.latitude;
    final lon = summary.longitude;
    final cropLabel =
        summary.cropType.isNotEmpty ? summary.cropType : l10n.crop;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return _MapScanDetailSheet(
          summary: summary,
          coordinateLine: lat != null && lon != null
              ? '${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}'
              : '—',
          timestampLine: _formatMarkerTimestamp(summary.scannedAt),
          onViewDetails: () {
            Navigator.of(sheetContext).pop();
            navigator.push<bool>(
              MaterialPageRoute<bool>(
                builder: (_) => DiagnosisResultDetailScreen(
                  scanId: scanId,
                  cropType: cropLabel,
                ),
              ),
            ).then((deleted) {
              if (!mounted || deleted != true) return;
              setState(() {
                _scanMarkers.removeWhere((s) => s.scanId == scanId);
              });
              ref.invalidate(scanHistoryProvider);
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
            });
          },
          onNavigate: lat != null && lon != null
              ? () {
                  Navigator.of(sheetContext).pop();
                  _openWalkingDirections(lat, lon);
                }
              : null,
          onDelete: () => _deleteMarkerFromMap(
            scanId: scanId,
            sheetContext: sheetContext,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Drain queued offline uploads the moment connectivity is restored.
    ref.listen<AsyncValue<bool>>(isOfflineProvider, (prev, next) {
      final wasOffline = prev?.value ?? true;
      final isNowOnline = !(next.value ?? true);
      if (wasOffline && isNowOnline && _pendingUploads.isNotEmpty) {
        _drainPendingUploads();
      }
    });
    ref.listen<MapAnalyticsState>(mapAnalyticsProvider, (prev, next) {
      final shouldRefetch = prev == null ||
          prev.fakeModeEnabled != next.fakeModeEnabled ||
          prev.timePreset != next.timePreset ||
          prev.compareWithPreviousWindow != next.compareWithPreviousWindow;
      if (next.fakeModeEnabled) {
        return;
      }
      if (shouldRefetch) {
        _loadMapMarkers(analyticsOverride: next);
      }
    });

    final historyAsync = ref.watch(scanHistoryProvider);
    final analytics = ref.watch(mapAnalyticsProvider);
    final analyticsNotifier = ref.read(mapAnalyticsProvider.notifier);
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final mapBlue = Theme.of(context).extension<MuzhirFeatureColors>()!.mapUserLocationBlue;
    final historyByScanId = <String, bool>{
      for (final item in historyAsync.asData?.value ?? const [])
        item.scanId: item.isHealthy,
    };
    final fakeCurrentPoints = _fakeWindowPoints(
      previousWindow: false,
      analytics: analytics,
    );
    final fakePreviousPoints = analytics.compareWithPreviousWindow
        ? _fakeWindowPoints(
            previousWindow: true,
            analytics: analytics,
          )
        : const <DiagnosisResponse>[];
    final allDisplayPoints = analytics.fakeModeEnabled
        ? <DiagnosisResponse>[...fakeCurrentPoints, ...fakePreviousPoints]
        : _scanMarkers;

    final diseaseOptions = allDisplayPoints
        .where((scan) => !scan.diagnosis.isHealthy)
        .map((scan) => scan.diagnosis.label.trim())
        .where((name) => name.isNotEmpty && name != '—')
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final visibleSource = analytics.fakeModeEnabled
        ? fakeCurrentPoints
        : _windowCurrentMarkers;
    final visibleMarkers = visibleSource.where((scan) {
      if (analytics.fakeModeEnabled) {
        if (!_matchesDiseaseFilter(scan, analytics)) return false;
        return true;
      }
      final historicalHealth = historyByScanId[scan.scanId];
      if (historyAsync.hasValue && historicalHealth == null) {
        // Keep map and history synced: if history no longer has this scan, hide it.
        return false;
      }
      final isHealthy = historicalHealth ?? scan.diagnosis.isHealthy;
      switch (_selectedHealthFilter) {
        case _MapHealthFilter.infected:
          return !isHealthy;
        case _MapHealthFilter.healthy:
          return isHealthy;
        case _MapHealthFilter.all:
          return true;
      }
    }).where((scan) {
      if (!_matchesDiseaseFilter(scan, analytics)) return false;
      return true;
    }).toList();

    final currentHeatPoints = analytics.fakeModeEnabled
        ? fakeCurrentPoints
        : _heatmapWindowPoints(
            previousWindow: false,
            analytics: analytics,
          );
    final previousHeatPoints = analytics.compareWithPreviousWindow
        ? (analytics.fakeModeEnabled
            ? fakePreviousPoints
            : _heatmapWindowPoints(previousWindow: true, analytics: analytics))
        : const <DiagnosisResponse>[];

    final markerWidgets = visibleMarkers
        .where((d) => d.latitude != null && d.longitude != null)
        .map((d) {
      final point = LatLng(d.latitude!, d.longitude!);
      final healthy = historyByScanId[d.scanId] ?? d.diagnosis.isHealthy;
      return Marker(
        point: point,
        width: 48,
        height: 48,
        alignment: Alignment.topCenter,
        child: GestureDetector(
          onTap: analytics.fakeModeEnabled ? null : () => _onMarkerTapped(d.scanId),
          child: Icon(
            Icons.location_on_rounded,
            size: 44,
            color: _getMarkerColor(healthy),
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      );
    }).toList();
    final currentHeatCircles = currentHeatPoints
        .map(
          (d) => CircleMarker(
            point: LatLng(d.latitude!, d.longitude!),
            radius: 24,
            color: MuzhirColors.earthyClayRed.withValues(alpha: 0.18),
          ),
        )
        .toList();
    final previousHeatCircles = previousHeatPoints
        .map(
          (d) => CircleMarker(
            point: LatLng(d.latitude!, d.longitude!),
            radius: 24,
            color: MuzhirColors.earthyClayRed.withValues(alpha: 0.12),
          ),
        )
        .toList();
    final fitTarget = analytics.showHeatmap
        ? (analytics.compareWithPreviousWindow
            ? <DiagnosisResponse>[...currentHeatPoints, ...previousHeatPoints]
            : currentHeatPoints)
        : visibleMarkers;

    return Column(
      children: [
        _buildHealthFilterBar(),
        _buildAnalyticsBar(diseaseOptions, analytics, analyticsNotifier),
        if (kDebugMode) _buildDeveloperFakeBar(analytics, analyticsNotifier),
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _defaultCenter,
                  initialZoom: _initialZoom,
                  minZoom: 3.0,
                  onTap: (_, latLng) {
                    if (!analytics.fakeModeEnabled ||
                        !analytics.fakeTapInsertEnabled) {
                      return;
                    }
                    _addFakePointFromTap(latLng, analytics);
                  },
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.muzhir.app',
                    maxZoom: 19,
                    tileProvider: NetworkTileProvider(
                      headers: {
                        'User-Agent': 'Muzhir/1.0 (Android; com.muzhir.app)',
                      },
                    ),
                    tileBuilder: (context, tileWidget, tile) {
                      if (tile.loadError) {
                        debugPrint(
                          '[TILE_ERR] z=${tile.coordinates.z} '
                          'x=${tile.coordinates.x} '
                          'y=${tile.coordinates.y}',
                        );
                        return ColoredBox(
                          color: Colors.red.withValues(alpha: 0.15),
                          child: const Center(
                            child: Icon(
                              Icons.wifi_off_rounded,
                              color: Colors.red,
                              size: 18,
                            ),
                          ),
                        );
                      }
                      return tileWidget;
                    },
                  ),
                  if (analytics.showHeatmap && previousHeatCircles.isNotEmpty)
                    CircleLayer(circles: previousHeatCircles),
                  if (analytics.showHeatmap &&
                      analytics.compareWithPreviousWindow &&
                      currentHeatCircles.isNotEmpty)
                    ClipRect(
                      clipper: _LeftSwipeClipper(analytics.comparisonSlider),
                      child: CircleLayer(circles: currentHeatCircles),
                    ),
                  if (analytics.showHeatmap &&
                      !analytics.compareWithPreviousWindow &&
                      currentHeatCircles.isNotEmpty)
                    CircleLayer(circles: currentHeatCircles),
                  if (!analytics.showHeatmap) MarkerLayer(markers: markerWidgets),
                  if (_pendingUploads.isNotEmpty)
                    MarkerLayer(
                      markers: _pendingUploads
                          .where((u) =>
                              u.latitude != null && u.longitude != null)
                          .map((u) => Marker(
                                point: LatLng(u.latitude!, u.longitude!),
                                width: 48,
                                height: 48,
                                alignment: Alignment.topCenter,
                                child: GestureDetector(
                                  onTap: () =>
                                      _onPendingMarkerTapped(context, l10n),
                                  child: Icon(
                                    Icons.location_on_rounded,
                                    size: 44,
                                    color: Colors.orange,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.35),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  if (_userLocation != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _userLocation!,
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          child: _UserLocationDot(mapBlue: mapBlue),
                        ),
                      ],
                    ),
                  RichAttributionWidget(
                    alignment: AttributionAlignment.bottomRight,
                    popupInitialDisplayDuration: const Duration(seconds: 3),
                    animationConfig: const ScaleRAWA(),
                    showFlutterMapAttribution: false,
                    popupBackgroundColor: scheme.surface,
                    attributions: const [
                      TextSourceAttribution('© OpenStreetMap contributors'),
                    ],
                  ),
                ],
              ),
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_markersLoading)
                      _MapOverlayBanner(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: scheme.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                l10n.loadingFieldScans,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: scheme.onSurface,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (!_markersLoading && _markersError != null) ...[
                      _MapOverlayBanner(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _markersError!,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurface,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _loadMapMarkers,
                                child: Text(l10n.retry),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_locationLoading)
                      Padding(
                        padding: EdgeInsets.only(
                          top: (_markersLoading || _markersError != null) ? 8 : 0,
                        ),
                        child: _MapOverlayBanner(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: scheme.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  l10n.findingYourLocation,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: scheme.onSurface,
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              PositionedDirectional(
                end: 16,
                bottom: 56,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FloatingActionButton(
                      heroTag: 'map_fit_all_markers',
                      onPressed: fitTarget.isEmpty
                          ? null
                          : () => _fitAllMarkersVisible(fitTarget),
                      tooltip: l10n.showAllMarkers,
                      child: const Icon(Icons.zoom_out_map),
                    ),
                    const SizedBox(height: 12),
                    FloatingActionButton(
                      heroTag: 'map_recenter_user',
                      onPressed: _locationLoading ? null : _onRecenterOnUserPressed,
                      tooltip: l10n.myLocation,
                      child: const Icon(Icons.my_location_rounded),
                    ),
                  ],
                ),
              ),
              if (analytics.showHeatmap && analytics.compareWithPreviousWindow)
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 10,
                  child: Material(
                    color: scheme.surface.withValues(alpha: 0.92),
                    elevation: 2,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Slider(
                        value: analytics.comparisonSlider,
                        min: 0.0,
                        max: 1.0,
                        divisions: 100,
                        label: '${(analytics.comparisonSlider * 100).round()}%',
                        onChanged: analyticsNotifier.setComparisonSlider,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LeftSwipeClipper extends CustomClipper<Rect> {
  _LeftSwipeClipper(this.fraction);

  final double fraction;

  @override
  Rect getClip(Size size) {
    final x = size.width * fraction.clamp(0.0, 1.0);
    return Rect.fromLTRB(0, 0, x, size.height);
  }

  @override
  bool shouldReclip(covariant _LeftSwipeClipper oldClipper) {
    return oldClipper.fraction != fraction;
  }
}

/// Bottom sheet for a tapped map pin: summary fields + view details + external maps.
class _MapScanDetailSheet extends StatelessWidget {
  const _MapScanDetailSheet({
    required this.summary,
    required this.coordinateLine,
    required this.timestampLine,
    required this.onViewDetails,
    this.onNavigate,
    required this.onDelete,
  });

  final DiagnosisResponse summary;
  final String coordinateLine;
  final String timestampLine;
  final VoidCallback onViewDetails;
  final VoidCallback? onNavigate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isHealthy = summary.diagnosis.isHealthy;
    final statusColor =
        isHealthy ? MuzhirColors.coreLeafGreen : MuzhirColors.earthyClayRed;
    final statusText = TranslationHelper.getLocalizedText(
      context,
      isHealthy ? 'Healthy' : 'Unhealthy',
    );

    return SafeArea(
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: MuzhirColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: MuzhirColors.mutedGrey.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.scanDetails,
                      style: GoogleFonts.lexend(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: MuzhirColors.titleCharcoal,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    color: MuzhirColors.earthyClayRed,
                    tooltip: l10n.deleteScanTooltip,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _MapDetailRow(
                label: l10n.healthStatus,
                value: statusText,
                valueColor: statusColor,
              ),
              const SizedBox(height: 14),
              _MapDetailRow(
                label: l10n.cropType,
                value: summary.cropType.isNotEmpty
                    ? TranslationHelper.getLocalizedText(context, summary.cropType)
                    : '—',
              ),
              const SizedBox(height: 14),
              _MapDetailRow(
                label: l10n.timestamp,
                value: timestampLine,
              ),
              const SizedBox(height: 14),
              _MapDetailRow(
                label: l10n.coordinates,
                value: coordinateLine,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: onViewDetails,
                  style: FilledButton.styleFrom(
                    backgroundColor: MuzhirColors.forestGreen,
                    foregroundColor: MuzhirColors.cardWhite,
                  ),
                  child: Text(
                    l10n.viewDetails,
                    style: GoogleFonts.lexend(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: onNavigate,
                  icon: const Icon(Icons.directions_walk_rounded),
                  label: Text(
                    l10n.navigate,
                    style: GoogleFonts.lexend(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapDetailRow extends StatelessWidget {
  const _MapDetailRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.lexend(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: MuzhirColors.mutedGrey,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.lexend(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: valueColor ?? MuzhirColors.titleCharcoal,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _MapOverlayBanner extends StatelessWidget {
  const _MapOverlayBanner({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 3,
      color: Theme.of(context).cardTheme.color ?? scheme.surface,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: child,
      ),
    );
  }
}

/// Standard GPS-style blue dot with white ring.
class _UserLocationDot extends StatelessWidget {
  const _UserLocationDot({required this.mapBlue});

  final Color mapBlue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: mapBlue,
        shape: BoxShape.circle,
        border: Border.all(color: scheme.onPrimary, width: 3),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.25),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }
}
