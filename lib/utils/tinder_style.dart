import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared palette and [GoogleFonts.outfit] styles for dark-background + white-card UI.
abstract final class TinderStyle {
  static const ink = Color(0xFF111827);
  static const muted = Color(0xFF6B7280);
  static const subtle = Color(0xFF9CA3AF);
  static const border = Color(0xFFE5E7EB);
  static const line = Color(0xFFECECEC);

  static TextStyle screenTitle({Color color = Colors.white}) => GoogleFonts.outfit(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        height: 1.05,
        color: color,
      );

  static TextStyle screenSubtitle(Color color) => GoogleFonts.outfit(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.35,
        color: color,
      );

  static TextStyle sectionCaps({Color? color}) => GoogleFonts.outfit(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.6,
        color: color ?? subtle,
      );

  static TextStyle cardTitle({Color color = ink}) => GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: color,
      );

  static TextStyle cardSubtitle({Color color = muted}) => GoogleFonts.outfit(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.3,
        color: color,
      );

  static TextStyle bodyCard({Color color = ink}) => GoogleFonts.outfit(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        height: 1.45,
        color: color,
      );

  static TextStyle bodyOnDarkMuted({double alpha = 0.62}) => GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.45,
        color: Colors.white.withValues(alpha: alpha),
      );

  static BoxShadow cardShadow() => BoxShadow(
        color: Colors.black.withValues(alpha: 0.14),
        blurRadius: 20,
        offset: const Offset(0, 8),
      );
}
