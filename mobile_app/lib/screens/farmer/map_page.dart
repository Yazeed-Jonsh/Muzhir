import 'package:flutter/material.dart';
import 'package:muzhir/config/app_theme.dart';
import 'package:muzhir/widgets/mock_google_map.dart';
import 'package:muzhir/widgets/map_marker_card.dart';

/// Farmer Disease Map Page.
/// Displays a simulated Google Map (generic farm view) with interactive markers.
class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  // Mock center of the farm
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(24.7136, 46.6753),
    zoom: 16.0,
  );

  // Future google_maps_flutter Set<Marker>
  late Set<MockMarker> _markers;

  @override
  void initState() {
    super.initState();
    _initMarkers();
  }

  void _initMarkers() {
    _markers = {
      MockMarker(
        markerId: 'm1',
        position: const LatLng(24.7145, 46.6740),
        iconColor: const Color(0xFFD4790E), // Diseased
        onTap: () => _showMarkerDetails(
          locationName: 'Sector A - North',
          cropType: 'Tomato',
          diseaseName: 'Early Blight',
          timeAgo: '2 hours ago',
          isHealthy: false,
        ),
      ),
      MockMarker(
        markerId: 'm2',
        position: const LatLng(24.7128, 46.6765),
        iconColor: MuzhirColors.coreLeafGreen, // Healthy
        onTap: () => _showMarkerDetails(
          locationName: 'Sector B - East',
          cropType: 'Date Palm',
          diseaseName: 'Healthy',
          timeAgo: 'Yesterday',
          isHealthy: true,
        ),
      ),
      MockMarker(
        markerId: 'm3',
        position: const LatLng(24.7120, 46.6730),
        iconColor: const Color(0xFFD4790E), // Diseased
        onTap: () => _showMarkerDetails(
          locationName: 'Sector C - South West',
          cropType: 'Wheat',
          diseaseName: 'Leaf Rust',
          timeAgo: '3 days ago',
          isHealthy: false,
        ),
      ),
      MockMarker(
        markerId: 'm4',
        position: const LatLng(24.7150, 46.6770),
        iconColor: MuzhirColors.coreLeafGreen, // Healthy
        onTap: () => _showMarkerDetails(
          locationName: 'Sector D - North East',
          cropType: 'Cucumber',
          diseaseName: 'Healthy',
          timeAgo: 'Just now',
          isHealthy: true,
        ),
      ),
    };
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
        // Map Container
        Expanded(
          child: MockGoogleMap(
            initialCameraPosition: _initialPosition,
            markers: _markers,
          ),
        ),
      ],
    );
  }
}
