import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:muzhir/core/api/api_service.dart';
import 'package:muzhir/models/diagnosis_response.dart';
import 'package:muzhir/models/scan_history_item.dart';
import 'package:muzhir/screens/farmer/diagnosis_result_detail_screen.dart';
import 'package:muzhir/theme/app_theme.dart';
import 'package:muzhir/widgets/crop_type_dropdown.dart';
import 'package:muzhir/widgets/diagnosis_result_card.dart';
import 'package:muzhir/widgets/recent_scan_tile.dart';
import 'package:muzhir/widgets/treatment_advice_dialog.dart';

enum _DiagnoseState { idle, preview, result }

/// Farmer Diagnose Page — Natural Organic layout with forest header and capture card.
class DiagnosePage extends StatefulWidget {
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
  State<DiagnosePage> createState() => _DiagnosePageState();
}

class _DiagnosePageState extends State<DiagnosePage> {
  _DiagnoseState _state = _DiagnoseState.idle;
  ScanSource _selectedSource = ScanSource.mobile;
  String? _selectedCrop;
  bool _isAnalyzing = false;
  File? _selectedImage;
  DiagnosisResponse? _diagnosisResult;
  final ImagePicker _picker = ImagePicker();

  List<ScanHistoryItem> _recentScans = [];
  bool _recentRefreshing = false;

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

  String _recentDiagnosisLabel(ScanHistoryItem item) {
    final name = item.diseaseName?.trim();
    if (name != null && name.isNotEmpty) return name;
    if (item.status == 'pending' || item.status == 'processing') {
      return 'Analysis in progress';
    }
    return 'No diagnosis yet';
  }

  String _recentRelativeTime(DateTime t) {
    final now = DateTime.now();
    final d = now.difference(t);
    if (d.isNegative) return 'Just now';
    if (d.inSeconds < 45) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} hours ago';
    if (d.inDays < 7) return '${d.inDays} days ago';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[t.month - 1]} ${t.day}, ${t.year}';
  }

  bool _recentLooksHealthy(String label) {
    final l = label.toLowerCase();
    return l.contains('healthy') ||
        l.contains('no disease') ||
        l.contains('no disease detected');
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null && mounted) {
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
    });
  }

  String _messageFromDioException(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['detail'] != null) {
      final d = data['detail'];
      if (d is String) return d;
      if (d is List && d.isNotEmpty) return d.first.toString();
    }
    return e.message ?? 'Could not analyze image. Please try again.';
  }

  String _messageFromDioScanDetail(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['detail'] != null) {
      final d = data['detail'];
      if (d is String) return d;
      if (d is List && d.isNotEmpty) return d.first.toString();
    }
    return e.message ?? 'Could not load scan details.';
  }

  Future<void> _openDiagnosisDetail(
    BuildContext context,
    ScanHistoryItem item,
  ) async {
    final navigator = Navigator.of(context);
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
            cropType: item.cropName,
          ),
        ),
      );
      if (!context.mounted || deleted != true) return;
      await _fetchRecentScans(showRefreshing: true);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          backgroundColor: MuzhirColors.forestGreen,
          content: Text(
            'Scan removed successfully',
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
            margin: const EdgeInsets.all(16),
            backgroundColor: MuzhirColors.earthyClayRed,
            content: Text(
              _messageFromDioScanDetail(e),
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
            margin: const EdgeInsets.all(16),
            backgroundColor: MuzhirColors.earthyClayRed,
            content: Text(
              'Could not open scan: $e',
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
    });

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
      final message = _messageFromDioException(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAnalyzing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          backgroundColor: MuzhirColors.earthyClayRed,
          content: Text(
            'Analysis failed: $e',
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

  void _onScanAnother() {
    setState(() {
      _state = _DiagnoseState.idle;
      _selectedCrop = null;
      _selectedImage = null;
      _isAnalyzing = false;
      _diagnosisResult = null;
    });
  }

  void _showTreatmentAdviceDialog(BuildContext context) {
    final d = _diagnosisResult;
    if (d == null) return;
    presentTreatmentAdviceDialog(context, d);
  }

  void _showCaptureSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: MuzhirColors.cardWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt_rounded,
                      color: MuzhirColors.forestGreen),
                  title: Text(
                    'Camera',
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
                    'Gallery',
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
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
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
    const headerBottomRadius = Radius.circular(30);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: headerBottomRadius,
            bottomRight: headerBottomRadius,
          ),
          child: Container(
            width: double.infinity,
            color: MuzhirColors.forestGreen,
            padding: const EdgeInsets.fromLTRB(20, 12, 88, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Diagnose Your Plant',
                  style: GoogleFonts.lexend(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: MuzhirColors.cardWhite,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Upload or capture a plant image to detect diseases using our advanced AI botanical analysis engine.',
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
        const Positioned(
          right: 4,
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
      padding: const EdgeInsets.all(14),
      child: _hasImage
          ? _buildImagePreviewInsideCard(context)
          : _buildEmptyCaptureCardBody(context),
    );
  }

  /// Dotted upload target, file hint, and lighting tip (idle only).
  Widget _buildEmptyCaptureCardBody(BuildContext context) {
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
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'Tap to upload or capture image',
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
                      'Supports JPG, PNG up to 10MB',
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
    const tipGreen = MuzhirColors.forestGreen;
    return Padding(
      padding: const EdgeInsets.only(top: 14, left: 2, right: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
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
              'Ensure the leaf is clear and well-lit for best results',
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
          if (_state == _DiagnoseState.preview)
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: _onRemoveImage,
                child: Container(
                  padding: const EdgeInsets.all(6),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QUICK CAPTURE',
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
                label: 'Camera',
                icon: Icons.camera_alt_rounded,
                onTap: () => _pickImage(ImageSource.camera),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _QuickCaptureChip(
                label: 'Gallery',
                icon: Icons.photo_library_rounded,
                onTap: () => _pickImage(ImageSource.gallery),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _QuickCaptureChip(
                label: 'Drone',
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
    final bool isMobile = _selectedSource == ScanSource.mobile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              isMobile ? Icons.smartphone_rounded : Icons.flight_rounded,
              size: 16,
              color: MuzhirColors.forestGreen,
            ),
            const SizedBox(width: 6),
            Text(
              'Selected via: ${isMobile ? 'Mobile' : 'Drone'}',
              style: GoogleFonts.lexend(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: MuzhirColors.titleCharcoal.withValues(alpha: 0.55),
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
                : const Text('Analyze Plant'),
          ),
        ),
        if (!enabled && !_isAnalyzing) ...[
          const SizedBox(height: 10),
          Text(
            'Please select an image to enable analysis',
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
    final d = _diagnosisResult;
    if (d == null) {
      return const SizedBox.shrink();
    }

    final confidencePct =
        (d.diagnosis.confidence * 100).round().clamp(0, 100);
    final isHealthy = d.diagnosis.isHealthy;
    final isAr =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';

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
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () => _showTreatmentAdviceDialog(context),
              icon: const Icon(Icons.lightbulb_outline_rounded),
              label: Text(
                isAr ? 'عرض نصائح العلاج' : 'Get Treatment Advice',
              ),
            ),
          ),
        ] else ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              isAr
                  ? 'نباتك بصحة جيدة! لا حاجة للعلاج.'
                  : 'Your plant is healthy! No treatment needed.',
              textAlign: TextAlign.center,
              textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
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

  Widget _buildRecentSection(BuildContext context) {
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
              'Recent Diagnosis',
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
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_recentScans.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No recent scans yet. Run an analysis above to see your latest results here.',
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
              final label = _recentDiagnosisLabel(scan);
              final healthy = _recentLooksHealthy(label);
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: _RecentDiagnosisCard(
                  cropName: scan.cropName,
                  diagnosisLabel: label,
                  timeLabel: _recentRelativeTime(scan.createdAt),
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
    final url = imageUrl.trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(14),
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
                          errorWidget: (_, __, ___) => ColoredBox(
                            color: MuzhirColors.weatherIconCircle
                                .withValues(alpha: 0.65),
                            child: Icon(
                              Icons.local_florist_rounded,
                              color: MuzhirColors.forestGreen.withValues(alpha: 0.85),
                              size: 28,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cropName,
                      style: GoogleFonts.lexend(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: MuzhirColors.titleCharcoal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      diagnosisLabel,
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
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
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
        alignment: Alignment.center,
        children: [
          Icon(Icons.flight_rounded, size: size * 0.88, color: color),
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              padding: const EdgeInsets.all(1.5),
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
