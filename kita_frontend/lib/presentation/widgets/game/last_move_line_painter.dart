import 'dart:math';
import 'package:flutter/material.dart';
import '../../../data/models/game_models.dart';

/// Data payload for a single move path to be rendered by [LastMoveLinePainter].
class LastMovePathData {
  final List<KitaPos> path;
  final bool isLatest;

  const LastMovePathData({
    required this.path,
    this.isLatest = true,
  });
}

/// Custom painter that renders semi-transparent directional path lines through
/// the steps of the last moves (White + Black) on the Kita board.
class LastMoveLinePainter extends CustomPainter {
  final List<LastMovePathData> paths;
  final bool isHorizontal;
  final bool flipBoard;
  final double cellSize;
  final Color lineColor;

  const LastMoveLinePainter({
    required this.paths,
    required this.isHorizontal,
    required this.flipBoard,
    required this.cellSize,
    required this.lineColor,
  });

  /// Factory for a single path (backwards compatibility).
  factory LastMoveLinePainter.single({
    required List<KitaPos> path,
    required bool isHorizontal,
    required bool flipBoard,
    required double cellSize,
    required Color lineColor,
  }) {
    return LastMoveLinePainter(
      paths: [LastMovePathData(path: path, isLatest: true)],
      isHorizontal: isHorizontal,
      flipBoard: flipBoard,
      cellSize: cellSize,
      lineColor: lineColor,
    );
  }

  Offset _posToCenter(KitaPos pos) {
    int displayCol;
    int displayRow;

    if (isHorizontal) {
      displayCol = flipBoard ? (6 - pos.col) : pos.col;
      displayRow = flipBoard ? (3 - pos.row) : pos.row;
    } else {
      displayCol = flipBoard ? (3 - pos.row) : pos.row;
      displayRow = flipBoard ? (6 - pos.col) : pos.col;
    }

    return Offset(
      (displayCol + 0.5) * cellSize,
      (displayRow + 0.5) * cellSize,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Draw previous move first so latest move layers smoothly on top
    final sortedPaths = List<LastMovePathData>.from(paths)
      ..sort((a, b) => (a.isLatest ? 1 : 0).compareTo(b.isLatest ? 1 : 0));

    for (final item in sortedPaths) {
      if (item.path.length < 2) continue;
      _paintPath(canvas, item.path, item.isLatest);
    }
  }

  void _paintPath(Canvas canvas, List<KitaPos> path, bool isLatest) {
    final points = path.map(_posToCenter).toList();

    // Draw rounded connecting polyline
    final linePaint = Paint()
      ..color = lineColor.withValues(alpha: isLatest ? 0.50 : 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(cellSize * (isLatest ? 0.10 : 0.075), 3.0)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final linePath = Path();
    linePath.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(linePath, linePaint);
  }

  @override
  bool shouldRepaint(covariant LastMoveLinePainter oldDelegate) {
    if (oldDelegate.paths.length != paths.length ||
        oldDelegate.isHorizontal != isHorizontal ||
        oldDelegate.flipBoard != flipBoard ||
        oldDelegate.cellSize != cellSize ||
        oldDelegate.lineColor != lineColor) {
      return true;
    }
    for (int i = 0; i < paths.length; i++) {
      if (oldDelegate.paths[i].path != paths[i].path ||
          oldDelegate.paths[i].isLatest != paths[i].isLatest) {
        return true;
      }
    }
    return false;
  }
}
