import 'package:flutter/material.dart';
import 'package:muzhir/theme/app_theme.dart';

/// Greeting banner at the top of the Farmer Dashboard.
/// Shows a welcome message and the current date.
class GreetingHeader extends StatelessWidget {
  const GreetingHeader({super.key});

  String _greetingByHour() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  /// Formats today using the device clock ([DateTime.now] in local time).
  String _formattedDate() {
    final now = DateTime.now();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            MuzhirColors.midnightTechGreen,
            MuzhirColors.midnightTechGreen.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_greetingByHour()}, Farmer',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: MuzhirColors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formattedDate(),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: MuzhirColors.luminousLime,
                        ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MuzhirColors.coreLeafGreen.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.eco_rounded,
                color: MuzhirColors.luminousLime,
                size: 32,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
