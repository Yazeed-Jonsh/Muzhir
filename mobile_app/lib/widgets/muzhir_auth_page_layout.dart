import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:muzhir/theme/app_theme.dart';

/// Small label above an auth text field (reference-style).
Widget muzhirAuthInputLabel(String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: GoogleFonts.lexend(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: MuzhirColors.titleCharcoal,
        ),
      ),
    ),
  );
}

/// Shared cream-filled field decoration (no floating label — use [muzhirAuthInputLabel] above).
InputDecoration muzhirAuthInputDecoration({
  required BuildContext context,
  required IconData prefixIcon,
  String? hintText,
  Widget? suffixIcon,
  bool subtleHint = false,
}) {
  final fieldOutline = MuzhirColors.weatherIconCircle.withValues(alpha: 0.85);
  final hintAlpha = subtleHint ? 0.38 : 0.75;
  return InputDecoration(
    filled: true,
    fillColor: MuzhirColors.creamScaffold,
    hintText: hintText,
    hintStyle: GoogleFonts.lexend(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: MuzhirColors.mutedGrey.withValues(alpha: hintAlpha),
    ),
    floatingLabelBehavior: FloatingLabelBehavior.never,
    prefixIcon: Icon(prefixIcon, color: MuzhirColors.forestGreen),
    suffixIcon: suffixIcon,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: fieldOutline, width: 1),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: fieldOutline, width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(
        color: MuzhirColors.forestGreen,
        width: 1.5,
      ),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide:
          BorderSide(color: Theme.of(context).colorScheme.error, width: 2),
    ),
  );
}

/// Centered footer line: subtle grey question + bold [MuzhirColors.forestGreen] action.
/// Wrap in [TextButton] (or [GestureDetector]) in the screen to handle navigation.
Widget muzhirAuthFooterLinkRichText({
  required String question,
  required String action,
}) {
  final questionStyle = GoogleFonts.lexend(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: MuzhirColors.titleCharcoal.withValues(alpha: 0.48),
  );
  final actionStyle = GoogleFonts.lexend(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: MuzhirColors.forestGreen,
  );
  return RichText(
    textAlign: TextAlign.center,
    text: TextSpan(
      style: questionStyle,
      children: [
        TextSpan(text: question),
        TextSpan(text: action, style: actionStyle),
      ],
    ),
  );
}

/// Forest header and white card; screens pass fields and footer inside [cardContent].
class MuzhirAuthPageLayout extends StatelessWidget {
  const MuzhirAuthPageLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.cardContent,
    this.showBackButton = false,
  });

  final String title;
  final String subtitle;
  final Widget cardContent;
  final bool showBackButton;

  static const double _cardRadius = 30;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: MuzhirColors.creamScaffold,
      body: SafeArea(
        top: false,
        bottom: true,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          clipBehavior: Clip.none,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AuthGreenHeader(
                topInset: topInset,
                title: title,
                subtitle: subtitle,
                showBackButton: showBackButton,
              ),
              Transform.translate(
                offset: const Offset(0, -40),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: MuzhirColors.cardWhite,
                      borderRadius: BorderRadius.circular(_cardRadius),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 40,
                          offset: const Offset(0, 18),
                          spreadRadius: -8,
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(_cardRadius),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          28,
                          34,
                          28,
                          34,
                        ),
                        child: cardContent,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthGreenHeader extends StatelessWidget {
  const _AuthGreenHeader({
    required this.topInset,
    required this.title,
    required this.subtitle,
    required this.showBackButton,
  });

  final double topInset;
  final String title;
  final String subtitle;
  final bool showBackButton;

  static const Color _headerGreenLight = Color(0xFF557A4A);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              MuzhirColors.forestGreen,
              _headerGreenLight,
            ],
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _AuthHeaderLeafTexturePainter(),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(24, topInset + 16, 24, 56),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (showBackButton)
                    Positioned(
                      top: 0,
                      left: -8,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  Column(
                    children: [
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: MuzhirColors.weatherIconCircle
                                .withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.18),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              'assets/logos/muzhir_logo.jpeg',
                              height: 44,
                              width: 44,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.lexend(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.lexend(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withValues(alpha: 0.92),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Very subtle organic texture on the forest header.
class _AuthHeaderLeafTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()..style = PaintingStyle.fill;

    void leaf(double cx, double cy, double w, double h, double rotation) {
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(rotation);
      base.color = Colors.white.withValues(alpha: 0.045);
      canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: w, height: h), base);
      base.color = Colors.white.withValues(alpha: 0.03);
      canvas.drawOval(
        Rect.fromCenter(
            center: const Offset(4, -3), width: w * 0.55, height: h * 0.45),
        base,
      );
      canvas.restore();
    }

    leaf(size.width * 0.12, size.height * 0.25, size.width * 0.45,
        size.width * 0.22, 0.35);
    leaf(size.width * 0.88, size.height * 0.35, size.width * 0.5,
        size.width * 0.2, -0.5);
    leaf(size.width * 0.55, size.height * 0.08, size.width * 0.35,
        size.width * 0.16, 0.9);
    leaf(size.width * 0.35, size.height * 0.75, size.width * 0.4,
        size.width * 0.18, -0.25);
    leaf(size.width * 0.75, size.height * 0.85, size.width * 0.38,
        size.width * 0.15, 0.6);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Primary forest-green CTA with white label + arrow.
class MuzhirAuthPrimaryButton extends StatefulWidget {
  const MuzhirAuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  State<MuzhirAuthPrimaryButton> createState() => _MuzhirAuthPrimaryButtonState();
}

class _MuzhirAuthPrimaryButtonState extends State<MuzhirAuthPrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MuzhirColors.forestGreen,
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: widget.loading ? null : widget.onPressed,
        onHighlightChanged: widget.loading
            ? null
            : (highlighted) => setState(() => _pressed = highlighted),
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: Center(
            child: widget.loading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : AnimatedScale(
                    scale: _pressed ? 0.98 : 1,
                    duration: const Duration(milliseconds: 120),
                    curve: Curves.easeOutCubic,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          widget.label,
                          style: GoogleFonts.lexend(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
