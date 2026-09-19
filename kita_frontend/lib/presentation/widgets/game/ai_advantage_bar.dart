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

  const AiAdvantageBar({
    super.key,
    required this.engine,
    this.ai,
    this.isVertical = false,
    this.thickness = 22.0,
  });

  /// Computes absolute evaluation from White's perspective.
  /// Standard range: [-1.0, 1.0] for ongoing games, ±10.0 for terminal wins.
  double get whiteAdvantageScore {
    final status = engine.getStatus();
    if (status == GameStatus.whiteWins) return 10.0;
    if (status == GameStatus.blackWins) return -10.0;
    if (status == GameStatus.draw) return 0.0;

    final effectiveAi = ai ?? KitaAI.instance;
    if (effectiveAi.isInitialized) {
      final raw = effectiveAi.evaluateStateWithSearch(engine);
      return (engine.turn == PieceTeam.white) ? raw : -raw;
    } else {
      try {
        effectiveAi.initialize();
      } catch (_) {}
    }

    // Material & King safety heuristic fallback if AI weights not yet loaded
    return _heuristicScore(engine);
  }

  static double _heuristicScore(KitaGameEngine eng) {
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
    return Container(
      height: thickness,
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(thickness / 2),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : Colors.black26,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Proportional fill: Left is White, Right is Black
          Row(
            children: [
              Expanded(
                flex: (fraction * 1000).toInt(),
                child: Container(
                  color: const Color(0xFFF0F2F5), // Premium White marble
                ),
              ),
              Expanded(
                flex: ((1.0 - fraction) * 1000).toInt(),
                child: Container(
                  color: const Color(0xFF1E242B), // Deep Obsidian Black
                ),
              ),
            ],
          ),

          // Evaluation Numeric Indicator Badge
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              decoration: BoxDecoration(
                color: isWhiteAdv
                    ? Colors.white.withValues(alpha: 0.92)
                    : (isBlackAdv
                        ? const Color(0xFF15191E).withValues(alpha: 0.92)
                        : Colors.grey.shade800.withValues(alpha: 0.85)),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isWhiteAdv
                      ? Colors.grey.shade300
                      : (isBlackAdv ? Colors.grey.shade700 : Colors.transparent),
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
                        ? const Color(0xFF1B263B)
                        : (isBlackAdv ? Colors.white70 : Colors.amberAccent),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                      color: isWhiteAdv
                          ? const Color(0xFF1B263B)
                          : (isBlackAdv ? Colors.white : Colors.white),
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
    return Container(
      width: thickness,
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(thickness / 2),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : Colors.black26,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Vertical split: White at bottom, Black at top (standard chess style)
          Column(
            children: [
              Expanded(
                flex: ((1.0 - fraction) * 1000).toInt(),
                child: Container(
                  color: const Color(0xFF1E242B), // Black side
                ),
              ),
              Expanded(
                flex: (fraction * 1000).toInt(),
                child: Container(
                  color: const Color(0xFFF0F2F5), // White side
                ),
              ),
            ],
          ),

          // Small centered label pill
          Positioned(
            bottom: fraction > 0.5 ? 8 : null,
            top: fraction <= 0.5 ? 8 : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: fraction > 0.5
                    ? Colors.black.withValues(alpha: 0.75)
                    : Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: fraction > 0.5 ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
