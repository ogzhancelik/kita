import 'dart:math';

import 'package:flutter/material.dart';

import '../../../data/models/game_models.dart';
import 'kita_board_theme.dart';

class KitaBoardWidget extends StatelessWidget {
  /// Current piece locations mapped by Piece ID (e.g. 'BK': KitaPos(0, 0))
  final Map<String, KitaPos> pieces;

  /// Currently selected tile position, if any
  final KitaPos? selectedPos;

  /// Set of valid move target positions to highlight
  final Set<KitaPos> validMoves;

  /// Callback when an active, valid tile is tapped
  final void Function(KitaPos pos)? onTileTap;

  /// True: 7 cols x 4 rows (horizontal layout, default)
  /// False: 4 cols x 7 rows (vertical layout)
  final bool isHorizontal;

  /// Flips the board viewpoint (e.g. when playing as Black)
  final bool flipBoard;

  /// Customizable board theme/styling with heatmap colors
  final KitaBoardTheme? theme;

  /// Optional custom widget builder for pieces
  final Widget Function(BuildContext context, KitaPiece piece, double size)?
  pieceBuilder;

  const KitaBoardWidget({
    super.key,
    required this.pieces,
    this.selectedPos,
    this.validMoves = const {},
    this.onTileTap,
    this.isHorizontal = true,
    this.flipBoard = false,
    this.theme,
    this.pieceBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentTheme = theme ?? KitaBoardTheme.emerald(isDark);

    final int colsCount = isHorizontal ? 7 : 4;
    final int rowsCount = isHorizontal ? 4 : 7;

    // Coordinate margin for semi-transparent rank/file label bars
    const double labelMargin = 18.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Available space minus margin for labels
        final double availW =
            constraints.maxWidth -
            (currentTheme.showCoordinateLabels ? labelMargin * 2 : 0);
        final double availH =
            (constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : constraints.maxWidth * (rowsCount / colsCount)) -
            (currentTheme.showCoordinateLabels ? labelMargin * 2 : 0);

        final double cellFromWidth = availW / colsCount;
        final double cellFromHeight = availH / rowsCount;
        final double cellSize = max(min(cellFromWidth, cellFromHeight), 24.0);

        final double gridWidth = cellSize * colsCount;
        final double gridHeight = cellSize * rowsCount;
        final double totalWidth =
            gridWidth +
            (currentTheme.showCoordinateLabels ? labelMargin * 2 : 0);
        final double totalHeight =
            gridHeight +
            (currentTheme.showCoordinateLabels ? labelMargin * 2 : 0);

        // Invert lookup: Pos -> PieceID
        final Map<KitaPos, String> posToPiece = {};
        pieces.forEach((id, pos) {
          posToPiece[pos] = id;
        });

        return Center(
          child: SizedBox(
            width: totalWidth,
            height: totalHeight,
            child: Stack(
              children: [
                // Top coordinate labels (2, 3, 1, 2, 1, 3, 2)
                if (currentTheme.showCoordinateLabels)
                  Positioned(
                    top: 0,
                    left: labelMargin,
                    width: gridWidth,
                    height: labelMargin,
                    child: _buildTopLabels(cellSize, colsCount, currentTheme),
                  ),

                // Bottom coordinate labels
                if (currentTheme.showCoordinateLabels)
                  Positioned(
                    bottom: 0,
                    left: labelMargin,
                    width: gridWidth,
                    height: labelMargin,
                    child: _buildBottomLabels(
                      cellSize,
                      colsCount,
                      currentTheme,
                    ),
                  ),

                // Left coordinate labels (2, 3, 3, 2)
                if (currentTheme.showCoordinateLabels)
                  Positioned(
                    left: 0,
                    top: labelMargin,
                    width: labelMargin,
                    height: gridHeight,
                    child: _buildLeftLabels(cellSize, rowsCount, currentTheme),
                  ),

                // Right coordinate labels
                if (currentTheme.showCoordinateLabels)
                  Positioned(
                    right: 0,
                    top: labelMargin,
                    width: labelMargin,
                    height: gridHeight,
                    child: _buildRightLabels(cellSize, rowsCount, currentTheme),
                  ),

                // Main Playable Grid
                Positioned(
                  left: currentTheme.showCoordinateLabels ? labelMargin : 0,
                  top: currentTheme.showCoordinateLabels ? labelMargin : 0,
                  width: gridWidth,
                  height: gridHeight,
                  child: Stack(
                    children: [
                      for (int r = 0; r < rowsCount; r++)
                        for (int c = 0; c < colsCount; c++)
                          _buildCell(
                            context: context,
                            displayCol: c,
                            displayRow: r,
                            cellSize: cellSize,
                            posToPiece: posToPiece,
                            theme: currentTheme,
                          ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  KitaPos _mapToCanonical(int displayCol, int displayRow) {
    int canonicalCol;
    int canonicalRow;

    if (isHorizontal) {
      canonicalCol = flipBoard ? (6 - displayCol) : displayCol;
      canonicalRow = flipBoard ? (3 - displayRow) : displayRow;
    } else {
      canonicalCol = flipBoard ? (6 - displayRow) : displayRow;
      canonicalRow = flipBoard ? (3 - displayCol) : displayCol;
    }

    return KitaPos(canonicalCol, canonicalRow);
  }

  Widget _buildCell({
    required BuildContext context,
    required int displayCol,
    required int displayRow,
    required double cellSize,
    required Map<KitaPos, String> posToPiece,
    required KitaBoardTheme theme,
  }) {
    final canonicalPos = _mapToCanonical(displayCol, displayRow);
    final isValid = KitaBoardConfig.isValidTile(
      canonicalPos.col,
      canonicalPos.row,
    );

    // Empty hole tiles: completely transparent & non-interactive
    if (!isValid) {
      return Positioned(
        left: displayCol * cellSize,
        top: displayRow * cellSize,
        width: cellSize,
        height: cellSize,
        child: const SizedBox.shrink(),
      );
    }

    final tileValue = KitaBoardConfig.getTileValue(
      canonicalPos.col,
      canonicalPos.row,
    );
    final isSelected = selectedPos == canonicalPos;
    final isValidMove = validMoves.contains(canonicalPos);
    final pieceId = posToPiece[canonicalPos];
    final piece = pieceId != null ? KitaPiece.allPieces[pieceId] : null;

    // Heatmap background color strictly derived from tile value (1, 2, or 3)
    final cellBaseColor = theme.getColorForValue(tileValue);

    return Positioned(
      left: displayCol * cellSize,
      top: displayRow * cellSize,
      width: cellSize,
      height: cellSize,
      child: Padding(
        padding: EdgeInsets.all(theme.tileSpacing),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTileTap != null ? () => onTileTap!(canonicalPos) : null,
            borderRadius: BorderRadius.circular(theme.tileBorderRadius),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.selectedHighlightColor
                    : cellBaseColor,
                borderRadius: BorderRadius.circular(theme.tileBorderRadius),
                border: Border.all(
                  color: isSelected
                      ? theme.selectedHighlightColor
                      : isValidMove
                      ? theme.validMoveHighlightColor
                      : Colors.white.withValues(alpha: 0.15),
                  width: (isSelected || isValidMove) ? 2.5 : 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    offset: const Offset(0, 2),
                    blurRadius: 3,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 1. Tile Step Value Badge (subtle semi-transparent indicator inside tile)
                  if (theme.showTileValues)
                    Positioned(
                      top: 2,
                      left: 3,
                      child: Text(
                        '$tileValue',
                        style: TextStyle(
                          fontSize: max(cellSize * 0.20, 9.5),
                          fontWeight: FontWeight.w900,
                          color: isSelected
                              ? Colors.black87
                              : theme.tileValueColor,
                        ),
                      ),
                    ),

                  // 2. Valid Move Target Indicator (Ring / Dot)
                  if (isValidMove)
                    Container(
                      width: cellSize * 0.32,
                      height: cellSize * 0.32,
                      decoration: BoxDecoration(
                        color: piece == null
                            ? theme.validMoveHighlightColor
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: piece != null
                            ? Border.all(
                                color: theme.validMoveHighlightColor,
                                width: 3.0,
                              )
                            : null,
                      ),
                    ),

                  // 3. Piece on Tile
                  if (piece != null)
                    _renderPiece(context, piece, cellSize * 0.68, theme),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _renderPiece(
    BuildContext context,
    KitaPiece piece,
    double size,
    KitaBoardTheme theme,
  ) {
    if (pieceBuilder != null) {
      return pieceBuilder!(context, piece, size);
    }

    final isWhite = piece.isWhite;
    final baseColor = isWhite ? theme.whitePieceColor : theme.blackPieceColor;
    final accentColor = piece.isKing
        ? (isWhite ? theme.whiteKingAccent : theme.blackKingAccent)
        : (isWhite ? const Color(0xFFBDC3C7) : const Color(0xFF6B7280));

    if (piece.isKing) {
      return CrownPieceWidget(
        size: size,
        bodyColor: baseColor,
        accentColor: accentColor,
      );
    } else {
      return ShieldPieceWidget(
        size: size * 0.88,
        bodyColor: baseColor,
        accentColor: accentColor,
      );
    }
  }

  // --- Perimeter Coordinate Markings (Semi-transparent) ---
  Widget _buildTopLabels(double cellSize, int count, KitaBoardTheme theme) {
    // 2 3 1 2 1 3 2
    final defaultValues = isHorizontal ? [2, 3, 1, 2, 1, 3, 2] : [2, 3, 3, 2];
    return Row(
      children: List.generate(count, (i) {
        final val = flipBoard ? defaultValues[count - 1 - i] : defaultValues[i];
        return SizedBox(
          width: cellSize,
          child: Center(
            child: Text(
              '$val',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: theme.coordinateLabelColor,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildBottomLabels(double cellSize, int count, KitaBoardTheme theme) {
    final defaultValues = isHorizontal ? [2, 3, 1, 2, 1, 3, 2] : [2, 3, 3, 2];
    return Row(
      children: List.generate(count, (i) {
        final val = flipBoard ? defaultValues[count - 1 - i] : defaultValues[i];
        return SizedBox(
          width: cellSize,
          child: Center(
            child: Text(
              '$val',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: theme.coordinateLabelColor,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildLeftLabels(double cellSize, int count, KitaBoardTheme theme) {
    // 2 3 3 2
    final defaultValues = isHorizontal ? [2, 3, 3, 2] : [2, 3, 1, 2, 1, 3, 2];
    return Column(
      children: List.generate(count, (i) {
        final val = flipBoard ? defaultValues[count - 1 - i] : defaultValues[i];
        return SizedBox(
          height: cellSize,
          child: Center(
            child: Text(
              '$val',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: theme.coordinateLabelColor,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildRightLabels(double cellSize, int count, KitaBoardTheme theme) {
    final defaultValues = isHorizontal ? [2, 3, 3, 2] : [2, 3, 1, 2, 1, 3, 2];
    return Column(
      children: List.generate(count, (i) {
        final val = flipBoard ? defaultValues[count - 1 - i] : defaultValues[i];
        return SizedBox(
          height: cellSize,
          child: Center(
            child: Text(
              '$val',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: theme.coordinateLabelColor,
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Custom Royal Crown piece widget for the Kita King (Şah)
class CrownPieceWidget extends StatelessWidget {
  final double size;
  final Color bodyColor;
  final Color accentColor;

  const CrownPieceWidget({
    super.key,
    required this.size,
    required this.bodyColor,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _CrownPainter(bodyColor: bodyColor, accentColor: accentColor),
    );
  }
}

class _CrownPainter extends CustomPainter {
  final Color bodyColor;
  final Color accentColor;

  _CrownPainter({required this.bodyColor, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Drop shadow paint
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.38)
      ..style = PaintingStyle.fill;

    // Crown Body Paint
    final bodyPaint = Paint()
      ..color = bodyColor
      ..style = PaintingStyle.fill;

    // Outline / Border Paint
    final strokePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeJoin = StrokeJoin.round;

    // Accent Paint (Gold Jewels / Band)
    final accentPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;

    Path createCrownPath(double offsetY) {
      final p = Path();
      // Bottom left
      p.moveTo(w * 0.18, h * 0.78 + offsetY);
      // Arched base
      p.quadraticBezierTo(
        w * 0.50,
        h * 0.83 + offsetY,
        w * 0.82,
        h * 0.78 + offsetY,
      );
      // Right edge up to right spike
      p.lineTo(w * 0.86, h * 0.38 + offsetY);
      // Dip to right valley
      p.lineTo(w * 0.68, h * 0.54 + offsetY);
      // Center tall spike
      p.lineTo(w * 0.50, h * 0.20 + offsetY);
      // Dip to left valley
      p.lineTo(w * 0.32, h * 0.54 + offsetY);
      // Left edge up to left spike
      p.lineTo(w * 0.14, h * 0.38 + offsetY);
      p.close();
      return p;
    }

    // 1. Draw Drop Shadow
    canvas.drawPath(createCrownPath(h * 0.05), shadowPaint);

    // 2. Draw Crown Body
    final crownPath = createCrownPath(0);
    canvas.drawPath(crownPath, bodyPaint);
    canvas.drawPath(crownPath, strokePaint);

    // 3. Draw Royal Base Headband
    final bandPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(w * 0.065, 2.0)
      ..strokeCap = StrokeCap.round;

    final bandPath = Path();
    bandPath.moveTo(w * 0.22, h * 0.73);
    bandPath.quadraticBezierTo(w * 0.50, h * 0.78, w * 0.78, h * 0.73);
    canvas.drawPath(bandPath, bandPaint);

    // 4. Crown Jewels on Peaks
    final r = w * 0.062;
    canvas.drawCircle(Offset(w * 0.14, h * 0.38), r, accentPaint); // Left jewel
    canvas.drawCircle(
      Offset(w * 0.86, h * 0.38),
      r,
      accentPaint,
    ); // Right jewel
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.20),
      r * 1.35,
      accentPaint,
    ); // Center tall jewel

    // Center star / cross glint
    final glintPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.49, h * 0.19), r * 0.45, glintPaint);
  }

  @override
  bool shouldRepaint(covariant _CrownPainter oldDelegate) =>
      oldDelegate.bodyColor != bodyColor ||
      oldDelegate.accentColor != accentColor;
}

/// Custom Tactical Shield piece widget for the Kita Pawns
class ShieldPieceWidget extends StatelessWidget {
  final double size;
  final Color bodyColor;
  final Color accentColor;

  const ShieldPieceWidget({
    super.key,
    required this.size,
    required this.bodyColor,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _ShieldPainter(bodyColor: bodyColor, accentColor: accentColor),
    );
  }
}

class _ShieldPainter extends CustomPainter {
  final Color bodyColor;
  final Color accentColor;

  _ShieldPainter({required this.bodyColor, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Drop shadow paint
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    // Shield Body Paint
    final bodyPaint = Paint()
      ..color = bodyColor
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    Path createShieldPath(double offsetY) {
      final p = Path();
      p.moveTo(w * 0.20, h * 0.25 + offsetY);
      p.lineTo(w * 0.80, h * 0.25 + offsetY);
      p.quadraticBezierTo(
        w * 0.80,
        h * 0.55 + offsetY,
        w * 0.50,
        h * 0.82 + offsetY,
      );
      p.quadraticBezierTo(
        w * 0.20,
        h * 0.55 + offsetY,
        w * 0.20,
        h * 0.25 + offsetY,
      );
      p.close();
      return p;
    }

    // 1. Draw shadow
    canvas.drawPath(createShieldPath(h * 0.05), shadowPaint);

    // 2. Draw Shield Body
    final path = createShieldPath(0);
    canvas.drawPath(path, bodyPaint);
    canvas.drawPath(path, strokePaint);

    // 3. Central emblem / circle
    final emblemPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.50, h * 0.45), w * 0.12, emblemPaint);
  }

  @override
  bool shouldRepaint(covariant _ShieldPainter oldDelegate) =>
      oldDelegate.bodyColor != bodyColor ||
      oldDelegate.accentColor != accentColor;
}
