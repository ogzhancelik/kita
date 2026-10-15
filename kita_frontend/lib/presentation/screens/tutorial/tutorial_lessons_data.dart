import '../../../data/models/game_models.dart';
import 'tutorial_models.dart';

class TutorialLessonsData {
  TutorialLessonsData._();

  /// Converts algebraic notation (e.g. "D1", "A7", "C4") to canonical KitaPos
  static KitaPos parsePos(String str) {
    final rowChar = str[0].toUpperCase();
    final colNum = int.parse(str.substring(1));
    const rowLabels = ['D', 'C', 'B', 'A'];
    final rowIndex = rowLabels.indexOf(rowChar);
    return KitaPos(colNum - 1, rowIndex);
  }

  static List<TutorialPage> getPages() {
    return [
      _buildPage1(),
      _buildPage2(),
      _buildPage3(),
      _buildPage4(),
      _buildPage5(),
      _buildPage6(),
      _buildPage7(),
      _buildPage8(),
    ];
  }

  /// Page 1: Board shape, King and Pawns, White army bottom-right
  static TutorialPage _buildPage1() {
    final emptyEngine = KitaGameEngine.custom(positions: {});
    final kingOnlyEngine = KitaGameEngine.custom(positions: {
      'WK': parsePos('A7'),
      'BK': parsePos('D1'),
    });
    final standardEngine = KitaGameEngine();

    return TutorialPage(
      pageNumber: 1,
      titleKey: 'tutorial.page1Title',
      cards: [
        TutorialCard(
          textKey: 'tutorial.page1Card1',
          engine: emptyEngine,
        ),
        TutorialCard(
          textKey: 'tutorial.page1Card2',
          engine: kingOnlyEngine,
          tintedTiles: {
            parsePos('A7'),
            parsePos('D1'),
          },
        ),
        TutorialCard(
          textKey: 'tutorial.page1Card3',
          engine: standardEngine,
          tintedTiles: {
            parsePos('A4'),
            parsePos('B7'),
            parsePos('D4'),
            parsePos('C1'),
          },
        ),
        TutorialCard(
          textKey: 'tutorial.page1Card4',
          engine: standardEngine,
          tintedTiles: {
            parsePos('A7'),
            parsePos('A4'),
            parsePos('B7'),
          },
        ),
      ],
    );
  }

  /// Page 2: Tile values 1, 2, 3 shown in their natural colors while other tiles are grayed out
  static TutorialPage _buildPage2() {
    final standardEngine = KitaGameEngine();
    final allTiles = KitaBoardConfig.tiles.keys.toSet();
    final val1 = KitaBoardConfig.tiles.entries
        .where((e) => e.value == 1)
        .map((e) => e.key)
        .toSet();
    final val2 = KitaBoardConfig.tiles.entries
        .where((e) => e.value == 2)
        .map((e) => e.key)
        .toSet();
    final val3 = KitaBoardConfig.tiles.entries
        .where((e) => e.value == 3)
        .map((e) => e.key)
        .toSet();

    return TutorialPage(
      pageNumber: 2,
      titleKey: 'tutorial.page2Title',
      cards: [
        TutorialCard(
          textKey: 'tutorial.page2Card1',
          engine: standardEngine,
          grayTiles: allTiles.difference(val1),
        ),
        TutorialCard(
          textKey: 'tutorial.page2Card2',
          engine: standardEngine,
          grayTiles: allTiles.difference(val2),
        ),
        TutorialCard(
          textKey: 'tutorial.page2Card3',
          engine: standardEngine,
          grayTiles: allTiles.difference(val3),
        ),
      ],
    );
  }

  /// Page 3: Step Count & Making a Move
  /// Step 1: Non-interactive, highlights opponent King tile.
  /// Step 2: Interactive, make a move, dynamic Black King reply.
  static TutorialPage _buildPage3() {
    final standardEngine = KitaGameEngine();

    return TutorialPage(
      pageNumber: 3,
      titleKey: 'tutorial.page3Title',
      interactiveType: InteractiveStepType.freeMove,
      initialEngine: standardEngine,
      tryItKey: 'tutorial.tryIt',
      successKey: 'tutorial.page3Success',
      cards: [
        TutorialCard(
          textKey: 'tutorial.page3Card1',
          engine: standardEngine,
          tintedTiles: {parsePos('D1')},
        ),
        TutorialCard(
          textKey: 'tutorial.page3Card2',
          engine: standardEngine,
        ),
      ],
    );
  }

  /// Page 4: No Undo Rule
  static TutorialPage _buildPage4() {
    final standardEngine = KitaGameEngine();

    return TutorialPage(
      pageNumber: 4,
      titleKey: 'tutorial.page4Title',
      interactiveType: InteractiveStepType.undoDemonstration,
      initialEngine: standardEngine,
      tryItKey: 'tutorial.tryIt',
      successKey: 'tutorial.page4Success',
      cards: [
        TutorialCard(
          textKey: 'tutorial.page4Card1',
          engine: standardEngine,
        ),
      ],
    );
  }

  /// Page 5: Forced Exception Rule
  static TutorialPage _buildPage5() {
    final forcedEngine = KitaGameEngine.custom(
      positions: {
        'WK': parsePos('D2'),
        'WP1': parsePos('D3'),
        'WP2': parsePos('D6'),
        'BK': parsePos('D1'),
        'BP1': parsePos('D5'),
        'BP2': parsePos('D7'),
      },
      turn: PieceTeam.white,
      lastMoveWhite: KitaMove(
        pieceId: 'WP1',
        fromPos: parsePos('C4'),
        toPos: parsePos('D3'),
      ),
      lastMoveBlack: KitaMove(
        pieceId: 'BP2',
        fromPos: parsePos('A7'),
        toPos: parsePos('D7'),
      ),
      moveCount: 2,
    );

    return TutorialPage(
      pageNumber: 5,
      titleKey: 'tutorial.page5Title',
      interactiveType: InteractiveStepType.forcedException,
      initialEngine: forcedEngine,
      tryItKey: 'tutorial.tryIt',
      successKey: 'tutorial.page5Success',
      cards: [
        TutorialCard(
          textKey: 'tutorial.page5Card1',
          engine: forcedEngine,
        ),
      ],
    );
  }

  /// Page 6: Victory Conditions (Capture King & Trap Opponent)
  static TutorialPage _buildPage6() {
    final captureEngine = KitaGameEngine.custom(
      positions: {
        'WK': parsePos('A7'),
        'WP1': parsePos('D3'),
        'WP2': parsePos('B7'),
        'BK': parsePos('D1'),
        'BP1': parsePos('B1'),
        'BP2': parsePos('D5'),
      },
      turn: PieceTeam.white,
      lastMoveWhite: KitaMove(
        pieceId: 'WP1',
        fromPos: parsePos('C4'),
        toPos: parsePos('D3'),
      ),
      lastMoveBlack: KitaMove(
        pieceId: 'BP1',
        fromPos: parsePos('A2'),
        toPos: parsePos('B1'),
      ),
      moveCount: 2,
    );

    final trapEngine = KitaGameEngine.custom(
      positions: {
        'WK': parsePos('A7'),
        'WP1': parsePos('A4'),
        'WP2': parsePos('D7'),
        'BK': parsePos('D1'),
        'BP1': parsePos('A1'),
        'BP2': parsePos('D4'),
      },
      turn: PieceTeam.white,
      lastMoveWhite: KitaMove(
        pieceId: 'WP2',
        fromPos: parsePos('B7'),
        toPos: parsePos('D7'),
      ),
      lastMoveBlack: KitaMove(
        pieceId: 'BP1',
        fromPos: parsePos('C1'),
        toPos: parsePos('A1'),
      ),
      moveCount: 2,
    );

    return TutorialPage(
      pageNumber: 6,
      titleKey: 'tutorial.page6Title',
      interactiveType: InteractiveStepType.captureKing,
      initialEngine: captureEngine,
      tryItKey: 'tutorial.tryItWin',
      successKey: 'tutorial.page6SuccessKing',
      cards: [
        TutorialCard(
          textKey: 'tutorial.page6Card1',
          engine: captureEngine,
        ),
        TutorialCard(
          textKey: 'tutorial.page6Card2',
          engine: trapEngine,
          selectedPos: parsePos('A7'),
        ),
      ],
    );
  }

  /// Page 7: Retaliation (Last Stand)
  static TutorialPage _buildPage7() {
    final retaliationEngine = KitaGameEngine.custom(
      positions: {
        'WK': parsePos('A7'),
        'WP1': parsePos('D3'),
        'WP2': parsePos('A4'),
        'BK': parsePos('D1'),
        'BP1': parsePos('B1'),
        'BP2': parsePos('C7'),
      },
      turn: PieceTeam.white,
      lastMoveWhite: KitaMove(
        pieceId: 'WP1',
        fromPos: parsePos('D5'),
        toPos: parsePos('D3'),
      ),
      lastMoveBlack: KitaMove(
        pieceId: 'BP2',
        fromPos: parsePos('D6'),
        toPos: parsePos('C7'),
      ),
      moveCount: 2,
    );

    return TutorialPage(
      pageNumber: 7,
      titleKey: 'tutorial.page7Title',
      interactiveType: InteractiveStepType.retaliationDraw,
      initialEngine: retaliationEngine,
      tryItKey: 'tutorial.tryIt',
      successKey: 'tutorial.page7Success',
      cards: [
        TutorialCard(
          textKey: 'tutorial.page7Card1',
          engine: retaliationEngine,
        ),
      ],
    );
  }

  /// Page 8: Repetition & Agreement Draw + Practice Match vs Bot
  static TutorialPage _buildPage8() {
    final repetitionEngine = KitaGameEngine.custom(
      positions: {
        'WK': parsePos('A6'),
        'WP1': parsePos('B7'),
        'WP2': parsePos('A4'),
        'BK': parsePos('C7'),
        'BP1': parsePos('D5'),
        'BP2': parsePos('A1'),
      },
      turn: PieceTeam.white,
      lastMoveWhite: KitaMove(
        pieceId: 'WP2',
        fromPos: parsePos('A1'),
        toPos: parsePos('A4'),
      ),
      lastMoveBlack: KitaMove(
        pieceId: 'BK',
        fromPos: parsePos('D1'),
        toPos: parsePos('A1'),
      ),
      moveCount: 2,
    );

    return TutorialPage(
      pageNumber: 8,
      titleKey: 'tutorial.page8Title',
      interactiveType: InteractiveStepType.repetitionLoop,
      initialEngine: repetitionEngine,
      cards: [
        TutorialCard(
          textKey: 'tutorial.page8Card1',
          engine: repetitionEngine,
        ),
      ],
    );
  }
}
