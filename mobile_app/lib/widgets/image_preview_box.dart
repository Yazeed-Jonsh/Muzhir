import 'dart:io';

import 'package:flutter/material.dart';
import 'package:muzhir/config/app_theme.dart';

/// Displays a preview of the selected image, or a dashed empty-state placeholder.
class ImagePreviewBox extends StatelessWidget {
  const ImagePreviewBox({
    super.key,
    required this.hasImage,
    this.imageFile,
    this.onRemove,
  });

  /// Whether an image has been selected (mock).
  final bool hasImage;

  /// The selected image file to display; when non-null, shows Image.file.
  final File? imageFile;

  /// Called when the user taps the remove button.
  final VoidCallback? onRemove;

  /// True when we have an actual image file to display (avoids showing preview UI with "No image loaded").
  bool get _hasDisplayableImage => hasImage && imageFile != null;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        color: _hasDisplayableImage
            ? MuzhirColors.midnightTechGreen.withValues(alpha: 0.05)
            : MuzhirColors.white,
        borderRadius: BorderRadius.circular(20),
        border: _hasDisplayableImage
            ? Border.all(color: MuzhirColors.coreLeafGreen.withValues(alpha: 0.3), width: 1.5)
            : null,
      ),
      child: _hasDisplayableImage ? _buildPreview(context) : _buildEmpty(context),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: MuzhirColors.deepCharcoal.withValues(alpha: 0.2),
        radius: 20,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              size: 48,
              color: MuzhirColors.deepCharcoal.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 12),
            Text(
              'No image selected',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: MuzhirColors.deepCharcoal.withValues(alpha: 0.4),
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose a capture method below',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: MuzhirColors.deepCharcoal.withValues(alpha: 0.3),
                    fontSize: 12,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    assert(imageFile != null, '_buildPreview is only used when _hasDisplayableImage is true');
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.file(
            imageFile!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
        // Remove button
        if (onRemove != null)
          Positioned(
            top: 10,
            right: 10,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: MuzhirColors.deepCharcoal.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: MuzhirColors.white,
                  size: 18,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Draws a dashed rounded-rect border for the empty state.
class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(radius),
      ));

    const dashWidth = 8.0;
    const dashSpace = 5.0;

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final end = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, end.clamp(0, metric.length)),
          paint,
        );
        distance = end + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      color != oldDelegate.color || radius != oldDelegate.radius;
}
