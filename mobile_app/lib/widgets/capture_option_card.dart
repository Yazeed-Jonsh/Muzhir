import 'package:flutter/material.dart';
import 'package:muzhir/config/app_theme.dart';

/// Tappable card for selecting an image capture method.
/// Used in the Diagnose page idle state for Camera, Gallery, and Drone options.
class CaptureOptionCard extends StatelessWidget {
  const CaptureOptionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? MuzhirColors.coreLeafGreen;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
          decoration: BoxDecoration(
            color: MuzhirColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: MuzhirColors.deepCharcoal.withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: MuzhirColors.deepCharcoal.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: MuzhirColors.deepCharcoal.withValues(alpha: 0.45),
                      fontSize: 11,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
