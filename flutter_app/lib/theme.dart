import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Backgrounds
  static const Color bgDark = Color(0xFF0f0f1e);
  static const Color bgCard = Color(0xFF1a1a2e);

  // Text
  static const Color textPrimary = Color(0xFFffffff);
  static const Color textSecondary = Color(0xFFa0a0c0);

  // Border
  static const Color borderColor = Color(0x1AFFFFFF);

  // Gradients
  static const List<Color> primaryGradient = [
    Color(0xFF667eea),
    Color(0xFF764ba2),
  ];
  static const List<Color> secondaryGradient = [
    Color(0xFFf093fb),
    Color(0xFFf5576c),
  ];

  // Glassmorphism
  static const Color glassBg = Color(0x0DFFFFFF);
  static const Color glassBorder = Color(0x1AFFFFFF);
}

class AppTextStyles {
  static TextStyle get h1 => GoogleFonts.outfit(
    fontWeight: FontWeight.w800,
    fontSize: 32,
    color: Colors.white,
    letterSpacing: -0.5,
  );

  static TextStyle get h2 => GoogleFonts.outfit(
    fontWeight: FontWeight.w700,
    fontSize: 24,
    color: Colors.white,
  );

  static TextStyle get h3 => GoogleFonts.outfit(
    fontWeight: FontWeight.w700,
    fontSize: 20,
    color: Colors.white,
  );

  static TextStyle get body =>
      GoogleFonts.inter(fontSize: 16, color: AppColors.textPrimary);

  static TextStyle get input => GoogleFonts.inter(
    fontSize: 16,
    color: AppColors.textPrimary,
    fontWeight: FontWeight.w500,
  );
}
