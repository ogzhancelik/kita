import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// In-App Kita Logo Widget:
/// 4-grid checkered background + white pawn emblem with 3D bottom bevel shadow.
class KitaLogo extends StatelessWidget {
  /// Dimension of the square logo in logical pixels.
  final double size;

  /// Optional tap callback.
  final VoidCallback? onTap;

  /// Whether to render the darker 3D bevel bottom shadow.
  final bool showShadow;

  const KitaLogo({
    super.key,
    this.size = 28,
    this.onTap,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(size * 0.22);
    final shadowOffset = (size * 0.055).clamp(1.5, 7.0);

    final Widget logoBox = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: AppColors.primaryShadow,
                  offset: Offset(0, shadowOffset),
                  blurRadius: 0,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: CustomPaint(
          size: Size(size, size),
          painter: const _KitaLogoPainter(),
        ),
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: onTap,
          child: logoBox,
        ),
      );
    }

    return logoBox;
  }
}

/// Canvas painter drawing the 4-grid checkered background and white pawn emblem
/// matching the exact SVG coordinates of app_icon.svg:
/// - 4-grid quadrants (Top-Left #BF5377, Top-Right #863653, Bottom-Left #863653, Bottom-Right #562838)
/// - Drop shadow for pawn (translated by y = +36px)
/// - White pawn body curve (translated by y = +36px)
/// - Pawn inner circle / dot emblem (translated by y = +36px)
class _KitaLogoPainter extends CustomPainter {
  const _KitaLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width / 1024.0;
    final double half = size.width / 2.0;

    // 1. 4-Grid Background
    // Top-Left quadrant
    canvas.drawRect(
      Rect.fromLTWH(0, 0, half, half),
      Paint()..color = AppColors.logoGridTopLeft,
    );
    // Top-Right quadrant
    canvas.drawRect(
      Rect.fromLTWH(half, 0, half, half),
      Paint()..color = AppColors.logoGridTopRight,
    );
    // Bottom-Left quadrant
    canvas.drawRect(
      Rect.fromLTWH(0, half, half, half),
      Paint()..color = AppColors.logoGridBottomLeft,
    );
    // Bottom-Right quadrant
    canvas.drawRect(
      Rect.fromLTWH(half, half, half, half),
      Paint()..color = AppColors.logoGridBottomRight,
    );

    // 2. Drop Shadow (Pawn path translated down by 36 + 45 = 81)
    const double ty = 36.0;
    final Path shadowPath = Path();
    shadowPath.moveTo(242.0 * s, (300.5 + ty) * s);
    shadowPath.lineTo(782.0 * s, (300.5 + ty) * s);
    shadowPath.quadraticBezierTo(
      782.0 * s,
      (570.5 + ty) * s,
      512.0 * s,
      (813.5 + ty) * s,
    );
    shadowPath.quadraticBezierTo(
      242.0 * s,
      (570.5 + ty) * s,
      242.0 * s,
      (300.5 + ty) * s,
    );
    shadowPath.close();

    canvas.drawPath(
      shadowPath,
      Paint()
        ..color = AppColors.logoPawnShadow
        ..style = PaintingStyle.fill,
    );

    // 3. White Pawn Body
    final Path pawnPath = Path();
    pawnPath.moveTo(242.0 * s, (255.5 + ty) * s);
    pawnPath.lineTo(782.0 * s, (255.5 + ty) * s);
    pawnPath.quadraticBezierTo(
      782.0 * s,
      (525.5 + ty) * s,
      512.0 * s,
      (768.5 + ty) * s,
    );
    pawnPath.quadraticBezierTo(
      242.0 * s,
      (525.5 + ty) * s,
      242.0 * s,
      (255.5 + ty) * s,
    );
    pawnPath.close();

    canvas.drawPath(
      pawnPath,
      Paint()
        ..color = AppColors.pieceWhite
        ..style = PaintingStyle.fill,
    );

    // Subtle stroke outline for crisp definition at larger sizes
    if (size.width >= 32) {
      canvas.drawPath(
        pawnPath,
        Paint()
          ..color = AppColors.logoPawnStroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = (2.0 * s).clamp(0.5, 2.0),
      );
    }

    // 4. Pawn Inner Circle / Dot Emblem
    final Offset dotCenter = Offset(512.0 * s, (435.5 + ty) * s);
    final double dotRadius = 108.0 * s;

    canvas.drawCircle(
      dotCenter,
      dotRadius,
      Paint()
        ..color = AppColors.logoPawnInnerDot
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _KitaLogoPainter oldDelegate) => false;
}
