import '../../../data/models/game_models.dart';

/// Interactive modes for hands-on tutorial steps.
enum InteractiveStepType {
  none,
  freeMove,
  undoDemonstration,
  forcedException,
  captureKing,
  trapNoLegalMoves,
  retaliationDraw,
  repetitionLoop,
}

/// A single explanation card shown on a tutorial page.
class TutorialCard {
  final String textKey;
  final Map<String, String>? namedArgs;
  final String? badgeKey;
  final KitaGameEngine? engine;
  final KitaPos? selectedPos;
  final Set<KitaPos>? validMoves;
  final Set<KitaPos>? tintedTiles;
  final Set<KitaPos>? grayTiles;
  final List<KitaMove>? lastMoves;

  const TutorialCard({
    required this.textKey,
    this.namedArgs,
    this.badgeKey,
    this.engine,
    this.selectedPos,
    this.validMoves,
    this.tintedTiles,
    this.grayTiles,
    this.lastMoves,
  });
}

/// Represents a single full tutorial page (Pages 1 to 8).
class TutorialPage {
  final int pageNumber;
  final String titleKey;
  final List<TutorialCard> cards;
  final InteractiveStepType interactiveType;
  final KitaGameEngine? initialEngine;
  final KitaPos? initialSelectedPos;
  final Set<KitaPos>? initialValidMoves;
  final Set<KitaPos>? initialTintedTiles;
  final Set<KitaPos>? initialGrayTiles;
  final String? successKey;
  final String? tryItKey;

  const TutorialPage({
    required this.pageNumber,
    required this.titleKey,
    required this.cards,
    this.interactiveType = InteractiveStepType.none,
    this.initialEngine,
    this.initialSelectedPos,
    this.initialValidMoves,
    this.initialTintedTiles,
    this.initialGrayTiles,
    this.successKey,
    this.tryItKey,
  });

  bool get isInteractive =>
      interactiveType != InteractiveStepType.none &&
      interactiveType != InteractiveStepType.repetitionLoop;
}
