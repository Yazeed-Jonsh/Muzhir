import 'package:flutter/material.dart';
import 'package:muzhir/theme/app_theme.dart';

// ── Google Maps API Mimic Classes ───────────────────────────────────

/// Represents a geographic coordinate.
class LatLng {
  final double latitude;
  final double longitude;

  const LatLng(this.latitude, this.longitude);
}

/// Represents the initial position of the map camera.
class CameraPosition {
  final LatLng target;
  final double zoom;

  const CameraPosition({
    required this.target,
    required this.zoom,
  });
}

/// Represents a pin on the map.
class MockMarker {
  final String markerId;
  final LatLng position;
  final VoidCallback onTap;
  final Color iconColor;

  const MockMarker({
    required this.markerId,
    required this.position,
    required this.onTap,
    this.iconColor = MuzhirColors.coreLeafGreen,
  });
}

// ── Mock Google Map Widget ──────────────────────────────────────────

/// A placeholder widget structured to mimic `google_maps_flutter`.
/// Easy to swap out later by simply replacing this class with `GoogleMap`.
class MockGoogleMap extends StatelessWidget {
  const MockGoogleMap({
    super.key,
    required this.initialCameraPosition,
    required this.markers,
  });

  final CameraPosition initialCameraPosition;
  final Set<MockMarker> markers;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          decoration: BoxDecoration(
            color: MuzhirColors.vividSprout.withValues(alpha: 0.15),
           
            // Mock satellite "farm" texture background
            /*
            image: const DecorationImage(
              image: AssetImage('assets/images/mock_farm_bg.png'),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                Colors.black26,
                BlendMode.darken,
              ),
            ),
            */
          ),
          
          child: Stack(
            children: [
              // Draw "field" grid lines as a placeholder for satellite imagery
              CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: _FarmGridPainter(),
              ),

              // Position markers
              ...markers.map((marker) {
                // Mock coordinate to screen mapping
                // Center of the screen is roughly the target
                final dx = constraints.maxWidth / 2 +
                    (marker.position.longitude - initialCameraPosition.target.longitude) * 50000;
                final dy = constraints.maxHeight / 2 -
                    (marker.position.latitude - initialCameraPosition.target.latitude) * 50000;

                return Positioned(
                  left: dx - 20, // offset by half icon size
                  top: dy - 40,  // offset by full icon height to pin the bottom
                  child: GestureDetector(
                    onTap: marker.onTap,
                    child: _AnimatedPin(color: marker.iconColor),
                  ),
                );
              }),

              // Map attribution placeholder
              Positioned(
                bottom: 8,
                right: 8,
                child: Text(
                  'Mock Map Data © 2026 Muzhir',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: MuzhirColors.deepCharcoal.withValues(alpha: 0.6),
                        fontSize: 10,
                      ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AnimatedPin extends StatefulWidget {
  const _AnimatedPin({required this.color});
  final Color color;

  @override
  State<_AnimatedPin> createState() => _AnimatedPinState();
}

class _AnimatedPinState extends State<_AnimatedPin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: -4.0, end: 4.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: Icon(
            Icons.location_on_rounded,
            size: 40,
            color: widget.color,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FarmGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = MuzhirColors.coreLeafGreen.withValues(alpha: 0.1)
      ..strokeWidth = 1.0;

    const spacing = 80.0;
    
    // Vertical lines
    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    
    // Horizontal lines
    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
