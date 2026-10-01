import 'package:flutter/material.dart';

import '../../../data/models/game_models.dart';
import 'tutorial_models.dart';

class TutorialLessonsData {
  TutorialLessonsData._();

  static List<TutorialLesson> getLessons() {
    return [
      _buildLesson1(),
      _buildLesson2(),
      _buildLesson3(),
    ];
  }

  /// Lesson 1: The Board & Pieces
  static TutorialLesson _buildLesson1() {
    final emptyEngine = KitaGameEngine.custom(positions: {});
    final standardEngine = KitaGameEngine();

    // Tile value groups
    final tilesVal1 = KitaBoardConfig.tiles.entries
        .where((e) => e.value == 1)
        .map((e) => e.key)
        .toSet();
    final tilesVal2 = KitaBoardConfig.tiles.entries
        .where((e) => e.value == 2)
        .map((e) => e.key)
        .toSet();
    final tilesVal3 = KitaBoardConfig.tiles.entries
        .where((e) => e.value == 3)
        .map((e) => e.key)
        .toSet();

    return TutorialLesson(
      lessonNumber: 1,
      titleKey: 'tutorial.lesson1Title',
      icon: Icons.grid_view_rounded,
      steps: [
        // Step 1: Merged "board layout" and "your army" (2 text cards)
        TutorialStep(
          textKeys: [
            'tutorial.lesson1Step1Card1',
            'tutorial.lesson1Step1Card2',
          ],
          engine: standardEngine,
        ),
        // Step 2: "tile values" (3 sub-boards: 1s, 2s, 3s highlighted)
        TutorialStep(
          textKeys: [
            'tutorial.lesson1Step2Desc',
          ],
          engine: emptyEngine,
          subBoards: [
            TutorialSubBoard(
              labelKey: 'tutorial.tileValue1',
              engine: emptyEngine,
              validMoves: tilesVal1,
            ),
            TutorialSubBoard(
              labelKey: 'tutorial.tileValue2',
              engine: emptyEngine,
              validMoves: tilesVal2,
            ),
            TutorialSubBoard(
              labelKey: 'tutorial.tileValue3',
              engine: emptyEngine,
              validMoves: tilesVal3,
            ),
          ],
        ),
        // Step 3: "goal" (2 text cards: goal of the game + kings captured, pawns not)
        TutorialStep(
          textKeys: [
            'tutorial.lesson1Step3Card1',
            'tutorial.lesson1Step3Card2',
          ],
          engine: standardEngine,
        ),
      ],
    );
  }

  /// Lesson 2: Movement & Rules
  static TutorialLesson _buildLesson2() {
    // Dynamic Steps: 2 sub-boards
    // Sub-board 1: Black King on D1 (value 2). WP1 on A4 (3, 3) highlighted with 2 steps.
    final engineKingOnD1 = KitaGameEngine.custom(
      positions: {
        'BK': const KitaPos(0, 0), // D1 -> value 2
        'BP1': const KitaPos(3, 0),
        'BP2': const KitaPos(0, 1),
        'WK': const KitaPos(6, 3),
        'WP1': const KitaPos(3, 3), // A4
        'WP2': const KitaPos(6, 2),
      },
      turn: PieceTeam.white,
    );
    final wp1MovesWith2 = engineKingOnD1.getLegalMovesForPiece('WP1');

    // Sub-board 2: Black King on D2 (value 3). WP1 on A4 (3, 3) highlighted with 3 steps.
    final engineKingOnD2 = KitaGameEngine.custom(
      positions: {
        'BK': const KitaPos(1, 0), // D2 -> value 3
        'BP1': const KitaPos(3, 0),
        'BP2': const KitaPos(0, 1),
        'WK': const KitaPos(6, 3),
        'WP1': const KitaPos(3, 3), // A4
        'WP2': const KitaPos(6, 2),
      },
      turn: PieceTeam.white,
    );
    final wp1MovesWith3 = engineKingOnD2.getLegalMovesForPiece('WP1');

    // Standard engine for free interactive move and undo demonstration
    final standardEngine = KitaGameEngine();

    // Forced Exception Setup:
    // White has only 1 legal move, which is reversing its previous move.
    // BK: D1, BP1: D5, BP2: D7, WK: D2, WP1: D3 (last from C4), WP2: D6.
    final forcedExceptionEngine = KitaGameEngine.custom(
      positions: {
        'BK': const KitaPos(0, 0),  // D1
        'BP1': const KitaPos(4, 0), // D5
        'BP2': const KitaPos(6, 0), // D7
        'WK': const KitaPos(1, 0),  // D2
        'WP1': const KitaPos(2, 0), // D3
        'WP2': const KitaPos(5, 0), // D6
      },
      turn: PieceTeam.white,
      lastMoveWhite: const KitaMove(
        pieceId: 'WP1',
        fromPos: KitaPos(3, 1), // C4
        toPos: KitaPos(2, 0),   // D3
      ),
    );
    final forcedMoves = forcedExceptionEngine.getLegalMoves();

    return TutorialLesson(
      lessonNumber: 2,
      titleKey: 'tutorial.lesson2Title',
      icon: Icons.directions_run_rounded,
      steps: [
        // Step 1: Dynamic Steps (2 sub-boards: King on 2 vs King on 3, highlighting A4)
        TutorialStep(
          textKeys: [
            'tutorial.lesson2Step1Desc',
          ],
          engine: engineKingOnD1,
          selectedPos: const KitaPos(3, 3),
          validMoves: wp1MovesWith2,
          subBoards: [
            TutorialSubBoard(
              labelKey: 'tutorial.dynamicStep2',
              engine: engineKingOnD1,
              selectedPos: const KitaPos(3, 3),
              validMoves: wp1MovesWith2,
            ),
            TutorialSubBoard(
              labelKey: 'tutorial.dynamicStep3',
              engine: engineKingOnD2,
              selectedPos: const KitaPos(3, 3),
              validMoves: wp1MovesWith3,
            ),
          ],
        ),
        // Step 2: Make a Move (Merged walking & try a move, free piece/move choice)
        TutorialStep(
          textKeys: [
            'tutorial.lesson2Step2Desc',
          ],
          engine: standardEngine,
          interactiveType: InteractiveStepType.freeMove,
          successDescKey: 'tutorial.lesson2Step2Success',
        ),
        // Step 3: No Immediate Undos (Interactive with AI automatic D4D2 reply)
        TutorialStep(
          textKeys: [
            'tutorial.lesson2Step3Desc',
          ],
          engine: standardEngine,
          interactiveType: InteractiveStepType.undoDemonstration,
          successDescKey: 'tutorial.lesson2Step3Success',
        ),
        // Step 4: Forced Exception (Setup where White only has 1 legal move and piece is selected)
        TutorialStep(
          textKeys: [
            'tutorial.lesson2Step4Desc',
          ],
          engine: forcedExceptionEngine,
          selectedPos: const KitaPos(2, 0), // WP1 at D3
          validMoves: forcedMoves.map((m) => m.toPos).toSet(),
        ),
      ],
    );
  }

  /// Lesson 3: Victory & Draws
  static TutorialLesson _buildLesson3() {
    // Step 1 setup: King Elimination (WP1 at D3 can capture BK at D1)
    final captureEngine = KitaGameEngine.custom(
      positions: {
        'BK': const KitaPos(0, 0), // D1
        'BP1': const KitaPos(3, 0),
        'BP2': const KitaPos(0, 2),
        'WK': const KitaPos(6, 3),
        'WP1': const KitaPos(2, 0), // D3
        'WP2': const KitaPos(6, 2),
      },
      turn: PieceTeam.white,
    );

    // Step 2 setup: No Legal Moves (BK:D1, BP:D4, BP:A1, WK:A7, WP:A4, WP:D7)
    // Correct move is A7C7 (WK from (6, 3) to (6, 1))
    final trapEngine = KitaGameEngine.custom(
      positions: {
        'BK': const KitaPos(0, 0),  // D1
        'BP1': const KitaPos(3, 0), // D4
        'BP2': const KitaPos(0, 3), // A1
        'WK': const KitaPos(6, 3),  // A7
        'WP1': const KitaPos(3, 3), // A4
        'WP2': const KitaPos(6, 0), // D7
      },
      turn: PieceTeam.white,
    );

    // Step 3 setup: Last Stand / Retaliation
    // White WP1 at D3 captures BK at D1. Black BP1 at C7 automatically retaliates to WK at A7.
    final retaliationEngine = KitaGameEngine.custom(
      positions: {
        'BK': const KitaPos(0, 0),  // D1
        'BP1': const KitaPos(6, 1), // C7
        'BP2': const KitaPos(0, 2),
        'WK': const KitaPos(6, 3),  // A7
        'WP1': const KitaPos(2, 0), // D3
        'WP2': const KitaPos(3, 3), // A4
      },
      turn: PieceTeam.white,
    );

    // Step 4 setup: Draws (Repetition & Agreement)
    final drawEngine = KitaGameEngine.custom(
      positions: {
        'BK': null,
        'BP1': const KitaPos(6, 3),
        'BP2': const KitaPos(0, 2),
        'WK': null,
        'WP1': const KitaPos(0, 0),
        'WP2': const KitaPos(3, 3),
      },
      turn: PieceTeam.white,
      kingEatenBy: 'both',
    );

    return TutorialLesson(
      lessonNumber: 3,
      titleKey: 'tutorial.lesson3Title',
      icon: Icons.emoji_events_rounded,
      steps: [
        // Step 1: King Elimination (Interactive)
        TutorialStep(
          textKeys: [
            'tutorial.lesson3Step1Desc',
          ],
          engine: captureEngine,
          selectedPos: const KitaPos(2, 0),
          validMoves: captureEngine.getLegalMovesForPiece('WP1'),
          interactiveType: InteractiveStepType.captureKing,
          successDescKey: 'tutorial.lesson3Step1Success',
        ),
        // Step 2: No Legal Moves (Interactive - make one move to win)
        TutorialStep(
          textKeys: [
            'tutorial.lesson3Step2Desc',
          ],
          engine: trapEngine,
          selectedPos: const KitaPos(6, 3),
          validMoves: trapEngine.getLegalMovesForPiece('WK'),
          interactiveType: InteractiveStepType.trapNoLegalMoves,
          tryItKey: 'tutorial.tryItWin',
          successDescKey: 'tutorial.lesson3Step2Success',
        ),
        // Step 3: Last Stand / Retaliation (Interactive)
        TutorialStep(
          textKeys: [
            'tutorial.lesson3Step3Desc',
          ],
          engine: retaliationEngine,
          selectedPos: const KitaPos(2, 0),
          validMoves: retaliationEngine.getLegalMovesForPiece('WP1'),
          interactiveType: InteractiveStepType.retaliationDraw,
          successDescKey: 'tutorial.lesson3Step3Success',
        ),
        // Step 4: Repetition & Agreement
        TutorialStep(
          textKeys: [
            'tutorial.lesson3Step4Desc',
          ],
          engine: drawEngine,
        ),
      ],
    );
  }
}
