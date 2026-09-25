import 'package:flutter/material.dart';

/// Centralized color palette for the Kita application,
/// capturing a refined Chess.com-inspired tactical aesthetic.
class AppColors {
  AppColors._();

  // --- Signature Brand & Accent Colors ---
  static const Color primary = Color(
    0xFF863653,
  ); // Ana Renk (Reddish Purplish / Crimson Berry Wine)
  static const Color primaryDark = Color(
    0xFF5A2236,
  ); // Deep Purplish Shadow
  static const Color primaryHover = Color(0xFF9E4366); // Lighter reddish-purple for hover
  static const Color primaryShadow = Color(
    0xFF501E30,
  ); // 3D bevel shadow for reddish-purple
  static const Color primaryLight = Color(
    0xFFD68CAE,
  ); // Luminous Plum for Dark Mode text/icons
  static const Color primaryVibrant = Color(
    0xFF863653,
  ); // Rich Saturated Purplish Red

  static const Color accent = Color(
    0xFFA8D8C6,
  ); // Accent Renk (Soft Mint / Seafoam)
  static const Color accentSecondary = Color(
    0xFF75B69C,
  ); // Accent Renk 2 (Vibrant Seafoam Jade)
  static const Color accentDark = Color(
    0xFF4C856F,
  ); // 3D bevel shadow for accent buttons

  // Interactive Action Colors (Main action is reddish purplish)
  static const Color primaryGreen = primary; // #863653: Main interactive CTA
  static const Color primaryGreenHover = primaryHover; // #9E4366: Hover state
  static const Color primaryGreenDark = primaryShadow; // #501E30: 3D button shadow
  static const Color accentGreen = accent; // #A8D8C6: Mint Accent

  static const Color boardDarkSquare = Color(0xFF769656);
  static const Color boardLightSquare = Color(0xFFEEEED2);
  static const Color boardHighlight = Color(0xFFF7F769);
  static const Color boardOceanHighlight = Color(0xFF00F5D4); // Vibrant bioluminescent aquamarine for Ocean Azure theme
  static const Color boardOceanSelected = Color(0xFFFFD166); // Sunlit warm gold for Ocean Azure theme

  // --- Rating & Badges ---
  static const Color ratingGold = Color(0xFFFFC83B);
  static const Color accentGold = Color(0xFFFFC83B);
  static const Color silverMedal = Color(0xFFC0C0C0);
  static const Color bronzeMedal = Color(0xFFCD7F32);
  static const Color guestOrange = Color(0xFFF39C12);
  static const Color winGreen = Color(0xFF70EFBF); // Vibrant Emerald Green for wins
  static const Color winBlue = Color(0xFF3498DB);
  static const Color lossRed = Color(0xFFE74C3C);
  static const Color drawGray = Color(0xFF3D4444);

  // --- Positive & Status Indicators (Accents: #A8D8C6 / #75B69C) ---
  static const Color online = accent; // #A8D8C6: Açık mint yeşili (çevrimiçi göstergesi)
  static const Color onlineLight = accent; // #A8D8C6: Mint online glow/badge background
  static const Color victory = winGreen; // #90F0CC: Vibrant saturated green (Galibiyet rozeti & metni)
  static const Color victoryLight = winGreen; // Victory tint / glow
  static const Color winStat = accent; // #A8D8C6: Saturated win rate/stat color
  static const Color winStatLight = accent; // Win stat badge tint

  static Color getVictory(bool isDark) => victory;
  static Color getOnline(bool isDark) => isDark ? accent : accentSecondary;

  // --- Active Turn Profile Panel Colors (Mint theme) ---
  static const Color turnActiveCardDark = Color(0xFF29372F); // Deep tactical mint for dark mode
  static const Color turnActiveCardLight = Color(0xFFD6F0E6); // Refreshing soft mint for light mode
  static const Color turnActiveBorderDark = Color(0xFF3B7260); // Mint border highlight dark
  static const Color turnActiveBorderLight = Color(0xFF8DCFB7); // Mint border highlight light

  static Color getTurnActiveCard(bool isDark) =>
      isDark ? turnActiveCardDark : turnActiveCardLight;
  static Color getTurnActiveBorder(bool isDark) =>
      isDark ? turnActiveBorderDark : turnActiveBorderLight;

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
  // Deep dark gray canvas (darker than #282828)
  static const Color darkBg = Color(0xFF191919); // Pure dark neutral gray
  // Cards use elevated neutral gray surface
  static const Color darkCard = Color(0xFF242424);
  static const Color darkSurface = Color(0xFF2E2E2E);
  static const Color darkSurfaceElevated = Color(0xFF383838);
  static const Color darkBorder = Color(0xFF3D3D3D);
  static const Color darkDivider = Color(0xFF2C2C2C);

  static const Color darkTextPrimary = Color(0xFFF5F6F6);
  static const Color darkTextSecondary = Color(0xFFB4B4B4);
  static const Color darkTextMuted = Color(0xFF7E7E7E);

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
