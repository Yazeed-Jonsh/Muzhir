import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:muzhir/theme/app_theme.dart';
import 'package:muzhir/widgets/map_marker_card.dart';

// ── Fake field reports (Jeddah) — replace with Firestore later ─────────────

/// Healthy vs diseased scan status for map mock data.
enum _MockReportStatus { healthy, diseased }

/// One map pin’s backing data before Firebase (matches intended Firestore shape).
class _MockMapReport {
  const _MockMapReport({
    required this.id,
    required this.position,
    required this.plantName,
    required this.status,
    required this.timestamp,
  });

  final String id;
  final LatLng position;
  final String plantName;
  final _MockReportStatus status;
  final DateTime timestamp;
}

/// Parcel / sector labels for bottom sheet (keyed by [_MockMapReport.id]).
const Map<String, String> _mockReportLocationTitles = {
  'jed-001': 'Al-Hamra',
  'jed-002': 'Al-Shati',
  'jed-003': 'Al-Rawdah',
  'jed-004': 'Obhur',
  'jed-005': 'Al-Balad',
};

/// Disease diagnosis label when status is diseased (keyed by report id).
const Map<String, String> _mockReportDiseaseLabels = {
  'jed-001': 'Early Blight',
  'jed-003': 'Leaf Rust',
  'jed-005': 'Powdery Mildew',
};

String _statusLineForReport(_MockMapReport r) {
  if (r.status == _MockReportStatus.healthy) return 'Healthy';
  return _mockReportDiseaseLabels[r.id] ?? 'Diseased';
}

String _relativeTime(DateTime past) {
  final d = DateTime.now().difference(past);
  if (d.inSeconds < 60) return 'Just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) {
    final h = d.inHours;
    return h == 1 ? '1 hour ago' : '$h hours ago';
  }
  if (d.inDays < 7) {
    final days = d.inDays;
    return days == 1 ? 'Yesterday' : '$days days ago';
  }
  if (d.inDays < 30) return '${d.inDays ~/ 7} weeks ago';
  return '${d.inDays ~/ 30} months ago';
}

/// Five synthetic field reports in Jeddah (mock data until Firestore).
final List<_MockMapReport> _mockReports = [
  _MockMapReport(
    id: 'jed-001',
    position: const LatLng(21.5160, 39.1650),
    plantName: 'Tomato',
    status: _MockReportStatus.diseased,
    timestamp: DateTime.now().subtract(const Duration(hours: 2)),
  ),
  _MockMapReport(
    id: 'jed-002',
    position: const LatLng(21.5850, 39.1200),
    plantName: 'Date palm',
    status: _MockReportStatus.healthy,
    timestamp: DateTime.now().subtract(const Duration(days: 1)),
  ),
  _MockMapReport(
    id: 'jed-003',
    position: const LatLng(21.5580, 39.1680),
    plantName: 'Wheat',
    status: _MockReportStatus.diseased,
    timestamp: DateTime.now().subtract(const Duration(days: 3)),
  ),
  _MockMapReport(
    id: 'jed-004',
    position: const LatLng(21.7100, 39.1250),
    plantName: 'Date palm',
    status: _MockReportStatus.healthy,
    timestamp: DateTime.now().subtract(const Duration(minutes: 45)),
  ),
  _MockMapReport(
    id: 'jed-005',
    position: const LatLng(21.4850, 39.1850),
    plantName: 'Grapes',
    status: _MockReportStatus.diseased,
    timestamp: DateTime.now().subtract(const Duration(hours: 18)),
  ),
];

/// Farmer Disease Map Page.
/// Displays an OpenStreetMap view with markers for disease/health status
/// and the user's current position when available.
class MapPage extends StatefulWidget {
  const MapPage({super.key, this.isTabVisible = false});

  /// When true, this tab is visible in the root [IndexedStack] (refresh location).
  final bool isTabVisible;

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  /// Fallback center (Jeddah) while GPS is loading or unavailable.
  static const LatLng _defaultCenter = LatLng(21.5433, 39.1728);
  static const double _initialZoom = 11.0;
  /// Street-level zoom when centering on the user (My Location FAB & first GPS fix).
  static const double _userLocationZoom = 15.5;

  late final MapController _mapController;

  LatLng? _userLocation;
  bool _locationLoading = false;
  bool _didAutoCenterOnUser = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
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

  /// Fits the five mock Jeddah report pins in view (with padding for FAB / chrome).
  void _fitAllMarkersVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final points = _mockReports.map((r) => r.position).toList();
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

  void _showReportSheet(_MockMapReport report) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return MapMarkerCard(
          locationName: _mockReportLocationTitles[report.id] ?? report.id,
          cropType: report.plantName,
          diseaseName: _statusLineForReport(report),
          timeAgo: _relativeTime(report.timestamp),
          isHealthy: report.status == _MockReportStatus.healthy,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mapBlue = Theme.of(context).extension<MuzhirFeatureColors>()!.mapUserLocationBlue;

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: const MapOptions(
                  initialCenter: _defaultCenter,
                  initialZoom: _initialZoom,
                  minZoom: 3.0,
                  interactionOptions: InteractionOptions(
                    flags: InteractiveFlag.all,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.muzhir',
                  ),
                  MarkerLayer(
                    markers: _mockReports.map((report) {
                      final markerColor = report.status == _MockReportStatus.healthy
                          ? MuzhirColors.darkOliveGreen
                          : MuzhirColors.earthyClayRed;
                      return Marker(
                        point: report.position,
                        width: 48,
                        height: 48,
                        alignment: Alignment.topCenter,
                        child: GestureDetector(
                          onTap: () => _showReportSheet(report),
                          child: Icon(
                            Icons.location_on_rounded,
                            size: 44,
                            color: markerColor,
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
                    }).toList(),
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
              if (_locationLoading)
                Positioned(
                  top: 12,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Material(
                      elevation: 3,
                      color: Theme.of(context).cardTheme.color ?? scheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
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
                            Text(
                              'Finding your location…',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: scheme.onSurface,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: 16,
                bottom: 56,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FloatingActionButton(
                      heroTag: 'map_fit_all_markers',
                      onPressed: _fitAllMarkersVisible,
                      tooltip: 'Show all markers',
                      child: const Icon(Icons.zoom_out_map),
                    ),
                    const SizedBox(height: 12),
                    FloatingActionButton(
                      heroTag: 'map_recenter_user',
                      onPressed: _locationLoading ? null : _onRecenterOnUserPressed,
                      tooltip: 'My location',
                      child: const Icon(Icons.my_location_rounded),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
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
