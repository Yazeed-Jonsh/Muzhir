import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:muzhir/core/api/api_service.dart';
import 'package:muzhir/core/utils/network_url_helper.dart';
import 'package:muzhir/core/utils/translation_helper.dart';
import 'package:muzhir/l10n/app_localizations.dart';
import 'package:muzhir/models/diagnosis_response.dart';
import 'package:muzhir/models/disease_detection.dart';
import 'package:muzhir/models/scan_history_item.dart';
import 'package:muzhir/providers/connectivity_provider.dart';
import 'package:muzhir/screens/farmer/diagnosis_result_detail_screen.dart';
import 'package:muzhir/services/inference_service.dart';
import 'package:muzhir/theme/app_theme.dart';
import 'package:muzhir/widgets/crop_type_dropdown.dart';
import 'package:muzhir/widgets/diagnosis_result_card.dart';
import 'package:muzhir/widgets/recent_scan_tile.dart';
import 'package:muzhir/widgets/treatment_recommendation_modal.dart';

enum _DiagnoseState { idle, preview, result }

/// Farmer Diagnose Page — Natural Organic layout with forest header and capture card.
class DiagnosePage extends ConsumerStatefulWidget {
  const DiagnosePage({
    super.key,
    this.onViewAllRecent,
    this.isTabVisible = false,
    this.refreshSignal = 0,
  });

  /// Switches main navigation to full history (e.g. History tab).
  final VoidCallback? onViewAllRecent;
  final bool isTabVisible;
  final int refreshSignal;

  @override
  ConsumerState<DiagnosePage> createState() => _DiagnosePageState();
}

class _DiagnosePageState extends ConsumerState<DiagnosePage> {
  _DiagnoseState _state = _DiagnoseState.idle;
  ScanSource _selectedSource = ScanSource.mobile;
  String? _selectedCrop;
  bool _isAnalyzing = false;
  File? _selectedImage;
  DiagnosisResponse? _diagnosisResult;
  final ImagePicker _picker = ImagePicker();

  List<ScanHistoryItem> _recentScans = [];
  bool _recentRefreshing = false;

  double? _diagnosisLatitude;
  double? _diagnosisLongitude;

  // ── On-device inference state ─────────────────────────────────────────────
  /// Detections from the on-device YOLO26n model (null when not yet run or
  /// after reset).
  OnDeviceResult? _onDeviceResult;

  /// True when the last analysis used on-device inference (offline fallback).
  bool _isOfflineMode = false;

  static ScanSource _scanSourceFromImageSource(ImageSource source) {
    switch (source) {
      case ImageSource.camera:
      case ImageSource.gallery:
        return ScanSource.mobile;
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchRecentScans();
  }

  @override
  void didUpdateWidget(covariant DiagnosePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final becameVisible = widget.isTabVisible && !oldWidget.isTabVisible;
    final signalChanged = widget.refreshSignal != oldWidget.refreshSignal;
    if (becameVisible || signalChanged) {
      _fetchRecentScans(showRefreshing: true);
    }
  }

  Future<void> _fetchRecentScans({bool showRefreshing = false}) async {
    if (showRefreshing && mounted) {
      setState(() => _recentRefreshing = true);
    }
    try {
      final list = await ApiService().getScanHistory(limit: 3);
      if (!mounted) return;
      setState(() {
        _recentScans = list;
        _recentRefreshing = false;
      });
    } catch (_) {
      // Keep existing list on failure (e.g. offline); first load stays empty.
      if (mounted && showRefreshing) {
        setState(() => _recentRefreshing = false);
      }
    }
  }

  String _recentDiagnosisLabel(ScanHistoryItem item, AppLocalizations l10n) {
    final name = item.diseaseName?.trim();
    if (name != null && name.isNotEmpty) return name;
    if (item.status == 'pending' || item.status == 'processing') {
      return l10n.analysisInProgress;
    }
    return l10n.noDiagnosisYet;
  }

  String _recentRelativeTime(DateTime t, AppLocalizations l10n) {
    final now = DateTime.now();
    final d = now.difference(t);
    if (d.isNegative || d.inSeconds < 45) return l10n.justNow;
    if (d.inMinutes < 60) return l10n.minutesAgo(d.inMinutes);
    if (d.inHours < 24) return l10n.hoursAgo(d.inHours);
    if (d.inDays < 7) return l10n.daysAgo(d.inDays);
    return DateFormat.yMMMd(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(t);
  }

  bool _recentLooksHealthy(String label) {
    final l = label.toLowerCase();
    return l.contains('healthy') ||
        l.contains('no disease') ||
        l.contains('no disease detected');
  }

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

  Future<void> _pickImageForDrone() async {
    final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.gallery);
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
      _diagnosisResult = null;
      _onDeviceResult = null;
      _isOfflineMode = false;
      _diagnosisLatitude = null;
      _diagnosisLongitude = null;
    });
  }

  String _messageFromDioException(DioException e, AppLocalizations l10n) {
    final data = e.response?.data;
    if (data is Map && data['detail'] != null) {
      final d = data['detail'];
      if (d is String) return d;
      if (d is List && d.isNotEmpty) return d.first.toString();
    }
    return e.message ?? l10n.analysisFailed('unknown error');
  }

  String _messageFromDioScanDetail(DioException e, AppLocalizations l10n) {
    final data = e.response?.data;
    if (data is Map && data['detail'] != null) {
      final d = data['detail'];
      if (d is String) return d;
      if (d is List && d.isNotEmpty) return d.first.toString();
    }
    return e.message ?? l10n.couldNotLoadScan;
  }

  Future<void> _openDiagnosisDetail(
    BuildContext context,
    ScanHistoryItem item,
  ) async {
    final navigator = Navigator.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isAr = Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: MuzhirColors.forestGreen.withValues(alpha: 0.85),
        ),
      ),
    );
    try {
      final diagnosis = await ApiService().getScanDiagnosis(item.scanId);
      navigator.pop();
      if (!context.mounted) return;
      final deleted = await navigator.push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => DiagnosisResultDetailScreen(
            diagnosis: diagnosis,
            cropType: isAr ? item.cropNameAr : item.cropName,
          ),
        ),
      );
      if (!context.mounted || deleted != true) return;
      await _fetchRecentScans(showRefreshing: true);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsetsDirectional.all(16),
          backgroundColor: MuzhirColors.forestGreen,
          content: Text(
            l10n.scanRemovedSuccessfully,
            style: GoogleFonts.lexend(
              color: MuzhirColors.cardWhite,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    } on DioException catch (e) {
      if (context.mounted) {
        navigator.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsetsDirectional.all(16),
            backgroundColor: MuzhirColors.earthyClayRed,
            content: Text(
              _messageFromDioScanDetail(e, l10n),
              style: GoogleFonts.lexend(
                color: MuzhirColors.cardWhite,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        navigator.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsetsDirectional.all(16),
            backgroundColor: MuzhirColors.earthyClayRed,
            content: Text(
              l10n.couldNotOpenScan(e.toString()),
              style: GoogleFonts.lexend(
                color: MuzhirColors.cardWhite,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }
    }
  }

  /// Backend `/diagnose` expects a stable crop id (e.g. `tomato`), not the display label.
  String _cropIdForApi(String? displayCrop) {
    final t = displayCrop?.trim().toLowerCase() ?? '';
    if (t == 'tomato') return 'tomato';
    return t.isEmpty ? 'tomato' : t.replaceAll(RegExp(r'\s+'), '_');
  }

  Future<void> _onAnalyze() async {
    if (_selectedCrop == null || _selectedImage == null) return;

    setState(() {
      _isAnalyzing = true;
      _diagnosisResult = null;
      _onDeviceResult = null;
      _isOfflineMode = false;
    });

    // Read connectivity once — no streaming subscription needed here.
    final isOffline = ref.read(isOfflineProvider).value ?? false;

    if (isOffline) {
      await _analyzeOnDevice();
    } else {
      await _analyzeRemote();
    }
  }

  /// On-device inference path (offline / YOLO26n).
  Future<void> _analyzeOnDevice() async {
    try {
      final result =
          await InferenceService.instance.runInference(_selectedImage!);
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _isOfflineMode = true;
        _onDeviceResult = result;
        _state = _DiagnoseState.result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAnalyzing = false);
      _showErrorSnackBar('On-device analysis failed: $e');
    }
  }

  /// Remote API inference path (online).
  Future<void> _analyzeRemote() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final response = await ApiService().uploadImageForDiagnosis(
        _selectedImage!,
        cropId: _cropIdForApi(_selectedCrop),
        growthStageId: 'vegetative',
      );
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _diagnosisResult = response;
        _state = _DiagnoseState.result;
      });
      await _fetchRecentScans(showRefreshing: true);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _isAnalyzing = false);
      _showErrorSnackBar(_messageFromDioException(e, l10n));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAnalyzing = false);
      _showErrorSnackBar(l10n.analysisFailed(e.toString()));
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsetsDirectional.all(16),
        backgroundColor: MuzhirColors.earthyClayRed,
        content: Text(
          message,
          style: GoogleFonts.lexend(
            color: MuzhirColors.cardWhite,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _onScanAnother() {
    setState(() {
      _state = _DiagnoseState.idle;
      _selectedCrop = null;
      _selectedImage = null;
      _isAnalyzing = false;
      _diagnosisResult = null;
      _onDeviceResult = null;
      _isOfflineMode = false;
      _diagnosisLatitude = null;
      _diagnosisLongitude = null;
    });
  }

  void _showCaptureSheet() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: MuzhirColors.cardWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadiusDirectional.only(
          topStart: Radius.circular(20),
          topEnd: Radius.circular(20),
        ),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt_rounded,
                      color: MuzhirColors.forestGreen),
                  title: Text(
                    l10n.camera,
                    style: GoogleFonts.lexend(fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded,
                      color: MuzhirColors.forestGreen),
                  title: Text(
                    l10n.gallery,
                    style: GoogleFonts.lexend(fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool get _hasImage =>
      _selectedImage != null &&
      (_state == _DiagnoseState.preview || _state == _DiagnoseState.result);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: MuzhirColors.creamScaffold,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(context)),
          SliverPadding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 20, 16, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildCaptureCard(context),
                const SizedBox(height: 16),
                _buildQuickCaptureRow(context),
                const SizedBox(height: 24),
                if (_state == _DiagnoseState.preview) ...[
                  _buildPreviewExtras(context),
                  const SizedBox(height: 24),
                ],
                if (_state == _DiagnoseState.result) ...[
                  const SizedBox(height: 8),
                  _buildResultSection(context),
                ],
                if (_state != _DiagnoseState.result)
                  _buildAnalyzeBlock(context),
                const SizedBox(height: 48),
                _buildRecentSection(context),
                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const headerBottomRadius = Radius.circular(30);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: const BorderRadiusDirectional.only(
            bottomStart: headerBottomRadius,
            bottomEnd: headerBottomRadius,
          ),
          child: Container(
            width: double.infinity,
            color: MuzhirColors.forestGreen,
            padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 88, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.diagnoseYourPlant,
                  style: GoogleFonts.lexend(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: MuzhirColors.cardWhite,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.diagnoseHeaderDescription,
                  style: GoogleFonts.lexend(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: MuzhirColors.cardWhite.withValues(alpha: 0.92),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
        const PositionedDirectional(
          end: 4,
          bottom: -8,
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.1,
              child: Icon(
                Icons.spa_rounded,
                size: 132,
                color: MuzhirColors.cardWhite,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCaptureCard(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: MuzhirColors.titleCharcoal.withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: MuzhirColors.titleCharcoal.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsetsDirectional.all(14),
      child: _hasImage
          ? _buildImagePreviewInsideCard(context)
          : _buildEmptyCaptureCardBody(context),
    );
  }

  /// Dotted upload target, file hint, and lighting tip (idle only).
  Widget _buildEmptyCaptureCardBody(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _showCaptureSheet,
            borderRadius: BorderRadius.circular(24),
            child: DottedBorder(
              options: const RoundedRectDottedBorderOptions(
                radius: Radius.circular(24),
                color: Color(0xFFE0E8D9),
                strokeWidth: 2.0,
                dashPattern: [14, 7],
                padding: EdgeInsets.all(4),
                strokeCap: StrokeCap.round,
              ),
              child: SizedBox(
                height: 220,
                width: double.infinity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: MuzhirColors.weatherIconCircle,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add_a_photo_rounded,
                        size: 30,
                        color: MuzhirColors.forestGreen,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
                      child: Text(
                        l10n.tapToUploadOrCaptureImage,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.lexend(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: MuzhirColors.titleCharcoal,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.supportsJpgPng,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.lexend(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: MuzhirColors.mutedGrey.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        _buildCaptureTipRow(),
      ],
    );
  }

  Widget _buildCaptureTipRow() {
    final l10n = AppLocalizations.of(context)!;
    const tipGreen = MuzhirColors.forestGreen;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 14, start: 2, end: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            alignment: AlignmentDirectional.center,
            decoration: BoxDecoration(
              color: tipGreen.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: tipGreen.withValues(alpha: 0.45), width: 1),
            ),
            child: Text(
              'i',
              style: GoogleFonts.lexend(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: tipGreen,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.captureTip,
              style: GoogleFonts.lexend(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                fontStyle: FontStyle.italic,
                color: tipGreen,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreviewInsideCard(BuildContext context) {
    final detections = _onDeviceResult?.detections ?? [];
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Image.file(
              _selectedImage!,
              fit: BoxFit.cover,
            ),
          ),
          // Bounding box overlay — only shown after on-device inference.
          if (detections.isNotEmpty)
            Positioned.fill(
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: CustomPaint(
                  painter: _BoundingBoxPainter(detections),
                ),
              ),
            ),
          if (_state == _DiagnoseState.preview)
            PositionedDirectional(
              top: 10,
              end: 10,
              child: GestureDetector(
                onTap: _onRemoveImage,
                child: Container(
                  padding: const EdgeInsetsDirectional.all(6),
                  decoration: BoxDecoration(
                    color: MuzhirColors.titleCharcoal.withValues(alpha: 0.72),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: MuzhirColors.cardWhite,
                    size: 18,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickCaptureRow(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.quickCapture,
          style: GoogleFonts.lexend(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            color: MuzhirColors.mutedGrey.withValues(alpha: 0.72),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _QuickCaptureChip(
                label: l10n.camera,
                icon: Icons.camera_alt_rounded,
                onTap: () => _pickImage(ImageSource.camera),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _QuickCaptureChip(
                label: l10n.gallery,
                icon: Icons.photo_library_rounded,
                onTap: () => _pickImage(ImageSource.gallery),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _QuickCaptureChip(
                label: l10n.drone,
                customIcon: const _AgriculturalDroneIcon(
                  color: MuzhirColors.forestGreen,
                  size: 24,
                ),
                onTap: _pickImageForDrone,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPreviewExtras(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bool isMobile = _selectedSource == ScanSource.mobile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              isMobile ? Icons.smartphone_rounded : Icons.flight_rounded,
              size: 16,
              color: MuzhirColors.forestGreen,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                l10n.selectedVia(isMobile ? l10n.mobile : l10n.drone),
                style: GoogleFonts.lexend(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: MuzhirColors.titleCharcoal.withValues(alpha: 0.55),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        CropTypeDropdown(
          value: _selectedCrop,
          onChanged: (val) => setState(() => _selectedCrop = val),
        ),
      ],
    );
  }

  Widget _buildAnalyzeBlock(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bool enabled =
        _hasImage && _state == _DiagnoseState.preview && !_isAnalyzing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: enabled ? _onAnalyze : null,
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: MuzhirColors.forestGreen,
              foregroundColor: MuzhirColors.cardWhite,
              disabledBackgroundColor:
                  MuzhirColors.mutedGrey.withValues(alpha: 0.28),
              disabledForegroundColor:
                  MuzhirColors.titleCharcoal.withValues(alpha: 0.78),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              textStyle: GoogleFonts.lexend(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: _isAnalyzing
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        MuzhirColors.cardWhite.withValues(alpha: 0.95),
                      ),
                    ),
                  )
                : Text(l10n.analyzePlant),
          ),
        ),
        if (!enabled && !_isAnalyzing) ...[
          const SizedBox(height: 10),
          Text(
            l10n.pleaseSelectImage,
            textAlign: TextAlign.center,
            style: GoogleFonts.lexend(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: MuzhirColors.mutedGrey,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildResultSection(BuildContext context) {
    return _isOfflineMode
        ? _buildOfflineResultSection(context)
        : _buildOnlineResultSection(context);
  }

  // ── Online result (remote API) ─────────────────────────────────────────────

  Widget _buildOnlineResultSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final d = _diagnosisResult;
    if (d == null) return const SizedBox.shrink();

    final confidencePct =
        (d.diagnosis.confidence * 100).round().clamp(0, 100);
    final isHealthy = d.diagnosis.isHealthy;
    final isAr =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    final recommendationText = isAr
        ? d.recommendation.textAr
        : d.recommendation.textEn;

    return Column(
      children: [
        DiagnosisResultCard(
          cropType: _selectedCrop ?? 'Tomato',
          diseaseName: d.diagnosis.label,
          confidencePercent: confidencePct,
          source: _selectedSource,
          isHealthy: d.diagnosis.isHealthy,
          latitude: d.latitude,
          longitude: d.longitude,
        ),
        if (!isHealthy) ...[
          if (recommendationText.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  showTreatmentRecommendationModal(
                    context,
                    recommendationText: recommendationText,
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: MuzhirColors.forestGreen,
                  side: BorderSide(
                    color: MuzhirColors.forestGreen.withValues(alpha: 0.45),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  minimumSize: const Size(double.infinity, 52),
                  alignment: Alignment.center,
                  tapTargetSize: MaterialTapTargetSize.padded,
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lightbulb_outline_rounded,
                        size: 22,
                        color: MuzhirColors.forestGreen.withValues(alpha: 0.95),
                      ),
                      const SizedBox(width: 10),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width - 120,
                        ),
                        child: Text(
                          l10n.getTreatmentAdvice,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.lexend(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ] else ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
            child: Text(
              l10n.healthyNoTreatment,
              textAlign: TextAlign.center,
              style: GoogleFonts.lexend(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: MuzhirColors.coreLeafGreen,
                height: 1.45,
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: TextButton.icon(
            onPressed: _onScanAnother,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(
              l10n.scanAnother,
              style: GoogleFonts.lexend(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: MuzhirColors.forestGreen,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Offline result (on-device YOLO26n) ────────────────────────────────────

  Widget _buildOfflineResultSection(BuildContext context) {
    final result = _onDeviceResult;
    final detections = result?.detections ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildOfflineBadge(result),
        const SizedBox(height: 12),
        if (detections.isEmpty)
          _buildNoDetectionCard()
        else ...[
          DiagnosisResultCard(
            cropType: _selectedCrop ?? 'Tomato',
            diseaseName: detections.first.labelEn,
            confidencePercent: detections.first.confidencePercent,
            source: _selectedSource,
            isHealthy: detections.first.isHealthy,
            latitude: _diagnosisLatitude,
            longitude: _diagnosisLongitude,
          ),
          if (detections.length > 1) ...[
            const SizedBox(height: 10),
            _buildSecondaryDetections(detections.skip(1).take(2).toList()),
          ],
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: () => _showOfflineLimitationDialog(context),
            icon: const Icon(Icons.wifi_off_rounded),
            label: const Text('Connect for AI Treatment Advice'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: TextButton.icon(
            onPressed: _onScanAnother,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(
              'Scan Another',
              style: GoogleFonts.lexend(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: MuzhirColors.forestGreen,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOfflineBadge(OnDeviceResult? result) {
    final msLabel = result != null
        ? ' · ${result.inferenceMs.toStringAsFixed(0)} ms'
        : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: MuzhirColors.infectionSeriousOrange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: MuzhirColors.infectionSeriousOrange.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.offline_bolt_rounded,
            size: 16,
            color: MuzhirColors.infectionSeriousOrange,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Offline · On-device YOLO26n$msLabel',
              style: GoogleFonts.lexend(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: MuzhirColors.infectionSeriousOrange,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDetectionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MuzhirColors.weatherIconCircle.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            color: MuzhirColors.forestGreen,
            size: 32,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No disease detected',
                  style: GoogleFonts.lexend(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: MuzhirColors.forestGreen,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'The plant appears healthy — or try a clearer, '
                  'closer image for a better result.',
                  style: GoogleFonts.lexend(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: MuzhirColors.mutedGrey,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryDetections(List<DiseaseDetection> others) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'OTHER DETECTIONS',
          style: GoogleFonts.lexend(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: MuzhirColors.mutedGrey.withValues(alpha: 0.75),
          ),
        ),
        const SizedBox(height: 6),
        ...others.map(
          (d) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: MuzhirColors.cardWhite,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color:
                        MuzhirColors.titleCharcoal.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: d.isHealthy
                          ? MuzhirColors.forestGreen
                          : MuzhirColors.infectionSeriousOrange,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      d.labelEn,
                      style: GoogleFonts.lexend(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: MuzhirColors.titleCharcoal,
                      ),
                    ),
                  ),
                  Text(
                    '${d.confidencePercent}%',
                    style: GoogleFonts.lexend(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: MuzhirColors.mutedGrey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showOfflineLimitationDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Connect to the internet',
          style: GoogleFonts.lexend(
            fontWeight: FontWeight.w700,
            color: MuzhirColors.titleCharcoal,
          ),
        ),
        content: Text(
          'AI-powered treatment recommendations require an active connection '
          'to the Muzhir backend. Reconnect and tap "Analyze Plant" again to '
          'get personalised Arabic & English treatment advice.',
          style: GoogleFonts.lexend(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: MuzhirColors.mutedGrey,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'OK',
              style: GoogleFonts.lexend(
                fontWeight: FontWeight.w600,
                color: MuzhirColors.forestGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAr = Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_recentRefreshing)
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                MuzhirColors.forestGreen.withValues(alpha: 0.95),
              ),
              backgroundColor: MuzhirColors.forestGreen.withValues(alpha: 0.18),
            ),
          ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.recentDiagnosis,
              style: GoogleFonts.lexend(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: MuzhirColors.titleCharcoal,
              ),
            ),
            TextButton(
              onPressed: widget.onViewAllRecent,
              style: TextButton.styleFrom(
                foregroundColor: MuzhirColors.forestGreen,
                textStyle: GoogleFonts.lexend(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text(l10n.viewAll),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_recentScans.isEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
            child: Text(
              l10n.noRecentScans,
              style: GoogleFonts.lexend(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: MuzhirColors.mutedGrey,
                height: 1.4,
              ),
            ),
          )
        else
          ..._recentScans.map(
            (scan) {
              final label = _recentDiagnosisLabel(scan, l10n);
              final healthy = _recentLooksHealthy(label);
              return Padding(
                padding: const EdgeInsetsDirectional.only(bottom: 20),
                child: _RecentDiagnosisCard(
                  cropName: isAr ? scan.cropNameAr : scan.cropName,
                  diagnosisLabel: label,
                  timeLabel: _recentRelativeTime(scan.createdAt, l10n),
                  isHealthy: healthy,
                  imageUrl: scan.imageUrl,
                  onTap: () => _openDiagnosisDetail(context, scan),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _RecentDiagnosisCard extends StatelessWidget {
  const _RecentDiagnosisCard({
    required this.cropName,
    required this.diagnosisLabel,
    required this.timeLabel,
    required this.isHealthy,
    required this.imageUrl,
    required this.onTap,
  });

  final String cropName;
  final String diagnosisLabel;
  final String timeLabel;
  final bool isHealthy;
  final String imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = isHealthy
        ? MuzhirColors.forestGreen
        : MuzhirColors.infectionSeriousOrange;
    final url = NetworkUrlHelper.normalizeRemoteUrl(imageUrl);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsetsDirectional.all(14),
          decoration: BoxDecoration(
            color: MuzhirColors.cardWhite,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: MuzhirColors.titleCharcoal.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: url.isEmpty
                      ? ColoredBox(
                          color: MuzhirColors.weatherIconCircle
                              .withValues(alpha: 0.65),
                          child: Icon(
                            Icons.local_florist_rounded,
                            color: MuzhirColors.forestGreen.withValues(alpha: 0.85),
                            size: 28,
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => ColoredBox(
                            color: MuzhirColors.weatherIconCircle
                                .withValues(alpha: 0.5),
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: MuzhirColors.forestGreen
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                          ),
                          errorWidget: (_, imageUrl, error) {
                            debugPrint(
                              '[IMG_ERR] DiagnosePage | $imageUrl | $error',
                            );
                            return ColoredBox(
                              color: MuzhirColors.weatherIconCircle
                                  .withValues(alpha: 0.65),
                              child: Icon(
                                Icons.local_florist_rounded,
                                color: MuzhirColors.forestGreen
                                    .withValues(alpha: 0.85),
                                size: 28,
                              ),
                            );
                          },
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      TranslationHelper.getLocalizedText(context, cropName),
                      style: GoogleFonts.lexend(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: MuzhirColors.titleCharcoal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      TranslationHelper.getLocalizedText(context, diagnosisLabel),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.lexend(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      timeLabel,
                      style: GoogleFonts.lexend(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: MuzhirColors.mutedGrey,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: MuzhirColors.mutedGrey,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickCaptureChip extends StatelessWidget {
  const _QuickCaptureChip({
    required this.label,
    this.icon,
    this.customIcon,
    required this.onTap,
  }) : assert(icon != null || customIcon != null);

  static const Color _chipFill = Color(0xFFF4F5F3);

  final String label;
  final IconData? icon;
  final Widget? customIcon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _chipFill,
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      shadowColor: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsetsDirectional.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: MuzhirColors.titleCharcoal.withValues(alpha: 0.06),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null)
                Icon(
                  icon,
                  size: 22,
                  color: MuzhirColors.forestGreen,
                )
              else
                customIcon!,
              const SizedBox(height: 5),
              Text(
                label,
                style: GoogleFonts.lexend(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: MuzhirColors.forestGreen,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bounding box overlay
// ─────────────────────────────────────────────────────────────────────────────

/// Draws coloured bounding boxes and confidence labels from on-device
/// detections over the image preview widget.
///
/// Bounding box coordinates from [ultralytics_yolo] are normalised to [0, 1]
/// relative to the original image dimensions and are mapped to the rendered
/// widget size here.
class _BoundingBoxPainter extends CustomPainter {
  const _BoundingBoxPainter(this.detections);

  final List<DiseaseDetection> detections;

  static const double _strokeWidth = 2.5;
  static const double _labelHeight = 20.0;
  static const double _fontSize = 11.0;

  @override
  void paint(Canvas canvas, Size size) {
    for (final det in detections) {
      final color =
          det.isHealthy ? MuzhirColors.forestGreen : MuzhirColors.earthyClayRed;

      final rect = Rect.fromLTWH(
        det.boundingBox.left * size.width,
        det.boundingBox.top * size.height,
        det.boundingBox.width * size.width,
        det.boundingBox.height * size.height,
      );

      // Box stroke
      canvas.drawRect(
        rect,
        Paint()
          ..color = color.withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = _strokeWidth,
      );

      // Label background
      final label = '${det.labelEn}  ${det.confidencePercent}%';
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Color(0xFFFFFFFF),
            fontSize: _fontSize,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width);

      final bgLeft = rect.left;
      final bgTop = (rect.top - _labelHeight).clamp(0.0, size.height);
      final bgWidth = (tp.width + 12).clamp(0.0, size.width - bgLeft);

      canvas.drawRRect(
        RRect.fromLTRBR(
          bgLeft,
          bgTop,
          bgLeft + bgWidth,
          bgTop + _labelHeight,
          const Radius.circular(4),
        ),
        Paint()..color = color,
      );

      tp.paint(
        canvas,
        Offset(bgLeft + 6, bgTop + (_labelHeight - tp.height) / 2),
      );
    }
  }

  @override
  bool shouldRepaint(_BoundingBoxPainter old) =>
      old.detections != detections;
}

/// Quadcopter silhouette with leaf badge — reads as crop-spraying / field drone.
class _AgriculturalDroneIcon extends StatelessWidget {
  const _AgriculturalDroneIcon({
    required this.color,
    this.size = 28,
  });

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: AlignmentDirectional.center,
        children: [
          Icon(Icons.flight_rounded, size: size * 0.88, color: color),
          PositionedDirectional(
            end: -1,
            bottom: -1,
            child: Container(
              padding: const EdgeInsetsDirectional.all(1.5),
              decoration: const BoxDecoration(
                color: MuzhirColors.cardWhite,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.eco_rounded,
                size: size * 0.38,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
