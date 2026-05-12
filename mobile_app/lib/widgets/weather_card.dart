import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:muzhir/l10n/app_localizations.dart';
import 'package:muzhir/theme/app_theme.dart';

/// Weather summary card using the device location and Open-Meteo.
/// Forest green (#436639) surface, white typography, mint (#E0E8D9) icon wells.
class WeatherCard extends StatefulWidget {
  const WeatherCard({super.key});

  @override
  State<WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<WeatherCard> {
  static const double _radius = 24;

  _WeatherData? _weather;
  var _loading = true;
  var _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    try {
      final position = await _currentPosition();
      final weather = await _fetchWeather(position);
      if (!mounted) return;
      setState(() {
        _weather = weather;
        _loading = false;
        _hasError = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hasError = true;
      });
    }
  }

  Future<Position> _currentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw StateError('Location service is disabled');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError('Location permission denied');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 10),
      ),
    );
  }

  Future<_WeatherData> _fetchWeather(Position position) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': position.latitude.toStringAsFixed(4),
      'longitude': position.longitude.toStringAsFixed(4),
      'current':
          'temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code',
      'timezone': 'auto',
    });

    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Weather request failed: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Weather response was not an object');
    }
    final current = decoded['current'];
    if (current is! Map<String, dynamic>) {
      throw const FormatException('Weather response missing current values');
    }

    final temperature = current['temperature_2m'];
    final humidity = current['relative_humidity_2m'];
    final windSpeed = current['wind_speed_10m'];
    final weatherCode = current['weather_code'];
    if (temperature is! num ||
        humidity is! num ||
        windSpeed is! num ||
        weatherCode is! num) {
      throw const FormatException('Weather response had invalid values');
    }

    return _WeatherData(
      temperatureCelsius: temperature.round(),
      humidityPercent: humidity.round(),
      windKmh: windSpeed.round(),
      weatherCode: weatherCode.round(),
    );
  }

  IconData _iconForWeatherCode(int code) {
    if (code == 0) return Icons.wb_sunny_rounded;
    if (code == 1 || code == 2 || code == 3) return Icons.wb_cloudy_rounded;
    if (code == 45 || code == 48) return Icons.foggy;
    if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) {
      return Icons.water_drop_rounded;
    }
    if (code >= 71 && code <= 77) return Icons.ac_unit_rounded;
    if (code >= 95 && code <= 99) return Icons.thunderstorm_rounded;
    return Icons.wb_sunny_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final weather = _weather;
    final temperature =
        weather == null ? '--' : '${weather.temperatureCelsius}';
    final locationText = _loading
        ? l10n.findingYourLocation
        : _hasError
            ? l10n.weatherUnavailable
            : l10n.myLocation;
    final humidity = weather == null ? '--' : '${weather.humidityPercent}%';
    final wind = weather == null ? '--' : '${weather.windKmh} km/h';
    final weatherIcon = weather == null
        ? Icons.wb_sunny_rounded
        : _iconForWeatherCode(weather.weatherCode);

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
                      '$temperature°',
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
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
                    Expanded(
                      child: Text(
                        locationText,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: MuzhirColors.white.withValues(alpha: 0.92),
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _WeatherDetail(
                      icon: Icons.water_drop_outlined,
                      value: humidity,
                      label: l10n.humidity,
                    ),
                    const SizedBox(width: 16),
                    _WeatherDetail(
                      icon: Icons.air,
                      value: wind,
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
            child: Icon(
              weatherIcon,
              color: MuzhirColors.forestGreen,
              size: 40,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeatherData {
  const _WeatherData({
    required this.temperatureCelsius,
    required this.humidityPercent,
    required this.windKmh,
    required this.weatherCode,
  });

  final int temperatureCelsius;
  final int humidityPercent;
  final int windKmh;
  final int weatherCode;
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
