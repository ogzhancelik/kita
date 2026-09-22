import 'package:flutter/material.dart';

/// Centralized color palette for the Kita application,
/// capturing a refined Chess.com-inspired tactical aesthetic.
class AppColors {
  AppColors._();

  // --- Signature Brand & Accent Colors ---
  static const Color primary = Color(
    0xFF693C51,
  ); // Ana Renk (Brand Plum / Burgundy)
  static const Color primaryDark = Color.fromARGB(
    255,
    24,
    13,
    31,
  ); // Ana Renk 2 (Deep Midnight Obsidian)
  static const Color primaryHover = Color(0xFF7E4A63); // Lighter plum for hover
  static const Color primaryShadow = Color(
    0xFF462535,
  ); // 3D bevel shadow for plum
  static const Color primaryLight = Color(
    0xFFD68CAE,
  ); // Luminous Plum for Dark Mode text/icons
  static const Color primaryVibrant = Color(
    0xFF8A4066,
  ); // Rich Saturated Plum for dark containers

  static const Color accent = Color(
    0xFFA8D8C6,
  ); // Accent Renk (Soft Mint / Seafoam)
  static const Color accentSecondary = Color(
    0xFF75B69C,
  ); // Accent Renk 2 (Vibrant Seafoam Jade)
  static const Color accentDark = Color(
    0xFF4C856F,
  ); // 3D bevel shadow for accent buttons

  // Interactive Action Colors (Aliased to vibrant accent for high contrast & pop)
  static const Color primaryGreen =
      accentSecondary; // #75B69C: Main interactive CTA
  static const Color primaryGreenHover = accent; // #A8D8C6: Hover state
  static const Color primaryGreenDark = accentDark; // #4C856F: 3D button shadow
  static const Color accentGreen = accent; // #A8D8C6

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
  static const Color evalGood = Color(0xFF75B69C);
  static const Color evalGoodBg = Color(0x2A75B69C);
  static const Color evalInaccuracy = Color(0xFFF39C12);
  static const Color evalInaccuracyBg = Color(0x2AF39C12);
  static const Color evalMistake = Color(0xFFE67E22);
  static const Color evalMistakeBg = Color(0x2AE67E22);
  static const Color evalBlunder = Color(0xFFE74C3C);
  static const Color evalBlunderBg = Color(0x2AE74C3C);
  static const Color evalNeutral = Color(0xFF95A5A6);
  static const Color evalNeutralBg = Color(0x2095A5A6);

  // --- Dark Theme Surfaces ---
  // Deep dark obsidian canvas (#16081F) so dark mode is truly deep and immersive
  static const Color darkBg = Color.fromARGB(255, 23, 17, 28);
  // Cards use the #282828 surface from the palette, providing clean elevation & contrast
  static const Color darkCard = Color.fromARGB(255, 30, 25, 34);
  static const Color darkSurface = Color.fromARGB(255, 47, 37, 59);
  static const Color darkSurfaceElevated = Color(0xFF4D4062);
  static const Color darkBorder = Color(0xFF453F4C);
  static const Color darkDivider = Color(0xFF352F3B);

  static const Color darkTextPrimary = Color(0xFFF5F6F6);
  static const Color darkTextSecondary = Color(0xFFC0BEC4);
  static const Color darkTextMuted = Color(0xFF8A8590);

  // --- Light Theme Surfaces ---
  static const Color lightBg = Color(0xFFF3F4F4);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFE6E8E8);
  static const Color lightSurfaceElevated = Color(0xFFDCE0E0);
  static const Color lightBorder = Color(0xFFD0D5D5);
  static const Color lightDivider = Color(0xFFDFE2E2);

  static const Color lightTextPrimary = Color(0xFF16081F);
  static const Color lightTextSecondary = Color(0xFF5D5760);
  static const Color lightTextMuted = Color(0xFF8E8A92);

  // --- Semantic Feedback ---
  static const Color error = Color(0xFFE64C3C);
  static const Color errorDark = Color(0xFFB03A2E);
  static const Color warning = Color(0xFFF39C12);
  static const Color info = Color(0xFF2980B9);
  static const Color success = Color(0xFF75B69C);

  // --- Helpers depending on Brightness ---
  static Color getBackground(bool isDark) => isDark ? darkBg : lightBg;
  static Color getCard(bool isDark) => isDark ? darkCard : lightCard;
  static Color getSurface(bool isDark) => isDark ? darkSurface : lightSurface;
  static Color getBorder(bool isDark) => isDark ? darkBorder : lightBorder;
  static Color getTextPrimary(bool isDark) =>
      isDark ? darkTextPrimary : lightTextPrimary;
  static Color getTextSecondary(bool isDark) =>
      isDark ? darkTextSecondary : lightTextSecondary;
  static Color getTextMuted(bool isDark) =>
      isDark ? darkTextMuted : lightTextMuted;
  static Color getBrandPrimary(bool isDark) => isDark ? primaryLight : primary;
}
