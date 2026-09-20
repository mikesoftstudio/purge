import 'package:flutter/material.dart';

import '../engine/types.dart';
import '../ui/strings.dart';

class SafetyBadge extends StatelessWidget {
  const SafetyBadge({super.key, required this.tier});

  final SafetyTier tier;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (bg, fg, border, label) = switch (tier) {
      SafetyTier.safe => (
          isDark ? const Color(0xFF052E16) : const Color(0xFFECFDF5),
          isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
          isDark ? const Color(0xFF166534) : const Color(0xFFA7F3D0),
          Strings.safe,
        ),
      SafetyTier.moderate => (
          isDark ? const Color(0xFF451A03) : const Color(0xFFFFFBEB),
          isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309),
          isDark ? const Color(0xFF92400E) : const Color(0xFFFDE68A),
          Strings.moderate,
        ),
      SafetyTier.advanced => (
          isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2),
          isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
          isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA),
          Strings.advanced,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
