import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/game_models.dart';
import '../../../data/models/kita_ai.dart';

class AiAdvantageBar extends StatelessWidget {
  /// The engine state to evaluate
  final KitaGameEngine engine;

  /// Optional pre-warmed AI instance. If null, a lightweight instance is used
  final KitaAI? ai;

  /// Whether to layout as a vertical bar (e.g. desktop side bar) or horizontal bar (e.g. mobile top bar)
  final bool isVertical;

  /// Overall thickness (width for vertical, height for horizontal)
  final double thickness;

  /// Optional precomputed score from White's perspective to avoid search recomputation
  final double? score;

  /// Search depth when score is not precomputed (default: 3)
  final int depth;

  const AiAdvantageBar({
    super.key,
    required this.engine,
    this.ai,
    this.score,
    this.depth = 3,
    this.isVertical = false,
    this.thickness = 22.0,
  });

  /// Computes absolute evaluation from White's perspective.
  /// Standard range: [-1.0, 1.0] for ongoing games, ±10.0 for terminal wins.
  double get whiteAdvantageScore => score ?? computeWhiteAdvantageScore(engine, ai, depth);

  /// Computes absolute evaluation from White's perspective.
  /// Standard range: [-1.0, 1.0] for ongoing games, ±10.0 for terminal wins.
  static double computeWhiteAdvantageScore(
    KitaGameEngine engine, [
    KitaAI? ai,
    int depth = 3,
  ]) {
    final status = engine.getStatus();
    if (status == GameStatus.whiteWins) return 10.0;
    if (status == GameStatus.blackWins) return -10.0;
    if (status == GameStatus.draw) return 0.0;

    final effectiveAi = ai ?? KitaAI.instance;
    if (effectiveAi.isInitialized) {
      final raw = effectiveAi.evaluateStateWithSearch(engine, depth: depth);
      return (engine.turn == PieceTeam.white) ? raw : -raw;
    } else {
      try {
        effectiveAi.initialize();
      } catch (_) {}
    }

    // Material & King safety heuristic fallback if AI weights not yet loaded
    return heuristicScore(engine);
  }

  static double heuristicScore(KitaGameEngine eng) {
    double score = 0.0;
    final wk = eng.positions['WK'];
    final bk = eng.positions['BK'];

    if (wk == null && bk != null) return -10.0;
    if (bk == null && wk != null) return 10.0;
    if (wk == null && bk == null) return 0.0;

    // Pawns count
    int whitePawns = (eng.positions['WP1'] != null ? 1 : 0) +
        (eng.positions['WP2'] != null ? 1 : 0);
    int blackPawns = (eng.positions['BP1'] != null ? 1 : 0) +
        (eng.positions['BP2'] != null ? 1 : 0);
    score += (whitePawns - blackPawns) * 0.2;

    // Mobility
    final legalMoves = eng.getLegalMoves();
    final mobilityDelta = (eng.turn == PieceTeam.white ? 1.0 : -1.0) *
        (legalMoves.length * 0.03);
    score += mobilityDelta;

    return score.clamp(-1.0, 1.0);
  }

  /// Converts White's score into a [0.0, 1.0] percentage for White's share of the bar.
  /// 0.0 = 100% Black advantage
  /// 0.5 = 50% Equal
  /// 1.0 = 100% White advantage
  double get whiteFraction {
    final score = whiteAdvantageScore;
    if (score >= 5.0) return 1.0;
    if (score <= -5.0) return 0.0;

    // Normal non-terminal range [-1.0, 1.0] mapped smoothly to [0.05, 0.95]
    final clamped = score.clamp(-1.0, 1.0);
    final mapped = 0.5 + (clamped * 0.45);
    return mapped.clamp(0.04, 0.96);
  }

  String get scoreLabel {
    final score = whiteAdvantageScore;
    if (score >= 5.0) return 'W WIN';
    if (score <= -5.0) return 'B WIN';
    if (score.abs() < 0.04) return '0.0';
    final sign = score > 0 ? '+' : '';
    return '$sign${score.toStringAsFixed(1)}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final targetFraction = whiteFraction;
    final label = scoreLabel;
    final isWhiteAdv = whiteAdvantageScore > 0.04;
    final isBlackAdv = whiteAdvantageScore < -0.04;

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: targetFraction, end: targetFraction),
      builder: (context, fraction, child) {
        if (isVertical) {
          return _buildVerticalBar(context, fraction, label, isDark, isWhiteAdv, isBlackAdv);
        } else {
          return _buildHorizontalBar(context, fraction, label, isDark, isWhiteAdv, isBlackAdv);
        }
      },
    );
  }

  Widget _buildHorizontalBar(
    BuildContext context,
    double fraction,
    String label,
    bool isDark,
    bool isWhiteAdv,
    bool isBlackAdv,
  ) {
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final whiteFlex = (fraction * 1000).toInt().clamp(0, 1000);
    final blackFlex = 1000 - whiteFlex;

    return Container(
      height: thickness,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(thickness / 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 4,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 1. Proportional fill: Left is White, Right is Black, clipped smoothly into a capsule
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(thickness / 2),
              clipBehavior: Clip.antiAlias,
              child: Row(
                children: [
                  if (whiteFlex > 0)
                    Expanded(
                      flex: whiteFlex,
                      child: Container(
                        color: AppColors.advantageWhite,
                      ),
                    ),
                  if (blackFlex > 0)
                    Expanded(
                      flex: blackFlex,
                      child: Container(
                        color: AppColors.advantageBlack,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 2. Crisp outer border overlay matching the pill radius without inset padding
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(thickness / 2),
                  border: Border.all(
                    color: borderColor,
                    width: 1.2,
                  ),
                ),
              ),
            ),
          ),

          // 3. Evaluation Numeric Indicator Badge
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1.5),
              decoration: BoxDecoration(
                color: isWhiteAdv
                    ? AppColors.pieceWhite.withValues(alpha: 0.92)
                    : (isBlackAdv
                        ? AppColors.advantageBadgeDark.withValues(alpha: 0.92)
                        : AppColors.darkSurfaceElevated.withValues(alpha: 0.88)),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isWhiteAdv
                      ? AppColors.lightBorder
                      : (isBlackAdv ? AppColors.darkBorder : Colors.transparent),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 3,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.balance_rounded,
                    size: 11,
                    color: isWhiteAdv
                        ? AppColors.advantageBadgeTextDark
                        : (isBlackAdv ? AppColors.darkTextSecondary : AppColors.ratingGold),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                      color: isWhiteAdv
                          ? AppColors.advantageBadgeTextDark
                          : AppColors.darkTextPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalBar(
    BuildContext context,
    double fraction,
    String label,
    bool isDark,
    bool isWhiteAdv,
    bool isBlackAdv,
  ) {
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final whiteFlex = (fraction * 1000).toInt().clamp(0, 1000);
    final blackFlex = 1000 - whiteFlex;

    return Container(
      width: thickness,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(thickness / 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Vertical split: Black at top, White at bottom (standard chess eval bar)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(thickness / 2),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  if (blackFlex > 0)
                    Expanded(
                      flex: blackFlex,
                      child: Container(
                        color: AppColors.advantageBlack,
                      ),
                    ),
                  if (whiteFlex > 0)
                    Expanded(
                      flex: whiteFlex,
                      child: Container(
                        color: AppColors.advantageWhite,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 2. Crisp outer border overlay
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(thickness / 2),
                  border: Border.all(
                    color: borderColor,
                    width: 1.2,
                  ),
                ),
              ),
            ),
          ),

          // 3. Small centered label pill
          Positioned(
            bottom: fraction > 0.5 ? 8 : null,
            top: fraction <= 0.5 ? 8 : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: fraction > 0.5
                    ? AppColors.darkSurface.withValues(alpha: 0.8)
                    : AppColors.lightCard.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: fraction > 0.5 ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
