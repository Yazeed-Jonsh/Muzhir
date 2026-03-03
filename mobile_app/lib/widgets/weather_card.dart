import 'package:flutter/material.dart';
import 'package:muzhir/config/app_theme.dart';

/// Weather summary card with mock data for Saudi Arabia.
class WeatherCard extends StatelessWidget {
  const WeatherCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            MuzhirColors.coreLeafGreen,
            MuzhirColors.vividSprout,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: MuzhirColors.coreLeafGreen.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Temperature & location
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '28°',
                      style:
                          Theme.of(context).textTheme.headlineLarge?.copyWith(
                                color: MuzhirColors.white,
                                fontSize: 40,
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'C',
                        style:
                            Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: MuzhirColors.white.withValues(alpha: 0.8),
                                ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: MuzhirColors.luminousLime,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Jeddah, Saudi Arabia',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: MuzhirColors.white.withValues(alpha: 0.9),
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Detail chips
                const Row(
                  children: [
                    _WeatherDetail(
                      icon: Icons.water_drop_outlined,
                      value: '45%',
                      label: 'Humidity',
                    ),
                    SizedBox(width: 16),
                    _WeatherDetail(
                      icon: Icons.air,
                      value: '12 km/h',
                      label: 'Wind',
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Sun icon
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: MuzhirColors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.wb_sunny_rounded,
              color: MuzhirColors.luminousLime,
              size: 40,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeatherDetail extends StatelessWidget {
  const _WeatherDetail({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: MuzhirColors.white.withValues(alpha: 0.8)),
        const SizedBox(width: 4),
        Text(
          '$value ',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: MuzhirColors.white,
                fontWeight: FontWeight.w600,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: MuzhirColors.white.withValues(alpha: 0.7),
                fontSize: 12,
              ),
        ),
      ],
    );
  }
}
