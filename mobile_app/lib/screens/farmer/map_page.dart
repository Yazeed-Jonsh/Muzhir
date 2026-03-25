import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:muzhir/config/app_theme.dart';
import 'package:muzhir/widgets/map_marker_card.dart';

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
  /// Fallback center (Taif region) while GPS is loading or unavailable.
  static const LatLng _defaultCenter = LatLng(21.2703, 40.4158);
  static const double _initialZoom = 11.0;
  static const double _userLocationZoom = 15.0;

  late final MapController _mapController;
  late final List<_MapMarkerData> _markers;

  LatLng? _userLocation;
  bool _locationLoading = false;
  bool _didAutoCenterOnUser = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _initMarkers();
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

  void _initMarkers() {
    _markers = [
      _MapMarkerData(
        point: const LatLng(21.2850, 40.4080),
        color: const Color(0xFFD4790E), // Orange – serious infection
        onTap: () => _showMarkerDetails(
          locationName: 'Sector A - North',
          cropType: 'Tomato',
          diseaseName: 'Early Blight',
          timeAgo: '2 hours ago',
          isHealthy: false,
        ),
      ),
      _MapMarkerData(
        point: const LatLng(21.2550, 40.4280),
        color: MuzhirColors.coreLeafGreen, // Green – healthy
        onTap: () => _showMarkerDetails(
          locationName: 'Sector B - East',
          cropType: 'Date Palm',
          diseaseName: 'Healthy',
          timeAgo: 'Yesterday',
          isHealthy: true,
        ),
      ),
      _MapMarkerData(
        point: const LatLng(21.2620, 40.3980),
        color: const Color(0xFFD4790E), // Orange – serious infection
        onTap: () => _showMarkerDetails(
          locationName: 'Sector C - South West',
          cropType: 'Wheat',
          diseaseName: 'Leaf Rust',
          timeAgo: '3 days ago',
          isHealthy: false,
        ),
      ),
    ];
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
    final target = _userLocation!;
    double zoom = _userLocationZoom;
    try {
      zoom = _mapController.camera.zoom;
    } catch (_) {}
    _animateMapTo(target, zoom: zoom.clamp(3.0, 18.0));
  }

  void _showMarkerDetails({
    required String locationName,
    required String cropType,
    required String diseaseName,
    required String timeAgo,
    required bool isHealthy,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return MapMarkerCard(
          locationName: locationName,
          cropType: cropType,
          diseaseName: diseaseName,
          timeAgo: timeAgo,
          isHealthy: isHealthy,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
                    markers: _markers.map((data) {
                      return Marker(
                        point: data.point,
                        width: 48,
                        height: 48,
                        alignment: Alignment.topCenter,
                        child: GestureDetector(
                          onTap: data.onTap,
                          child: Icon(
                            Icons.location_on_rounded,
                            size: 44,
                            color: data.color,
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
                          child: _UserLocationDot(),
                        ),
                      ],
                    ),
                  const RichAttributionWidget(
                    alignment: AttributionAlignment.bottomRight,
                    popupInitialDisplayDuration: Duration(seconds: 3),
                    animationConfig: ScaleRAWA(),
                    showFlutterMapAttribution: false,
                    popupBackgroundColor: MuzhirColors.surface,
                    attributions: [
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
                      color: MuzhirColors.white,
                      borderRadius: BorderRadius.circular(24),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: MuzhirColors.coreLeafGreen,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Finding your location…',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: MuzhirColors.deepCharcoal,
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
                child: FloatingActionButton(
                  onPressed: _locationLoading ? null : _onRecenterOnUserPressed,
                  backgroundColor: MuzhirColors.coreLeafGreen,
                  foregroundColor: MuzhirColors.white,
                  child: const Icon(Icons.my_location_rounded),
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
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: const Color(0xFF1E88E5),
        shape: BoxShape.circle,
        border: Border.all(color: MuzhirColors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }
}

class _MapMarkerData {
  const _MapMarkerData({
    required this.point,
    required this.color,
    required this.onTap,
  });

  final LatLng point;
  final Color color;
  final VoidCallback onTap;
}
