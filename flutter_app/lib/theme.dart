import 'package:flutter/material.dart';
import 'services/theme_service.dart';

class AppColors {
  // Backgrounds
  static const Color bgDark = Color(0xFF0f0f1e);
  static const Color bgCard = Color(0xFF1a1a2e);

  // Light Mode (Glass) Backgrounds
  static const Color bgLight = Color(0xFFF7F8FC);
  static const Color bgCardLight = Color(0xFFFFFFFF);

  // Text
  static const Color textPrimary = Color(0xFFffffff);
  static const Color textSecondary = Color(0xFFa0a0c0);

  // Light Mode Text
  static const Color textPrimaryLight = Color(0xFF1a1a2e);
  static const Color textSecondaryLight = Color(0xFF6b7280);

  // Border
  static const Color borderColor = Color(0x1AFFFFFF);
  static const Color borderColorLight = Color(0x1A000000);

  // Gradients
  static const List<Color> primaryGradient = [
    Color(0xFF667eea),
    Color(0xFF764ba2),
  ];
  static const List<Color> secondaryGradient = [
    Color(0xFFf093fb),
    Color(0xFFf5576c),
  ];

  static Color getTextColor() =>
      themeService.isGlass ? textPrimaryLight : textPrimary;

  static Color getSecondaryTextColor() =>
      themeService.isGlass ? textSecondaryLight : textSecondary;

  static Color get glassBg => themeService.isGlass
      ? Colors.white.withOpacity(0.8)
      : const Color(0x0DFFFFFF);

  static Color get glassBorder =>
      themeService.isGlass ? const Color(0x1A000000) : const Color(0x1AFFFFFF);
}

class AppTextStyles {
  static TextStyle get h1 => TextStyle(
    fontWeight: FontWeight.w800,
    fontSize: 32,
    color: AppColors.getTextColor(),
    letterSpacing: -0.5,
  );

  static TextStyle get h2 => TextStyle(
    fontWeight: FontWeight.w700,
    fontSize: 24,
    color: AppColors.getTextColor(),
  );

  static TextStyle get h3 => TextStyle(
    fontWeight: FontWeight.w700,
    fontSize: 20,
    color: AppColors.getTextColor(),
  );

  static TextStyle get body => TextStyle(
    fontSize: 16,
    color: AppColors.getTextColor(),
  );

  static TextStyle get input => TextStyle(
    fontSize: 16,
    color: AppColors.getTextColor(),
    fontWeight: FontWeight.w500,
  );
}
