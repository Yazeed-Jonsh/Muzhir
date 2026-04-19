import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:muzhir/models/diagnosis_response.dart';
import 'package:muzhir/theme/app_theme.dart';

bool _localeIsArabic(BuildContext context) {
  final code = Localizations.localeOf(context).languageCode.toLowerCase();
  return code == 'ar';
}

/// Shows stored [diagnosis.recommendation] only (no API calls).
void presentTreatmentAdviceDialog(
  BuildContext context,
  DiagnosisResponse diagnosis,
) {
  showDialog<void>(
    context: context,
    builder: (ctx) {
      final isAr = _localeIsArabic(ctx);
      final rec = diagnosis.recommendation;
      final body = isAr
          ? (rec.textAr.isEmpty ? '—' : rec.textAr)
          : (rec.textEn.isEmpty ? '—' : rec.textEn);
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          isAr ? 'نصائح العلاج' : 'Treatment advice',
          textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
          style: GoogleFonts.lexend(
            fontWeight: FontWeight.w700,
            color: MuzhirColors.titleCharcoal,
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            body,
            textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
            style: GoogleFonts.lexend(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: MuzhirColors.titleCharcoal,
              height: isAr ? 1.5 : 1.4,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              isAr ? 'إغلاق' : 'Close',
              style: GoogleFonts.lexend(
                fontWeight: FontWeight.w600,
                color: MuzhirColors.forestGreen,
              ),
            ),
          ),
        ],
      );
    },
  );
}
