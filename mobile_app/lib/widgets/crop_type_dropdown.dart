import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:muzhir/theme/app_theme.dart';

/// Dropdown for selecting crop type before analysis.
/// V1: only "Tomato" is available.
class CropTypeDropdown extends StatelessWidget {
  const CropTypeDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String? value;
  final ValueChanged<String?> onChanged;

  static const List<String> _cropTypes = ['Tomato'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Crop Type',
          style: GoogleFonts.lexend(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: MuzhirColors.titleCharcoal,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: MuzhirColors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: MuzhirColors.deepCharcoal.withValues(alpha: 0.12),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: MuzhirColors.deepCharcoal.withValues(alpha: 0.12),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: MuzhirColors.coreLeafGreen,
                width: 1.5,
              ),
            ),
            prefixIcon: const Icon(
              Icons.local_florist_rounded,
              color: MuzhirColors.coreLeafGreen,
            ),
          ),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: MuzhirColors.coreLeafGreen,
          ),
          dropdownColor: MuzhirColors.white,
          style: Theme.of(context).textTheme.bodyLarge,
          hint: Text(
            'Select crop type',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: MuzhirColors.deepCharcoal.withValues(alpha: 0.4),
                ),
          ),
          items: _cropTypes
              .map((crop) => DropdownMenuItem(
                    value: crop,
                    child: Text(crop),
                  ))
              .toList(),
        ),
      ],
    );
  }
}
