import 'dart:math';

import 'package:flutter/material.dart';

import '../../../data/models/game_models.dart';
import 'kita_board_theme.dart';

/// Data payload carried when dragging a piece on the Kita board.
class PieceDragData {
  final String pieceId;
  final KitaPos fromPos;

  const PieceDragData({
    required this.pieceId,
    required this.fromPos,
  });
}

class KitaBoardWidget extends StatelessWidget {
  /// Current piece locations mapped by Piece ID (e.g. 'BK': KitaPos(0, 0))
  final Map<String, KitaPos> pieces;

  /// Currently selected tile position, if any
  final KitaPos? selectedPos;

  /// Set of valid move target positions to highlight
  final Set<KitaPos> validMoves;

  /// Callback when an active, valid tile is tapped
  final void Function(KitaPos pos)? onTileTap;

  /// Callback when a piece is dropped onto a tile
  final void Function(KitaPos fromPos, KitaPos toPos)? onPieceDropped;

  /// Callback when dragging starts on a piece
  final void Function(KitaPos pos)? onPieceDragStarted;

  /// Callback when dragging of a piece is cancelled
  final void Function(KitaPos pos)? onPieceDragCancelled;

  /// Predicate determining if a piece at the position can be dragged
  final bool Function(KitaPos pos)? isPieceDraggable;

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
    this.onPieceDropped,
    this.onPieceDragStarted,
    this.onPieceDragCancelled,
    this.isPieceDraggable,
    this.isHorizontal = true,
    this.flipBoard = false,
    this.theme,
    this.pieceBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final currentTheme = theme ?? KitaBoardTheme.amberSunset();

    final int colsCount = isHorizontal ? 7 : 4;
    final int rowsCount = isHorizontal ? 4 : 7;


    // Invert lookup: Pos -> PieceID
    final Map<KitaPos, String> posToPiece = {};
    pieces.forEach((id, pos) {
      posToPiece[pos] = id;
    });

    return Center(
      child: AspectRatio(
        aspectRatio: colsCount / rowsCount,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double cellSize = constraints.maxWidth / colsCount;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int r = 0; r < rowsCount; r++)
                  Expanded(
                    flex: 1,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (int c = 0; c < colsCount; c++)
                          Expanded(
                            flex: 1,
                            child: AspectRatio(
                              aspectRatio: 1.0,
                              child: _buildCell(
                                context: context,
                                displayCol: c,
                                displayRow: r,
                                cellSize: cellSize,
                                posToPiece: posToPiece,
                                theme: currentTheme,
                                colsCount: colsCount,
                                rowsCount: rowsCount,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
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
    required int colsCount,
    required int rowsCount,
  }) {
    final canonicalPos = _mapToCanonical(displayCol, displayRow);
    final isValid = KitaBoardConfig.isValidTile(
      canonicalPos.col,
      canonicalPos.row,
    );

    // Empty hole tiles: completely transparent & non-interactive
    if (!isValid) {
      return const SizedBox.shrink();
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

    // Coordinates:
    // First column: row labels (A, B, C, D)
    final bool isFirstCol = (displayCol == 0);
    // Last row: col numbers (1, 2, 3, 4, 5, 6, 7)
    final bool isLastRow = (displayRow == rowsCount - 1);

    const rowLetters = ['A', 'B', 'C', 'D'];
    final String rowLabel = isHorizontal
        ? ((canonicalPos.row >= 0 && canonicalPos.row < rowLetters.length)
            ? rowLetters[canonicalPos.row]
            : '${canonicalPos.row}')
        : '${canonicalPos.col + 1}';

    final String colLabel = isHorizontal
        ? '${canonicalPos.col + 1}'
        : ((canonicalPos.row >= 0 && canonicalPos.row < rowLetters.length)
            ? rowLetters[canonicalPos.row]
            : '${canonicalPos.row}');

    final double innerSize = max(cellSize - (theme.tileSpacing * 2), 16.0);
    final double pieceSize = innerSize * 0.72;
    final double labelFontSize = max(cellSize * 0.17, 8.5);

    return Padding(
      padding: EdgeInsets.all(theme.tileSpacing),
      child: SizedBox.expand(
        child: DragTarget<PieceDragData>(
          onWillAcceptWithDetails: (details) => onPieceDropped != null,
          onAcceptWithDetails: (details) {
            onPieceDropped?.call(details.data.fromPos, canonicalPos);
          },
          builder: (context, candidateData, rejectedData) {
            final isDragHovered = candidateData.isNotEmpty;
            final isHoveredValidMove = isDragHovered && isValidMove;

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTileTap != null ? () => onTileTap!(canonicalPos) : null,
                borderRadius: BorderRadius.circular(theme.tileBorderRadius),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.selectedHighlightColor
                        : isHoveredValidMove
                            ? theme.validMoveHighlightColor.withValues(alpha: 0.35)
                            : cellBaseColor,
                    borderRadius: BorderRadius.circular(theme.tileBorderRadius),
                    border: Border.all(
                      color: isSelected
                          ? theme.selectedHighlightColor
                          : isHoveredValidMove
                              ? theme.validMoveHighlightColor
                              : isValidMove
                                  ? theme.validMoveHighlightColor
                                  : Colors.white.withValues(alpha: 0.15),
                      width: isHoveredValidMove
                          ? 3.5
                          : (isSelected || isValidMove)
                              ? 2.5
                              : 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isHoveredValidMove
                            ? theme.validMoveHighlightColor.withValues(alpha: 0.4)
                            : Colors.black.withValues(alpha: 0.22),
                        offset: const Offset(0, 2),
                        blurRadius: isHoveredValidMove ? 6 : 3,
                      ),
                    ],
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    alignment: Alignment.center,
                    children: [
                      // 1. Tile Step Value Badge (sol üst)
                      if (theme.showTileValues)
                        Positioned(
                          top: 2,
                          left: 4,
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

                      // 2. Row Coordinate Label (sol alt - A, B, C, D)
                      if (theme.showCoordinateLabels && isFirstCol)
                        Positioned(
                          bottom: 2,
                          left: 4,
                          child: Text(
                            rowLabel,
                            style: TextStyle(
                              fontSize: labelFontSize,
                              fontWeight: FontWeight.w800,
                              color: isSelected
                                  ? Colors.black54
                                  : theme.coordinateLabelColor,
                            ),
                          ),
                        ),

                      // 3. Col Coordinate Label (sağ alt - 1, 2, 3, 4, 5, 6, 7)
                      if (theme.showCoordinateLabels && isLastRow)
                        Positioned(
                          bottom: 2,
                          right: 4,
                          child: Text(
                            colLabel,
                            style: TextStyle(
                              fontSize: labelFontSize,
                              fontWeight: FontWeight.w800,
                              color: isSelected
                                  ? Colors.black54
                                  : theme.coordinateLabelColor,
                            ),
                          ),
                        ),

                      // 4. Valid Move Target Indicator (Ring / Dot)
                      if (isValidMove)
                        Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            width: cellSize * (isHoveredValidMove ? 0.45 : 0.32),
                            height: cellSize * (isHoveredValidMove ? 0.45 : 0.32),
                            decoration: BoxDecoration(
                              color: piece == null
                                  ? theme.validMoveHighlightColor
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                              border: piece != null
                                  ? Border.all(
                                      color: theme.validMoveHighlightColor,
                                      width: isHoveredValidMove ? 4.0 : 3.0,
                                    )
                                  : null,
                            ),
                          ),
                        ),

                      // 5. Piece on Tile (tam ortada)
                      if (piece != null)
                        Center(
                          child: _buildPieceWidget(
                            context: context,
                            piece: piece,
                            pieceId: pieceId!,
                            canonicalPos: canonicalPos,
                            pieceSize: pieceSize,
                            theme: theme,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPieceWidget({
    required BuildContext context,
    required KitaPiece piece,
    required String pieceId,
    required KitaPos canonicalPos,
    required double pieceSize,
    required KitaBoardTheme theme,
  }) {
    final renderedPiece = _renderPiece(context, piece, pieceSize, theme);
    final canDrag = onPieceDropped != null &&
        (isPieceDraggable == null || isPieceDraggable!(canonicalPos));

    if (!canDrag) {
      return renderedPiece;
    }

    return Draggable<PieceDragData>(
      data: PieceDragData(pieceId: pieceId, fromPos: canonicalPos),
      dragAnchorStrategy: childDragAnchorStrategy,
      onDragStarted: () {
        onPieceDragStarted?.call(canonicalPos);
      },
      onDraggableCanceled: (velocity, offset) {
        onPieceDragCancelled?.call(canonicalPos);
      },
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: pieceSize,
          height: pieceSize,
          child: Transform.scale(
            scale: 1.55,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: pieceSize * 0.95,
                  height: pieceSize * 0.95,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.50),
                        blurRadius: 20,
                        spreadRadius: 4,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                ),
                renderedPiece,
              ],
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.25,
        child: renderedPiece,
      ),
      child: renderedPiece,
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
