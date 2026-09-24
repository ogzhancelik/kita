import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

enum HeatmapPalette { emerald, amber, ocean, purple, slate, minecraft }

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

  /// If provided, overrides dynamic scaling with a fixed border radius in pixels.
  final double? fixedTileBorderRadius;

  /// If provided, overrides dynamic scaling with a fixed tile spacing in pixels.
  final double? fixedTileSpacing;

  /// If provided, overrides dynamic scaling with a fixed tile value font size in pixels.
  final double? fixedTileValueFontSize;

  /// If provided, overrides dynamic scaling with a fixed coordinate label font size in pixels.
  final double? fixedCoordinateLabelFontSize;

  /// Ratio of tile border radius relative to [cellSize].
  /// Baseline: ~0.145 (~8.0px on a standard 19:9 phone horizontal board where cellSize ≈ 55px).
  final double tileBorderRadiusRatio;

  /// Ratio of tile padding (margin around each tile) relative to [cellSize].
  /// Baseline: ~0.023 (~1.25px on a standard 19:9 phone horizontal board, half of the previous 2.5px spacing).
  final double tileSpacingRatio;

  /// Ratio of tile step value badge font size relative to [cellSize].
  /// Baseline: ~0.20 (~11.0px on a standard 19:9 phone horizontal board where cellSize ≈ 55px).
  final double tileValueFontSizeRatio;

  /// Ratio of coordinate labels (row A-D, col 1-7) font size relative to [cellSize].
  /// Baseline: ~0.128 (~7.0px on a standard 19:9 phone horizontal board where cellSize ≈ 55px).
  final double coordinateLabelFontSizeRatio;

  /// Maximum tile border radius in pixels.
  /// Baseline: 8.0px (preferred max on 16:10 desktop screen and 19:9 phone).
  final double maxTileBorderRadius;

  /// Maximum tile spacing in pixels.
  /// Baseline: 2.5px.
  final double maxTileSpacing;

  /// Maximum font size for the tile step value badge.
  /// Baseline: 30.0px (previous value on 16:10 desktop screen).
  final double maxTileValueFontSize;

  /// Maximum font size for row & column coordinate labels.
  /// Baseline: 16.5px (previous value on 16:10 desktop screen).
  final double maxCoordinateLabelFontSize;

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
    double? tileBorderRadius,
    double? tileSpacing,
    double? tileValueFontSize,
    double? coordinateLabelFontSize,
    this.tileBorderRadiusRatio = 0.145,
    this.tileSpacingRatio = 0.023,
    this.tileValueFontSizeRatio = 0.20,
    this.coordinateLabelFontSizeRatio = 0.128,
    this.maxTileBorderRadius = 8.0,
    this.maxTileSpacing = 2.5,
    this.maxTileValueFontSize = 22.0,
    this.maxCoordinateLabelFontSize = 14.5,
  })  : fixedTileBorderRadius = tileBorderRadius,
        fixedTileSpacing = tileSpacing,
        fixedTileValueFontSize = tileValueFontSize,
        fixedCoordinateLabelFontSize = coordinateLabelFontSize;

  /// Backward-compatible fallback assuming baseline cell size of ~55px.
  double get tileBorderRadius =>
      fixedTileBorderRadius ?? (55.0 * tileBorderRadiusRatio);
  double get tileSpacing => fixedTileSpacing ?? (55.0 * tileSpacingRatio);

  /// Computes the effective border radius scaled dynamically to the given [cellSize]
  /// and clamped to [maxTileBorderRadius] (with phone baseline as floor for max).
  double effectiveTileBorderRadius(double cellSize) {
    if (fixedTileBorderRadius != null) return fixedTileBorderRadius!;
    final double phoneBaseline = 55.0 * tileBorderRadiusRatio;
    final double ceiling = max(maxTileBorderRadius, phoneBaseline);
    return min(cellSize * tileBorderRadiusRatio, ceiling);
  }

  /// Computes the effective tile spacing (half-gap between tiles)
  /// scaled dynamically to the given [cellSize] and clamped to [maxTileSpacing].
  double effectiveTileSpacing(double cellSize) {
    if (fixedTileSpacing != null) return fixedTileSpacing!;
    final double phoneBaseline = 55.0 * tileSpacingRatio;
    final double ceiling = max(maxTileSpacing, phoneBaseline);
    return min(cellSize * tileSpacingRatio, ceiling);
  }

  /// Computes the effective tile value badge font size scaled dynamically to the given [cellSize]
  /// and clamped to [maxTileValueFontSize] (with phone baseline as floor for max).
  double effectiveTileValueFontSize(double cellSize) {
    if (fixedTileValueFontSize != null) return fixedTileValueFontSize!;
    final double phoneBaseline = 55.0 * tileValueFontSizeRatio;
    final double ceiling = max(maxTileValueFontSize, phoneBaseline);
    return min(cellSize * tileValueFontSizeRatio, ceiling);
  }

  /// Computes the effective coordinate label font size scaled dynamically to the given [cellSize]
  /// and clamped to [maxCoordinateLabelFontSize] (with phone baseline as floor for max).
  double effectiveCoordinateLabelFontSize(double cellSize) {
    if (fixedCoordinateLabelFontSize != null) return fixedCoordinateLabelFontSize!;
    final double phoneBaseline = 55.0 * coordinateLabelFontSizeRatio;
    final double ceiling = max(maxCoordinateLabelFontSize, phoneBaseline);
    return min(cellSize * coordinateLabelFontSizeRatio, ceiling);
  }

  Color getColorForValue(int value) {
    return valueColors[value] ?? const Color(0xFF4A4A4A);
  }

  factory KitaBoardTheme.minecraft() {
    return KitaBoardTheme(
      valueColors: const {
        1: Color(0xFFfcd235), // 1: Dark forest
        2: Color(0xFFe96c0b), // 2: Mid emerald
        3: Color(0xFF982421), // 3: Bright lively green
      },
      selectedHighlightColor: const Color.fromARGB(
        255,
        255,
        255,
        255,
      ).withValues(alpha: 0.5),
      validMoveHighlightColor: const Color.fromARGB(
        255,
        0,
        0,
        0,
      ).withValues(alpha: 0.5),
      tileValueColor: AppColors.darkCard,
    );
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
      tileValueColor: const Color.fromARGB(
        255,
        255,
        255,
        255,
      ).withValues(alpha: 0.85),
    );
  }

  // --- 2. Heatmap Amber Sunset (Warm fiery gradient) ---
  factory KitaBoardTheme.amberSunset() {
    return const KitaBoardTheme(
      valueColors: {
        1: Color(0xFF5e262f), // 1: Deep burnt umber
        2: Color(0xFF8d3e53), // 2: Warm radiant amber
        3: Color(0xFFbf5377), // 3: Fiery bright coral
      },
      selectedHighlightColor: Color(0xFFF39C12),
      validMoveHighlightColor: Color(0xFFef9d0d),
      tileValueColor: Colors.white,
    );
  }

  // --- 3. Heatmap Ocean Azure (Deep sea to electric cyan) ---
  factory KitaBoardTheme.oceanAzure() {
    return const KitaBoardTheme(
      valueColors: {
        1: Color(0xFF275e49), // 1: Deep navy
        2: Color(0xFF3e8f66), // 2: Oceanic azure
        3: Color(0xFF52be80), // 3: Vibrant turquoise
      },
      selectedHighlightColor: AppColors.boardOceanSelected,
      validMoveHighlightColor: AppColors.boardOceanHighlight,
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
