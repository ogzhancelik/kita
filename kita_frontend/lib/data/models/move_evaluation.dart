import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

enum MoveQuality {
  brilliant,
  good,
  inaccuracy,
  mistake,
  blunder,
  neutral,
}

class MoveEvaluation {
  /// Advantage change from the perspective of the player who made the move.
  /// Positive means position improved, negative means position worsened.
  final double delta;

  /// Absolute position score from White's perspective [-10.0, 10.0] after this move.
  final double whiteAdvantageAfter;

  /// Position score from moving player's perspective after this move.
  final double playerAdvantageAfter;

  /// Whether this move was played by White.
  final bool isWhiteMove;

  final MoveQuality quality;

  const MoveEvaluation({
    required this.delta,
    required this.whiteAdvantageAfter,
    required this.playerAdvantageAfter,
    required this.isWhiteMove,
    required this.quality,
  });

  /// Factory to compute evaluation between state before move and state after move.
  factory MoveEvaluation.compute({
    required double whiteScoreBefore,
    required double whiteScoreAfter,
    required bool isWhiteMove,
  }) {
    // Delta from moving player's perspective:
    // If White moved: delta = W_after - W_before
    // If Black moved: delta = (-W_after) - (-W_before) = W_before - W_after
    final double delta = isWhiteMove
        ? (whiteScoreAfter - whiteScoreBefore)
        : (whiteScoreBefore - whiteScoreAfter);

    final double playerAdvantageAfter = isWhiteMove ? whiteScoreAfter : -whiteScoreAfter;

    // Classification
    MoveQuality quality;
    if (playerAdvantageAfter >= 9.5 && delta >= 2.0) {
      quality = MoveQuality.brilliant;
    } else if (playerAdvantageAfter <= -9.5 && delta <= -2.0) {
      quality = MoveQuality.blunder;
    } else if (delta < -0.50) {
      quality = MoveQuality.blunder;
    } else if (delta < -0.20) {
      quality = MoveQuality.mistake;
    } else if (delta < -0.05) {
      quality = MoveQuality.inaccuracy;
    } else if (delta >= 0.05) {
      quality = MoveQuality.good;
    } else {
      quality = MoveQuality.neutral;
    }

    return MoveEvaluation(
      delta: delta,
      whiteAdvantageAfter: whiteScoreAfter,
      playerAdvantageAfter: playerAdvantageAfter,
      isWhiteMove: isWhiteMove,
      quality: quality,
    );
  }

  /// Compact delta label, e.g. "+0.1", "-0.3", "0.0", "+WIN", "-BLN"
  String get deltaLabel {
    if (whiteAdvantageAfter >= 9.5 && delta >= 2.0) {
      return isWhiteMove ? '+WIN' : '-BLN';
    }
    if (whiteAdvantageAfter <= -9.5 && delta <= -2.0) {
      return isWhiteMove ? '-BLN' : '+WIN';
    }

    if (delta.abs() < 0.04) {
      return '0.0';
    }

    final sign = delta > 0 ? '+' : '';
    return '$sign${delta.toStringAsFixed(1)}';
  }

  /// Position score formatted label, e.g. "+0.4"
  String get positionScoreLabel {
    if (whiteAdvantageAfter >= 9.5) return 'W WIN';
    if (whiteAdvantageAfter <= -9.5) return 'B WIN';
    if (whiteAdvantageAfter.abs() < 0.04) return '0.0';
    final sign = whiteAdvantageAfter > 0 ? '+' : '';
    return '$sign${whiteAdvantageAfter.toStringAsFixed(1)}';
  }

  /// Localized quality name (Good, Inaccuracy, Mistake, Blunder)
  String get qualityName {
    switch (quality) {
      case MoveQuality.brilliant:
      case MoveQuality.good:
        return 'replay.evalGood'.tr();
      case MoveQuality.inaccuracy:
        return 'replay.evalInaccuracy'.tr();
      case MoveQuality.mistake:
        return 'replay.evalMistake'.tr();
      case MoveQuality.blunder:
        return 'replay.evalBlunder'.tr();
      case MoveQuality.neutral:
        return 'replay.evalGood'.tr();
    }
  }

  /// Semantic text color based on quality
  Color getTextColor(bool isDark, bool isActive) {
    if (isActive) return Colors.white;
    switch (quality) {
      case MoveQuality.brilliant:
      case MoveQuality.good:
        return isDark ? AppColors.accentGreen : AppColors.primaryGreenDark;
      case MoveQuality.inaccuracy:
        return isDark ? AppColors.warning : AppColors.guestOrange;
      case MoveQuality.mistake:
        return AppColors.evalMistake;
      case MoveQuality.blunder:
        return AppColors.evalBlunder;
      case MoveQuality.neutral:
        return isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    }
  }

  /// Semantic badge background color
  Color getBadgeColor(bool isActive) {
    if (isActive) return Colors.white.withValues(alpha: 0.22);
    switch (quality) {
      case MoveQuality.brilliant:
      case MoveQuality.good:
        return AppColors.evalGoodBg;
      case MoveQuality.inaccuracy:
        return AppColors.evalInaccuracyBg;
      case MoveQuality.mistake:
        return AppColors.evalMistakeBg;
      case MoveQuality.blunder:
        return AppColors.evalBlunderBg;
      case MoveQuality.neutral:
        return AppColors.evalNeutralBg;
    }
  }

  /// Semantic badge border color
  Color getBorderColor(bool isDark, bool isActive) {
    if (isActive) return Colors.white.withValues(alpha: 0.4);
    switch (quality) {
      case MoveQuality.brilliant:
      case MoveQuality.good:
        return AppColors.evalGood.withValues(alpha: 0.35);
      case MoveQuality.inaccuracy:
        return AppColors.evalInaccuracy.withValues(alpha: 0.35);
      case MoveQuality.mistake:
        return AppColors.evalMistake.withValues(alpha: 0.35);
      case MoveQuality.blunder:
        return AppColors.evalBlunder.withValues(alpha: 0.35);
      case MoveQuality.neutral:
        return isDark ? AppColors.darkBorder : AppColors.lightBorder;
    }
  }
}
