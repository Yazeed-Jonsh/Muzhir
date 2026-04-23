import 'package:flutter/material.dart';
import 'package:muzhir/l10n/app_localizations.dart';
import 'package:muzhir/theme/app_theme.dart';

/// Weather summary card with mock data for Saudi Arabia.
/// Forest green (#436639) surface, white typography, mint (#E0E8D9) icon wells.
class WeatherCard extends StatelessWidget {
  const WeatherCard({super.key});

  static const double _radius = 24;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MuzhirColors.forestGreen,
        borderRadius: BorderRadius.circular(_radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: MuzhirColors.forestGreen.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
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
                                  color: MuzhirColors.white.withValues(alpha: 0.85),
                                ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: MuzhirColors.white.withValues(alpha: 0.9),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      l10n.jeddahSaudiArabia,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: MuzhirColors.white.withValues(alpha: 0.92),
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _WeatherDetail(
                      icon: Icons.water_drop_outlined,
                      value: '45%',
                      label: l10n.humidity,
                    ),
                    const SizedBox(width: 16),
                    _WeatherDetail(
                      icon: Icons.air,
                      value: '12 km/h',
                      label: l10n.wind,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: MuzhirColors.weatherIconCircle,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.wb_sunny_rounded,
              color: MuzhirColors.forestGreen,
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
        Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: MuzhirColors.weatherIconCircle,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 16,
            color: MuzhirColors.forestGreen,
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: MuzhirColors.white.withValues(alpha: 0.75),
                    fontSize: 10,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: MuzhirColors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}
