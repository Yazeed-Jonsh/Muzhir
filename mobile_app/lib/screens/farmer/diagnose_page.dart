import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:muzhir/config/app_theme.dart';
import 'package:muzhir/widgets/capture_option_card.dart';
import 'package:muzhir/widgets/image_preview_box.dart';
import 'package:muzhir/widgets/crop_type_dropdown.dart';
import 'package:muzhir/widgets/diagnosis_result_card.dart';
import 'package:muzhir/widgets/recent_scan_tile.dart';

enum _DiagnoseState { idle, preview, result }

/// Farmer Diagnose Page.
/// Flow: idle → preview (with crop type dropdown) → result (text-only).
/// No image quality assessment. No bounding boxes or masks.
class DiagnosePage extends StatefulWidget {
  const DiagnosePage({super.key});

  @override
  State<DiagnosePage> createState() => _DiagnosePageState();
}

class _DiagnosePageState extends State<DiagnosePage> {
  _DiagnoseState _state = _DiagnoseState.idle;
  ScanSource _selectedSource = ScanSource.mobile;
  String? _selectedCrop;
  bool _isAnalyzing = false;
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  /// Location captured when an image is picked for diagnosis (null if unavailable).
  double? _diagnosisLatitude;
  double? _diagnosisLongitude;

  static ScanSource _scanSourceFromImageSource(ImageSource source) {
    switch (source) {
      case ImageSource.camera:
        return ScanSource.mobile;
      case ImageSource.gallery:
        return ScanSource.mobile;
    }
  }

  /// Resolves location permission and reads the current [Position].
  /// Updates [_diagnosisLatitude] and [_diagnosisLongitude], or clears them on failure.
  Future<void> _getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        setState(() {
          _diagnosisLatitude = null;
          _diagnosisLongitude = null;
        });
      }
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() {
          _diagnosisLatitude = null;
          _diagnosisLongitude = null;
        });
      }
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (mounted) {
        setState(() {
          _diagnosisLatitude = position.latitude;
          _diagnosisLongitude = position.longitude;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _diagnosisLatitude = null;
          _diagnosisLongitude = null;
        });
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null && mounted) {
      await _getCurrentLocation();
      if (!mounted) return;
      setState(() {
        _selectedImage = File(pickedFile.path);
        _selectedSource = _scanSourceFromImageSource(source);
        _selectedCrop = 'Tomato';
        _state = _DiagnoseState.preview;
      });
    }
  }

  /// Picks an image from gallery to use as an imported drone scan.
  /// Only enters preview when a file is actually selected.
  Future<void> _pickImageForDrone() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null && mounted) {
      await _getCurrentLocation();
      if (!mounted) return;
      setState(() {
        _selectedImage = File(pickedFile.path);
        _selectedSource = ScanSource.drone;
        _selectedCrop = 'Tomato';
        _state = _DiagnoseState.preview;
      });
    }
  }

  void _onRemoveImage() {
    setState(() {
      _state = _DiagnoseState.idle;
      _selectedCrop = null;
      _selectedImage = null;
      _isAnalyzing = false;
      _diagnosisLatitude = null;
      _diagnosisLongitude = null;
    });
  }

  Future<void> _onAnalyze() async {
    if (_selectedCrop == null) return;

    setState(() => _isAnalyzing = true);

    // Mock 1.5s analysis delay — no quality assessment step
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;
    setState(() {
      _isAnalyzing = false;
      _state = _DiagnoseState.result;
    });
  }

  void _onScanAnother() {
    setState(() {
      _state = _DiagnoseState.idle;
      _selectedCrop = null;
      _selectedImage = null;
      _isAnalyzing = false;
      _diagnosisLatitude = null;
      _diagnosisLongitude = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Page title
          Text(
            'Plant Diagnosis',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Scan your plant for diseases using AI',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: MuzhirColors.deepCharcoal.withValues(alpha: 0.55),
                ),
          ),
          const SizedBox(height: 20),

          // Image preview box (all states)
          ImagePreviewBox(
            hasImage: _state != _DiagnoseState.idle,
            imageFile: _selectedImage,
            onRemove: _state == _DiagnoseState.preview ? _onRemoveImage : null,
          ),
          const SizedBox(height: 20),

          // State-specific content
          if (_state == _DiagnoseState.idle) _buildIdleSection(),
          if (_state == _DiagnoseState.preview) _buildPreviewSection(),
          if (_state == _DiagnoseState.result) _buildResultSection(),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── IDLE STATE ────────────────────────────────────────────────────

  Widget _buildIdleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How would you like to capture?',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            CaptureOptionCard(
              icon: Icons.camera_alt_rounded,
              title: 'Camera',
              subtitle: 'Take photo',
              onTap: () => _pickImage(ImageSource.camera),
            ),
            const SizedBox(width: 12),
            CaptureOptionCard(
              icon: Icons.photo_library_rounded,
              title: 'Gallery',
              subtitle: 'Choose file',
              onTap: () => _pickImage(ImageSource.gallery),
            ),
            const SizedBox(width: 12),
            CaptureOptionCard(
              icon: Icons.flight_rounded,
              title: 'Drone',
              subtitle: 'Import scan',
              iconColor: MuzhirColors.midnightTechGreen,
              onTap: _pickImageForDrone,
            ),
          ],
        ),
      ],
    );
  }

  // ── PREVIEW STATE ─────────────────────────────────────────────────

  Widget _buildPreviewSection() {
    final bool isMobile = _selectedSource == ScanSource.mobile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Source indicator
        Row(
          children: [
            Icon(
              isMobile ? Icons.smartphone_rounded : Icons.flight_rounded,
              size: 16,
              color: MuzhirColors.vividSprout,
            ),
            const SizedBox(width: 6),
            Text(
              'Selected via: ${isMobile ? 'Mobile' : 'Drone'}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: MuzhirColors.deepCharcoal.withValues(alpha: 0.55),
                  ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Crop type dropdown
        CropTypeDropdown(
          value: _selectedCrop,
          onChanged: (val) => setState(() => _selectedCrop = val),
        ),
        const SizedBox(height: 24),

        // Analyze button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _isAnalyzing ? null : _onAnalyze,
            icon: _isAnalyzing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(MuzhirColors.white),
                    ),
                  )
                : const Icon(Icons.eco_rounded),
            label: Text(_isAnalyzing ? 'Analyzing...' : 'Analyze Plant'),
          ),
        ),
      ],
    );
  }

  // ── RESULT STATE ──────────────────────────────────────────────────

  Widget _buildResultSection() {
    return Column(
      children: [
        // Text-only diagnosis result (no bounding boxes, no masks)
        DiagnosisResultCard(
          cropType: _selectedCrop ?? 'Tomato',
          diseaseName: 'Early Blight',
          confidencePercent: 87,
          source: _selectedSource,
          latitude: _diagnosisLatitude,
          longitude: _diagnosisLongitude,
        ),
        const SizedBox(height: 16),

        // Get Treatment Advice (disabled placeholder for future GPT)
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.lightbulb_outline_rounded),
            label: const Text('Get Treatment Advice'),
          ),
        ),
        const SizedBox(height: 12),

        // Scan Another
        SizedBox(
          width: double.infinity,
          height: 52,
          child: TextButton.icon(
            onPressed: _onScanAnother,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(
              'Scan Another',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: MuzhirColors.coreLeafGreen,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ),
      ],
    );
  }
}
