import 'package:flutter/material.dart';
import '../../../data/models/game_models.dart';

/// Interactive modes for hands-on tutorial steps.
enum InteractiveStepType {
  none,
  freeMove,
  undoDemonstration,
  captureKing,
  trapNoLegalMoves,
  retaliationDraw,
}

/// A sub-board configuration for steps that display multiple boards
/// (e.g. Tile Values highlighting 1s, 2s, 3s or Dynamic Steps showing King on 2 vs 3).
class TutorialSubBoard {
  final String labelKey;
  final KitaGameEngine engine;
  final KitaPos? selectedPos;
  final Set<KitaPos> validMoves;

  const TutorialSubBoard({
    required this.labelKey,
    required this.engine,
    this.selectedPos,
    this.validMoves = const {},
  });
}

/// Represents a single step inside a tutorial lesson.
class TutorialStep {
  final List<String> textKeys;
  final KitaGameEngine engine;
  final KitaPos? selectedPos;
  final Set<KitaPos> validMoves;
  final List<TutorialSubBoard>? subBoards;
  final InteractiveStepType interactiveType;
  final String? tryItKey;
  final String? successDescKey;

  const TutorialStep({
    required this.textKeys,
    required this.engine,
    this.selectedPos,
    this.validMoves = const {},
    this.subBoards,
    this.interactiveType = InteractiveStepType.none,
    this.tryItKey,
    this.successDescKey,
  });

  bool get isInteractive => interactiveType != InteractiveStepType.none;
}

/// Represents a full lesson containing one or more steps.
class TutorialLesson {
  final int lessonNumber;
  final String titleKey;
  final IconData icon;
  final List<TutorialStep> steps;

  const TutorialLesson({
    required this.lessonNumber,
    required this.titleKey,
    required this.icon,
    required this.steps,
  });
}
