import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

enum HeatmapPalette {
  emerald,
  amber,
  ocean,
  purple,
  slate,
}

class KitaBoardTheme {
  final Map<int, Color> valueColors;
  final Color borderColor;
  final Color selectedHighlightColor;
  final Color validMoveHighlightColor;
  final Color tileValueColor;
  final Color coordinateLabelColor;
  final Color whitePieceColor;
  final Color blackPieceColor;
  final Color whiteKingAccent;
  final Color blackKingAccent;
  final bool showTileValues;
  final bool showCoordinateLabels;
  final double tileBorderRadius;
  final double tileSpacing;

  const KitaBoardTheme({
    required this.valueColors,
    this.borderColor = AppColors.darkBorder,
    this.selectedHighlightColor = const Color(0xFFF7F769),
    this.validMoveHighlightColor = const Color(0xFF2ECC71),
    this.tileValueColor = Colors.white70,
    this.coordinateLabelColor = Colors.white54,
    this.whitePieceColor = const Color(0xFFFFFFFF),
    this.blackPieceColor = const Color(0xFF16191F),
    this.whiteKingAccent = AppColors.ratingGold,
    this.blackKingAccent = const Color(0xFFE74C3C),
    this.showTileValues = true,
    this.showCoordinateLabels = true,
    this.tileBorderRadius = 8.0,
    this.tileSpacing = 2.5,
  });

  Color getColorForValue(int value) {
    return valueColors[value] ?? const Color(0xFF4A4A4A);
  }

  // --- 1. Heatmap Emerald (Signature Chess.com style) ---
  factory KitaBoardTheme.emerald([bool isDark = true]) {
    return KitaBoardTheme(
      valueColors: isDark
          ? const {
              1: Color(0xFF385E28), // 1: Dark forest
              2: Color(0xFF5E8E3E), // 2: Mid emerald
              3: Color(0xFF88BF52), // 3: Bright lively green
            }
          : const {
              1: Color(0xFF7EA865),
              2: Color(0xFF9BC282),
              3: Color(0xFFC0E0A6),
            },
      selectedHighlightColor: const Color(0xFFF1C40F).withValues(alpha: 0.85),
      validMoveHighlightColor: const Color(0xFF00FF88).withValues(alpha: 0.85),
      tileValueColor: Colors.white.withValues(alpha: 0.85),
    );
  }

  // --- 2. Heatmap Amber Sunset (Warm fiery gradient) ---
  factory KitaBoardTheme.amberSunset() {
    return const KitaBoardTheme(
      valueColors: {
        1: Color(0xFF7A3E00), // 1: Deep burnt umber
        2: Color(0xFFD35400), // 2: Warm radiant amber
        3: Color(0xFFE74C3C), // 3: Fiery bright coral
      },
      selectedHighlightColor: Color(0xFFF39C12),
      validMoveHighlightColor: Color(0xFF2ECC71),
      tileValueColor: Colors.white,
    );
  }

  // --- 3. Heatmap Ocean Azure (Deep sea to electric cyan) ---
  factory KitaBoardTheme.oceanAzure() {
    return const KitaBoardTheme(
      valueColors: {
        1: Color(0xFF154360), // 1: Deep navy
        2: Color(0xFF2471A3), // 2: Oceanic azure
        3: Color(0xFF17A589), // 3: Vibrant turquoise
      },
      selectedHighlightColor: Color(0xFFF4D03F),
      validMoveHighlightColor: Color(0xFF58D68D),
      tileValueColor: Colors.white,
    );
  }

  // --- 4. Heatmap Cyber Purple ---
  factory KitaBoardTheme.cyberPurple() {
    return const KitaBoardTheme(
      valueColors: {
        1: Color(0xFF4A235A), // 1: Deep dark violet
        2: Color(0xFF7D3C98), // 2: Neon royal purple
        3: Color(0xFFAF7AC5), // 3: Radiant orchid
      },
      selectedHighlightColor: Color(0xFFF1C40F),
      validMoveHighlightColor: Color(0xFF00E676),
      tileValueColor: Colors.white,
    );
  }

  // --- 5. Heatmap Slate Monochrome ---
  factory KitaBoardTheme.slateMonochrome() {
    return const KitaBoardTheme(
      valueColors: {
        1: Color(0xFF262421), // 1: Deep carbon
        2: Color(0xFF403C36), // 2: Mid slate
        3: Color(0xFF635E55), // 3: Ash slate
      },
      selectedHighlightColor: AppColors.primaryGreen,
      validMoveHighlightColor: Color(0xFF3498DB),
      tileValueColor: Colors.white70,
    );
  }
}
