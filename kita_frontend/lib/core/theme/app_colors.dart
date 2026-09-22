import 'package:flutter/material.dart';

/// Centralized color palette for the Kita application,
/// capturing a refined Chess.com-inspired tactical aesthetic.
class AppColors {
  AppColors._();

  // --- Signature Brand & Chess Colors ---
  static const Color primaryGreen = Color(0xFF81B64C);
  static const Color primaryGreenHover = Color(0xFF91C55C);
  static const Color primaryGreenDark = Color(0xFF587E32); // 3D bevel shadow
  static const Color accentGreen = Color(0xFFA8D06B);

  static const Color boardDarkSquare = Color(0xFF769656);
  static const Color boardLightSquare = Color(0xFFEEEED2);
  static const Color boardHighlight = Color(0xFFF7F769);

  // --- Rating & Badges ---
  static const Color ratingGold = Color(0xFFFFC83B);
  static const Color accentGold = Color(0xFFFFC83B);
  static const Color silverMedal = Color(0xFFC0C0C0);
  static const Color bronzeMedal = Color(0xFFCD7F32);
  static const Color guestOrange = Color(0xFFF39C12);
  static const Color winBlue = Color(0xFF3498DB);
  static const Color lossRed = Color(0xFFE74C3C);
  static const Color drawGray = Color(0xFF95A5A6);

  // --- Move Quality & Evaluation Indicators ---
  static const Color evalGood = Color(0xFF81B64C);
  static const Color evalGoodBg = Color(0x2A81B64C);
  static const Color evalInaccuracy = Color(0xFFF39C12);
  static const Color evalInaccuracyBg = Color(0x2AF39C12);
  static const Color evalMistake = Color(0xFFE67E22);
  static const Color evalMistakeBg = Color(0x2AE67E22);
  static const Color evalBlunder = Color(0xFFE74C3C);
  static const Color evalBlunderBg = Color(0x2AE74C3C);
  static const Color evalNeutral = Color(0xFF95A5A6);
  static const Color evalNeutralBg = Color(0x2095A5A6);

  // --- Dark Theme Surfaces (Default Chess.com dark mode) ---
  static const Color darkBg = Color(0xFF161512);
  static const Color darkCard = Color(0xFF262421);
  static const Color darkSurface = Color(0xFF302E2B);
  static const Color darkSurfaceElevated = Color(0xFF3B3835);
  static const Color darkBorder = Color(0xFF45423E);
  static const Color darkDivider = Color(0xFF383531);

  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFB0ACA6);
  static const Color darkTextMuted = Color(0xFF7A7670);

  // --- Light Theme Surfaces ---
  static const Color lightBg = Color(0xFFF0EFEB);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFE5E3DD);
  static const Color lightSurfaceElevated = Color(0xFFDCDAD3);
  static const Color lightBorder = Color(0xFFD0CDC4);
  static const Color lightDivider = Color(0xFFE0DDD5);

  static const Color lightTextPrimary = Color(0xFF262421);
  static const Color lightTextSecondary = Color(0xFF6B6761);
  static const Color lightTextMuted = Color(0xFF9E9A92);

  // --- Semantic Feedback ---
  static const Color error = Color(0xFFE64C3C);
  static const Color errorDark = Color(0xFFB03A2E);
  static const Color warning = Color(0xFFF39C12);
  static const Color info = Color(0xFF2980B9);
  static const Color success = Color(0xFF81B64C);

  // --- Helpers depending on Brightness ---
  static Color getBackground(bool isDark) => isDark ? darkBg : lightBg;
  static Color getCard(bool isDark) => isDark ? darkCard : lightCard;
  static Color getSurface(bool isDark) => isDark ? darkSurface : lightSurface;
  static Color getBorder(bool isDark) => isDark ? darkBorder : lightBorder;
  static Color getTextPrimary(bool isDark) => isDark ? darkTextPrimary : lightTextPrimary;
  static Color getTextSecondary(bool isDark) => isDark ? darkTextSecondary : lightTextSecondary;
  static Color getTextMuted(bool isDark) => isDark ? darkTextMuted : lightTextMuted;
}
