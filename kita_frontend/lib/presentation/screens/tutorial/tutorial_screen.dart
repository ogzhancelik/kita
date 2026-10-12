import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/feedback/haptic_service.dart';
import '../../../core/feedback/sound_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/game_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/game_settings_provider.dart';
import '../../providers/offline_game_provider.dart';
import '../../screens/game/offline_match_screen.dart';
import '../../widgets/common/kita_card.dart';
import '../../widgets/common/responsive_layout.dart';
import '../../widgets/game/kita_board_theme.dart';
import '../../widgets/game/kita_board_widget.dart';
import '../../widgets/game/kita_game_board.dart';
import 'tutorial_lessons_data.dart';
import 'tutorial_models.dart';

class TutorialScreen extends StatefulWidget {
  final bool isFirstLaunch;

  /// Tracks whether the tutorial screen is currently open and active.
  static bool isTutorialOpen = false;

  const TutorialScreen({
    super.key,
    this.isFirstLaunch = false,
  });

  static Future<void> launch(BuildContext context, {bool isFirstLaunch = false}) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TutorialScreen(isFirstLaunch: isFirstLaunch),
      ),
    );
  }

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen>
    with SingleTickerProviderStateMixin {
  late final List<TutorialPage> _pages;
  int _currentPageIndex = 0;
  int _currentCardIndex = 0;
  bool _showPracticePrompt = false;

  // Interactive page state
  KitaGameEngine? _interactiveEngine;
  KitaPos? _interactiveSelectedPos;
  Set<KitaPos> _interactiveValidMoves = {};
  bool _interactiveCompleted = false;
  String? _interactiveFeedback;

  // Stored state from previous pages for continuation & memory
  final Map<int, KitaGameEngine> _completedEngines = {};
  final Map<int, bool> _completedPages = {};
  KitaMove? _playerPage3Move;
  int _page3Tour = 1;

  // Stage for undo and delayed auto-responses
  int _autoPlayStage = 0;

  // Page 8 Repetition Autoplay
  Timer? _repetitionTimer;
  int _repetitionMoveIndex = 0;
  KitaGameEngine? _repetitionEngine;

  // Pulse animation for "Tap to continue"
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    TutorialScreen.isTutorialOpen = true;
    _pages = TutorialLessonsData.getPages();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initPageState();
  }

  @override
  void dispose() {
    TutorialScreen.isTutorialOpen = false;
    _repetitionTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  TutorialPage get _currentPage => _pages[_currentPageIndex];

  TutorialCard get _currentCard {
    final page = _currentPage;
    if (_currentCardIndex < page.cards.length) {
      return page.cards[_currentCardIndex];
    }
    return page.cards.last;
  }

  bool get _isLastPageOverall => _currentPageIndex == _pages.length - 1;

  void _initPageState() {
    _repetitionTimer?.cancel();
    final page = _currentPage;
    _interactiveFeedback = null;
    _autoPlayStage = 0;

    // Check if player has already completed this page earlier
    if (_completedPages[_currentPageIndex] == true &&
        _completedEngines[_currentPageIndex] != null) {
      if (page.pageNumber == 3 && _currentCardIndex == 0) {
        _page3Tour = 1;
        _interactiveEngine = page.initialEngine ?? KitaGameEngine();
        _interactiveCompleted = false;
        _interactiveSelectedPos = null;
        _interactiveValidMoves = {};
        return;
      }
      if (page.pageNumber == 6 && _currentCardIndex == 0) {
        final card0 = page.cards[0];
        _interactiveEngine = card0.engine ?? page.initialEngine!;
        _interactiveCompleted = false;
        _interactiveSelectedPos = card0.selectedPos;
        return;
      }
      _interactiveEngine = _completedEngines[_currentPageIndex];
      _interactiveCompleted = true;
      _interactiveSelectedPos = null;
      _interactiveValidMoves = {};
      return;
    }

    _interactiveCompleted = false;

    // Handle Page 3
    if (page.pageNumber == 3) {
      _page3Tour = 1;
      final initial = page.initialEngine ?? KitaGameEngine();
      _interactiveEngine = initial;
      _interactiveSelectedPos = null;
      _interactiveValidMoves = {};
      return;
    }

    // Handle Page 4 (No Undo Rule)
    if (page.pageNumber == 4) {
      // Start with board from Page 3 (which already includes Black's response)
      final prevEngine = _completedEngines[2] ??
          KitaGameEngine().applyMove(
            const KitaMove(
              pieceId: 'WP1',
              fromPos: KitaPos(3, 3), // A4
              toPos: KitaPos(3, 1),   // C4
            ),
          ).applyMove(
            const KitaMove(
              pieceId: 'BK',
              fromPos: KitaPos(0, 0), // D1
              toPos: KitaPos(2, 0),   // D3
            ),
          ).applyMove(
            const KitaMove(
              pieceId: 'BP2',
              fromPos: KitaPos(1, 1), // C1
              toPos: KitaPos(2, 1),   // D2
            ),
          );

      // Explicitly ensure turn is White so the player can move immediately
      final readyWhiteEng = KitaGameEngine.custom(
        positions: prevEngine.positions,
        turn: PieceTeam.white,
        lastMoveWhite: prevEngine.lastMoveWhite,
        lastMoveBlack: prevEngine.lastMoveBlack,
        executedMoveWhite: prevEngine.executedMoveWhite,
        executedMoveBlack: prevEngine.executedMoveBlack,
        kingEatenBy: prevEngine.kingEatenBy,
        stateHistory: prevEngine.stateHistory,
        moveCount: prevEngine.moveCount >= 2 ? prevEngine.moveCount : 2,
      );

      _interactiveEngine = readyWhiteEng;
      _autoPlayStage = 0; // Immediately active for White
      _interactiveCompleted = false;

      // Autoselect White's last moved piece from Page 3 Tour 2
      _playerPage3Move ??= readyWhiteEng.lastMoveWhite ??
          const KitaMove(
            pieceId: 'WP1',
            fromPos: KitaPos(3, 3),
            toPos: KitaPos(3, 1),
          );

      final lastMovedPos = _playerPage3Move!.toPos;
      _interactiveSelectedPos = lastMovedPos;
      final pid = readyWhiteEng.activePositions.entries
          .firstWhere(
            (e) => e.value == lastMovedPos,
            orElse: () => const MapEntry('', KitaPos(-1, -1)),
          )
          .key;

      if (pid.isNotEmpty) {
        _interactiveValidMoves = readyWhiteEng
            .getLegalMovesForTeam(PieceTeam.white)
            .where((m) => m.pieceId == pid)
            .map((m) => m.toPos)
            .toSet();
      } else {
        _interactiveValidMoves = {};
      }
      return;
    }

    // Handle Page 6 (Victory Conditions: Card 1 vs Card 2)
    if (page.pageNumber == 6) {
      final card = _currentCard;
      final engine = card.engine ?? page.initialEngine!;
      _interactiveEngine = engine;
      _interactiveSelectedPos = card.selectedPos ?? page.initialSelectedPos;
      if (_interactiveSelectedPos != null) {
        final pid = _interactiveEngine!.activePositions.entries
            .firstWhere(
              (e) => e.value == _interactiveSelectedPos,
              orElse: () => const MapEntry('', KitaPos(-1, -1)),
            )
            .key;
        _interactiveValidMoves = pid.isNotEmpty
            ? _interactiveEngine!.getLegalMovesForPiece(pid)
            : {};
      } else {
        _interactiveValidMoves = {};
      }
      _interactiveCompleted = false;
      return;
    }

    // Handle Page 8 (Repetition loop)
    if (page.pageNumber == 8) {
      _startPage8RepetitionLoop();
      return;
    }

    // Standard Interactive Pages (Page 5, Page 7, etc.)
    if (page.isInteractive) {
      _interactiveEngine = page.initialEngine;
      _interactiveSelectedPos = page.initialSelectedPos;
      if (_interactiveSelectedPos != null && _interactiveEngine != null) {
        final pid = _interactiveEngine!.activePositions.entries
            .firstWhere(
              (e) => e.value == _interactiveSelectedPos,
              orElse: () => const MapEntry('', KitaPos(-1, -1)),
            )
            .key;
        _interactiveValidMoves = pid.isNotEmpty
            ? _interactiveEngine!.getLegalMovesForPiece(pid)
            : {};
      } else {
        _interactiveValidMoves = {};
      }
    } else {
      _interactiveEngine = null;
      _interactiveSelectedPos = null;
      _interactiveValidMoves = {};
    }
  }

  void _startPage8RepetitionLoop() {
    final page = _currentPage;
    final baseEngine = page.initialEngine!;
    _repetitionEngine = baseEngine;
    _repetitionMoveIndex = 0;

    // Autoplay moves in loop: A4D4, A1A4, D4D1, A4D4, D1A1, D4D1, A1A4, D1A1
    final moveStrings = [
      ('WP2', 'A4', 'D4'),
      ('BP2', 'A1', 'A4'),
      ('WP2', 'D4', 'D1'),
      ('BP2', 'A4', 'D4'),
      ('WP2', 'D1', 'A1'),
      ('BP2', 'D4', 'D1'),
      ('WP2', 'A1', 'A4'),
      ('BP2', 'D1', 'A1'),
    ];

    _repetitionTimer?.cancel();
    _repetitionTimer = Timer.periodic(const Duration(milliseconds: 950), (timer) {
      if (!mounted || _currentPageIndex != 7) {
        timer.cancel();
        return;
      }

      final (pid, fromStr, toStr) = moveStrings[_repetitionMoveIndex % moveStrings.length];
      final m = KitaMove(
        pieceId: pid,
        fromPos: TutorialLessonsData.parsePos(fromStr),
        toPos: TutorialLessonsData.parsePos(toStr),
      );

      final isWhite = pid.startsWith('W');
      final movingEng = KitaGameEngine.custom(
        positions: _repetitionEngine!.positions,
        turn: isWhite ? PieceTeam.white : PieceTeam.black,
        lastMoveWhite: _repetitionEngine!.lastMoveWhite,
        lastMoveBlack: _repetitionEngine!.lastMoveBlack,
        executedMoveWhite: _repetitionEngine!.executedMoveWhite,
        executedMoveBlack: _repetitionEngine!.executedMoveBlack,
        kingEatenBy: _repetitionEngine!.kingEatenBy,
        stateHistory: _repetitionEngine!.stateHistory,
        moveCount: _repetitionEngine!.moveCount + 1,
      );

      final next = movingEng.applyMove(m);
      setState(() {
        _repetitionEngine = next;
        _repetitionMoveIndex++;
      });
      SoundService.instance.playMove();
    });
  }

  void _onScreenTap() {
    final page = _currentPage;

    // If an unintended move was made and retry feedback is showing, screen tap resets the step
    if (_interactiveFeedback != null) {
      _onResetStep();
      return;
    }

    // In Page 3, Card 0 is informational (highlights opponent King on D1).
    // Tapping advances to Card 1 ("Make a move!").
    if (page.pageNumber == 3 && _currentCardIndex == 0) {
      setState(() {
        _currentCardIndex = 1;
        _initPageState();
      });
      return;
    }

    // If page is interactive and player has not completed it yet, ignore screen taps
    if (page.isInteractive && !_interactiveCompleted) {
      return;
    }

    // In Page 6, if first victory condition card was completed, advance to second card
    if (page.pageNumber == 6 && _currentCardIndex == 0) {
      setState(() {
        _currentCardIndex = 1;
        _interactiveCompleted = false;
        _initPageState();
      });
      return;
    }

    // If there are more cards to reveal on this page, advance to next card
    if (_currentCardIndex < page.cards.length - 1) {
      setState(() {
        _currentCardIndex++;
        _initPageState();
      });
      return;
    }

    // Otherwise, advance to next page
    _onNextPage();
  }

  bool get _canGoPrevious =>
      _showPracticePrompt || _currentPageIndex > 0 || _currentCardIndex > 0;

  void _onTapLeft() {
    if (_interactiveFeedback != null) {
      _onResetStep();
      return;
    }
    if (_canGoPrevious) {
      HapticService.instance.selection();
      _onPrevious();
    }
  }

  void _onTapRight() {
    if (_showPracticePrompt) return;
    HapticService.instance.selection();
    _onScreenTap();
  }

  void _onPrevious() {
    if (_showPracticePrompt) {
      setState(() {
        _showPracticePrompt = false;
        _initPageState();
      });
      return;
    }

    if (_currentPageIndex == 5 && _currentCardIndex == 1) {
      setState(() {
        _currentCardIndex = 0;
        _completedPages.remove(5);
        _completedEngines.remove(5);
        _interactiveCompleted = false;
        _initPageState();
      });
      return;
    }

    if (_currentCardIndex > 0) {
      setState(() {
        _currentCardIndex--;
        _initPageState();
      });
      return;
    }

    if (_currentPageIndex > 0) {
      setState(() {
        _currentPageIndex--;
        _currentCardIndex = 0;
        _initPageState();
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  void _onNextPage() async {
    if (_isLastPageOverall) {
      setState(() {
        _showPracticePrompt = true;
      });
      return;
    }

    setState(() {
      _currentPageIndex++;
      _currentCardIndex = 0;
      _initPageState();
    });
  }

  Future<void> _markTutorialCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_tutorial', true);
  }

  void _onResetStep() {
    setState(() {
      if (_currentPageIndex == 2) {
        _page3Tour = 1;
        _playerPage3Move = null;
      }
      _completedPages.remove(_currentPageIndex);
      _completedEngines.remove(_currentPageIndex);
      _interactiveFeedback = null;
      _initPageState();
    });
  }

  void _handleInteractiveMove(KitaMove move) {
    final page = _currentPage;

    if (page.pageNumber == 6) {
      if (_currentCardIndex == 0) {
        _handlePage6CaptureMove(move);
      } else {
        _handlePage6TrapMove(move);
      }
      return;
    }

    switch (page.interactiveType) {
      case InteractiveStepType.freeMove:
        _handlePage3Move(move);
        break;
      case InteractiveStepType.undoDemonstration:
        _handlePage4Move(move);
        break;
      case InteractiveStepType.forcedException:
        _handlePage5Move(move);
        break;
      case InteractiveStepType.captureKing:
        _handlePage6CaptureMove(move);
        break;
      case InteractiveStepType.trapNoLegalMoves:
        _handlePage6TrapMove(move);
        break;
      case InteractiveStepType.retaliationDraw:
        _handlePage7RetaliationMove(move);
        break;
      default:
        break;
    }
  }

  void _handlePage3Move(KitaMove move) {
    if (_page3Tour == 1) {
      final afterWhite = _interactiveEngine!.applyMove(move);

      setState(() {
        _interactiveEngine = afterWhite;
        _autoPlayStage = 1;
        _interactiveFeedback = null;
      });
      SoundService.instance.playMove();
      HapticService.instance.light();

      // After player plays:
      // "If player played A7A5, play D1D2. In other cases, play D1D3."
      Timer(const Duration(milliseconds: 450), () {
        if (!mounted || _currentPageIndex != 2) return;

        final isA7A5 = move.fromPos == TutorialLessonsData.parsePos('A7') &&
            move.toPos == TutorialLessonsData.parsePos('A5');

        final blackMove = isA7A5
            ? KitaMove(
                pieceId: 'BK',
                fromPos: TutorialLessonsData.parsePos('D1'),
                toPos: TutorialLessonsData.parsePos('D2'),
              )
            : KitaMove(
                pieceId: 'BK',
                fromPos: TutorialLessonsData.parsePos('D1'),
                toPos: TutorialLessonsData.parsePos('D3'),
              );

        final blackTurnEng = KitaGameEngine.custom(
          positions: _interactiveEngine!.positions,
          turn: PieceTeam.black,
          lastMoveWhite: _interactiveEngine!.lastMoveWhite,
          lastMoveBlack: _interactiveEngine!.lastMoveBlack,
          executedMoveWhite: _interactiveEngine!.executedMoveWhite,
          executedMoveBlack: _interactiveEngine!.executedMoveBlack,
          kingEatenBy: _interactiveEngine!.kingEatenBy,
          stateHistory: _interactiveEngine!.stateHistory,
          moveCount: _interactiveEngine!.moveCount,
        );

        final afterBlack = blackTurnEng.applyMove(blackMove);

        final readyWhiteEng = KitaGameEngine.custom(
          positions: afterBlack.positions,
          turn: PieceTeam.white,
          lastMoveWhite: afterBlack.lastMoveWhite,
          lastMoveBlack: afterBlack.lastMoveBlack,
          executedMoveWhite: afterBlack.executedMoveWhite,
          executedMoveBlack: afterBlack.executedMoveBlack,
          kingEatenBy: afterBlack.kingEatenBy,
          stateHistory: afterBlack.stateHistory,
          moveCount: afterBlack.moveCount,
        );

        setState(() {
          _interactiveEngine = readyWhiteEng;
          _page3Tour = 2; // Transition to Tour 2: White makes another move!
          _autoPlayStage = 0; // Board becomes active for White's 2nd move
          _interactiveCompleted = false;
        });
        SoundService.instance.playMove();
        HapticService.instance.light();
      });
    } else {
      // Tour 2: White plays second move
      _playerPage3Move = move;
      final afterWhite2 = _interactiveEngine!.applyMove(move);

      setState(() {
        _interactiveEngine = afterWhite2;
        _autoPlayStage = 1; // Temporarily inactive while Black moves
        _interactiveCompleted = false;
        _interactiveFeedback = null;
      });
      SoundService.instance.playMove();
      HapticService.instance.light();

      // Black opponent now plays at the end of Page 3:
      Timer(const Duration(milliseconds: 450), () {
        if (!mounted || _currentPageIndex != 2) return;

        final blackTurnEng = KitaGameEngine.custom(
          positions: _interactiveEngine!.positions,
          turn: PieceTeam.black,
          lastMoveWhite: _interactiveEngine!.lastMoveWhite,
          lastMoveBlack: _interactiveEngine!.lastMoveBlack,
          executedMoveWhite: _interactiveEngine!.executedMoveWhite,
          executedMoveBlack: _interactiveEngine!.executedMoveBlack,
          kingEatenBy: _interactiveEngine!.kingEatenBy,
          stateHistory: _interactiveEngine!.stateHistory,
          moveCount: _interactiveEngine!.moveCount,
        );

        final candidates = [
          KitaMove(pieceId: 'BP2', fromPos: TutorialLessonsData.parsePos('C1'), toPos: TutorialLessonsData.parsePos('D2')),
          KitaMove(pieceId: 'BP2', fromPos: TutorialLessonsData.parsePos('C1'), toPos: TutorialLessonsData.parsePos('D1')),
          KitaMove(pieceId: 'BP2', fromPos: TutorialLessonsData.parsePos('C1'), toPos: TutorialLessonsData.parsePos('A2')),
          KitaMove(pieceId: 'BP1', fromPos: TutorialLessonsData.parsePos('D4'), toPos: TutorialLessonsData.parsePos('D7')),
        ];

        KitaMove? chosenMove;
        final legalOpponentMoves = blackTurnEng.getLegalMovesForTeam(PieceTeam.black);
        for (final cand in candidates) {
          if (legalOpponentMoves.any((m) => m.pieceId == cand.pieceId && m.toPos == cand.toPos)) {
            chosenMove = cand;
            break;
          }
        }

        chosenMove ??= legalOpponentMoves.isNotEmpty ? legalOpponentMoves.first : candidates.first;
        final nextEng = blackTurnEng.applyMove(chosenMove);

        // Turn skips back to White
        final readyWhiteEng = KitaGameEngine.custom(
          positions: nextEng.positions,
          turn: PieceTeam.white,
          lastMoveWhite: nextEng.lastMoveWhite,
          lastMoveBlack: nextEng.lastMoveBlack,
          executedMoveWhite: nextEng.executedMoveWhite,
          executedMoveBlack: nextEng.executedMoveBlack,
          kingEatenBy: nextEng.kingEatenBy,
          stateHistory: nextEng.stateHistory,
          moveCount: nextEng.moveCount >= 2 ? nextEng.moveCount : 2,
        );

        setState(() {
          _interactiveEngine = readyWhiteEng;
          _interactiveCompleted = true;
          _autoPlayStage = 2; // Auto-play complete
          _completedEngines[2] = readyWhiteEng;
          _completedPages[2] = true;
        });
        SoundService.instance.playMove();
        HapticService.instance.light();
      });
    }
  }

  void _handlePage4Move(KitaMove move) {
    final nextEng = _interactiveEngine!.applyMove(move);

    setState(() {
      _interactiveEngine = nextEng;
      _interactiveCompleted = true;
      _interactiveSelectedPos = null;
      _interactiveValidMoves = {};
      _completedEngines[3] = nextEng;
      _completedPages[3] = true;
      _interactiveFeedback = null;
    });
    SoundService.instance.playMove();
    HapticService.instance.light();
  }

  void _handlePage5Move(KitaMove move) {
    // Only legal move: D3 -> C4
    final targetTo = TutorialLessonsData.parsePos('C4');
    final nextEng = _interactiveEngine!.applyMove(move);

    if (move.toPos == targetTo) {
      setState(() {
        _interactiveEngine = nextEng;
        _interactiveCompleted = true;
        _completedEngines[4] = nextEng;
        _completedPages[4] = true;
        _interactiveFeedback = null;
      });
      SoundService.instance.playMove();
      HapticService.instance.light();
    } else {
      setState(() {
        _interactiveEngine = nextEng;
        _interactiveCompleted = false;
        _interactiveFeedback = 'tutorial.tryAgain'.tr();
      });
      SoundService.instance.playMove();
      HapticService.instance.light();
    }
  }

  void _handlePage6CaptureMove(KitaMove move) {
    // WP1 at D3 captures BK at D1
    final bkPos = _interactiveEngine!.positions['BK'];
    final nextEng = _interactiveEngine!.applyMove(move);

    if (move.toPos == bkPos) {
      setState(() {
        _interactiveEngine = nextEng;
        _interactiveCompleted = true;
        // Do NOT set _completedPages[5] = true yet! Card 2 (Trap) must still be played!
        _interactiveFeedback = null;
      });
      SoundService.instance.playCapture();
      HapticService.instance.medium();
    } else {
      setState(() {
        _interactiveEngine = nextEng;
        _interactiveCompleted = false;
        _interactiveFeedback = 'tutorial.tryAgain'.tr();
      });
      SoundService.instance.playMove();
      HapticService.instance.light();
    }
  }

  void _handlePage6TrapMove(KitaMove move) {
    // Expected winning move: A7 -> C7
    final targetTo = TutorialLessonsData.parsePos('C7');
    final nextEng = _interactiveEngine!.applyMove(move);

    if (move.pieceId == 'WK' && move.toPos == targetTo) {
      setState(() {
        _interactiveEngine = nextEng;
        _interactiveCompleted = true;
        _completedEngines[5] = nextEng;
        _completedPages[5] = true;
        _interactiveFeedback = null;
      });
      SoundService.instance.playMove();
      HapticService.instance.light();
    } else {
      setState(() {
        _interactiveEngine = nextEng;
        _interactiveCompleted = false;
        _interactiveFeedback = 'tutorial.tryAgain'.tr();
      });
      SoundService.instance.playMove();
      HapticService.instance.light();
    }
  }

  void _handlePage7RetaliationMove(KitaMove move) {
    // Player captures Black King on D1
    final bkPos = _interactiveEngine!.positions['BK'];
    final afterWhite = _interactiveEngine!.applyMove(move);

    if (move.toPos == bkPos) {
      setState(() {
        _interactiveEngine = afterWhite;
        _autoPlayStage = 1;
        _interactiveFeedback = null;
      });
      SoundService.instance.playCapture();
      HapticService.instance.medium();

      // Opponent BP2 at C7 retaliates to WK at A7
      Timer(const Duration(milliseconds: 650), () {
        if (!mounted || _currentPageIndex != 6) return;
        final retaliationMove = KitaMove(
          pieceId: 'BP2',
          fromPos: TutorialLessonsData.parsePos('C7'),
          toPos: TutorialLessonsData.parsePos('A7'),
        );
        final afterRetaliation = _interactiveEngine!.applyMove(retaliationMove);
        setState(() {
          _interactiveEngine = afterRetaliation;
          _interactiveCompleted = true;
          _autoPlayStage = 2;
          _completedEngines[6] = afterRetaliation;
          _completedPages[6] = true;
        });
        SoundService.instance.playCapture();
        HapticService.instance.medium();
      });
    } else {
      setState(() {
        _interactiveEngine = afterWhite;
        _interactiveCompleted = false;
        _interactiveFeedback = 'tutorial.tryAgain'.tr();
      });
      SoundService.instance.playMove();
      HapticService.instance.light();
    }
  }

  void _launchPracticeBotMatch() async {
    await _markTutorialCompleted();

    if (!mounted) return;
    final authProv = context.read<AuthProvider>();
    final offlineProv = context.read<OfflineGameProvider>();
    final isGuest = authProv.isGuest || authProv.currentUser == null;
    final playerId = authProv.currentUser?.id;
    final playerName = authProv.currentUser?.username ??
        authProv.guestProfile?.nickname ??
        'Guest';
    final playerRating = authProv.currentUser?.rating ?? 1200;

    offlineProv.startOfflineMatch(
      mode: PlayMode.vsAi,
      playerTeam: PieceTeam.white,
      botDifficulty: 1, // Beginner AI
      playerId: playerId,
      playerName: playerName,
      playerRating: playerRating,
      isGuest: isGuest,
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const OfflineMatchScreen(),
        settings: const RouteSettings(name: '/offline_match'),
      ),
    );
  }

  Widget _buildPracticePromptPage(bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: KitaCard(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Celebratory Trophy Badge
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accentGold.withValues(alpha: 0.16),
                  border: Border.all(
                    color: AppColors.accentGold.withValues(alpha: 0.45),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: AppColors.accentGold,
                  size: 38,
                ),
              ),
              const SizedBox(height: 18),

              // Title
              Text(
                'tutorial.practiceTitle'.tr(),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.getTextPrimary(isDark),
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),

              // Description
              Text(
                'tutorial.practiceDesc'.tr(),
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.45,
                  color: AppColors.getTextSecondary(isDark),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),

              // Match details preview card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurfaceElevated
                      : AppColors.lightSurfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.smart_toy_rounded,
                        color: AppColors.primaryLight,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'game.aiBot'.tr(),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.getTextPrimary(isDark),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'game.easy'.tr(),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.getTextMuted(isDark),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accentGold.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Lv. 1',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accentGold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons: Play (Primary) and Cancel
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _launchPracticeBotMatch,
                  icon: const Icon(Icons.play_arrow_rounded, size: 24),
                  label: Text(
                    'tutorial.playPracticeBot'.tr(),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.getBrandPrimary(isDark),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                height: 44,
                child: TextButton.icon(
                  onPressed: () async {
                    await _markTutorialCompleted();
                    if (mounted) Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: Text(
                    'common.cancel'.tr(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.getTextSecondary(isDark),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRichText(String text, bool isDark) {
    final spans = <InlineSpan>[];
    final defaultColor = isDark ? Colors.white : AppColors.lightTextPrimary;
    final colorStack = <Color>[];

    final tagRegex = RegExp(
      r'</?(mint|red|yellow)>|<king_icon/>|<pawn_icon/>',
      caseSensitive: false,
    );

    int lastIndex = 0;
    for (final match in tagRegex.allMatches(text)) {
      if (match.start > lastIndex) {
        final textChunk = text.substring(lastIndex, match.start);
        spans.add(
          TextSpan(
            text: textChunk,
            style: TextStyle(
              fontSize: 15.0,
              height: 1.45,
              fontWeight: colorStack.isNotEmpty ? FontWeight.w700 : FontWeight.w500,
              color: colorStack.isNotEmpty ? colorStack.last : defaultColor,
            ),
          ),
        );
      }

      final matched = match.group(0)!;
      if (matched == '<king_icon/>') {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: CrownPieceWidget(
                size: 20,
                bodyColor: isDark ? const Color(0xFFF1F5F9) : const Color(0xFFE2E8F0),
                accentColor: AppColors.accentGold,
              ),
            ),
          ),
        );
      } else if (matched == '<pawn_icon/>') {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: ShieldPieceWidget(
                size: 19,
                bodyColor: isDark ? const Color(0xFFF1F5F9) : const Color(0xFFE2E8F0),
                accentColor: const Color(0xFF94A3B8),
              ),
            ),
          ),
        );
      } else if (matched == '<mint>') {
        colorStack.add(AppColors.accent);
      } else if (matched == '<red>') {
        colorStack.add(AppColors.lossRed);
      } else if (matched == '<yellow>') {
        colorStack.add(AppColors.accentGold);
      } else if (matched == '</mint>') {
        colorStack.remove(AppColors.accent);
      } else if (matched == '</red>') {
        colorStack.remove(AppColors.lossRed);
      } else if (matched == '</yellow>') {
        colorStack.remove(AppColors.accentGold);
      }

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastIndex),
          style: TextStyle(
            fontSize: 15.0,
            height: 1.45,
            fontWeight: colorStack.isNotEmpty ? FontWeight.w700 : FontWeight.w500,
            color: colorStack.isNotEmpty ? colorStack.last : defaultColor,
          ),
        ),
      );
    }

    return RichText(text: TextSpan(children: spans));
  }

  String _formatMoveNotation(KitaMove? m) {
    if (m == null) return 'A7A5';
    return m.posNotation;
  }

  String _formatReversedNotation(KitaMove? m) {
    if (m == null) return 'A5A7';
    return '${KitaMove.formatPos(m.toPos)}${KitaMove.formatPos(m.fromPos)}';
  }

  Color _getLessonColor(KitaBoardTheme theme, int stepIndex, int totalSteps) {
    if (totalSteps <= 1) return theme.getColorForValue(1);
    final double t = stepIndex / (totalSteps - 1);

    final Color c1 = theme.getColorForValue(1);
    final Color c2 = theme.getColorForValue(2);
    final Color c3 = theme.getColorForValue(3);

    // Board themes range from light (Value 3) to dark (Value 1).
    // Ensure cStart is lighter and cEnd is darker so the progress bar darkens as lessons advance.
    final Color cStart;
    final Color cMid = c2;
    final Color cEnd;

    if (c3.computeLuminance() >= c1.computeLuminance()) {
      cStart = c3;
      cEnd = c1;
    } else {
      cStart = c1;
      cEnd = c3;
    }

    if (t <= 0.5) {
      return Color.lerp(cStart, cMid, t / 0.5) ?? cStart;
    } else {
      return Color.lerp(cMid, cEnd, (t - 0.5) / 0.5) ?? cEnd;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final page = _currentPage;
    final card = _currentCard;

    final gameSettings = context.watch<GameSettingsProvider?>();
    final theme = (gameSettings != null)
        ? gameSettings.currentBoardTheme(isDark)
        : KitaBoardTheme.amberSunset();

    // Determine current display engine
    final KitaGameEngine displayEngine = _repetitionEngine ??
        _interactiveEngine ??
        (card.engine ?? page.initialEngine ?? KitaGameEngine());

    final bool isBoardInteractive = page.isInteractive &&
        !(page.pageNumber == 3 && _currentCardIndex == 0) &&
        !_interactiveCompleted &&
        _interactiveFeedback == null &&
        _autoPlayStage != 1;

    final KitaPos? displaySelectedPos = _interactiveEngine != null
        ? _interactiveSelectedPos
        : (card.selectedPos ?? page.initialSelectedPos);

    final Set<KitaPos> displayValidMoves = _interactiveEngine != null
        ? _interactiveValidMoves
        : (card.validMoves ?? page.initialValidMoves ?? const {});

    final Set<KitaPos> displayTintedTiles =
        card.tintedTiles ?? page.initialTintedTiles ?? const {};

    final Set<KitaPos> displayGrayTiles =
        card.grayTiles ?? page.initialGrayTiles ?? const {};

    // Compute dynamic text for Page 3 and Page 4
    String cardRawText = card.textKey.tr(namedArgs: card.namedArgs);

    if (page.pageNumber == 3) {
      if (_currentCardIndex == 0) {
        cardRawText = card.textKey.tr(namedArgs: card.namedArgs);
      } else if (_page3Tour == 1) {
        cardRawText = card.textKey.tr(namedArgs: card.namedArgs);
      } else {
        final bkPos = _interactiveEngine?.positions['BK'];
        final val = bkPos != null ? KitaBoardConfig.tileValue(bkPos) : 2;
        cardRawText = 'tutorial.page3OpponentMoved'.tr(namedArgs: {'val': '$val'});
      }
    } else if (page.pageNumber == 4) {
      final lastMoveStr = _formatMoveNotation(_playerPage3Move);
      final reversedMoveStr = _formatReversedNotation(_playerPage3Move);
      cardRawText = 'tutorial.page4Card1'.tr(namedArgs: {
        'lastMove': lastMoveStr,
        'reversedMove': reversedMoveStr,
      });
    }

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapUp: (details) {
            final screenWidth = MediaQuery.of(context).size.width;
            if (details.globalPosition.dx < screenWidth * 0.4) {
              _onTapLeft();
            } else {
              _onTapRight();
            }
          },
          child: Stack(
            children: [
              // Subtle Left Edge Gradient Background
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 28,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          (isDark ? Colors.white : Colors.black).withValues(alpha: isDark ? 0.04 : 0.03),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Subtle Right Edge Gradient Background
              if (!_showPracticePrompt)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: 28,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerRight,
                          end: Alignment.centerLeft,
                          colors: [
                            AppColors.getBrandPrimary(isDark).withValues(alpha: isDark ? 0.08 : 0.05),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              ResponsiveLayout(
                maxWidth: 520,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              children: [
                // Top Navigation Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back_rounded,
                          color: AppColors.getTextPrimary(isDark),
                        ),
                        tooltip: 'common.back'.tr(),
                        onPressed: _onPrevious,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkSurfaceElevated
                                  : AppColors.lightSurfaceElevated,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isDark
                                    ? AppColors.darkBorder
                                    : AppColors.lightBorder,
                                width: 0.8,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Row(
                              children: [
                                for (int i = 0; i < _pages.length; i++) ...[
                                  if (i > 0)
                                    Container(
                                      width: 1.5,
                                      color: isDark
                                          ? AppColors.darkBg
                                          : AppColors.lightBg,
                                    ),
                                  Expanded(
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeOutCubic,
                                      color: (_showPracticePrompt || i <= _currentPageIndex)
                                          ? _getLessonColor(
                                              theme,
                                              i,
                                              _pages.length,
                                            )
                                          : Colors.transparent,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Close / Skip Button
                      if (widget.isFirstLaunch && !_showPracticePrompt)
                        TextButton(
                          onPressed: () async {
                            await _markTutorialCompleted();
                            if (context.mounted) Navigator.of(context).pop();
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.getTextSecondary(isDark),
                          ),
                          child: Text(
                            'tutorial.skip'.tr(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        )
                      else
                        IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: AppColors.getTextSecondary(isDark),
                          ),
                          tooltip: 'common.close'.tr(),
                          onPressed: () async {
                            if (_showPracticePrompt) {
                              await _markTutorialCompleted();
                            }
                            if (context.mounted) Navigator.of(context).pop();
                          },
                        ),
                    ],
                  ),
                ),

                if (_showPracticePrompt)
                  Expanded(
                    child: _buildPracticePromptPage(isDark),
                  )
                else ...[
                  // Board & Cards Area
                  Expanded(
                    child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Page Title Header inside page content
                        Padding(
                          padding: const EdgeInsets.only(top: 2, bottom: 8, left: 6, right: 6),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: Text(
                              page.titleKey.tr(),
                              key: ValueKey<String>(page.titleKey),
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                                color: AppColors.getTextPrimary(isDark),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),

                        // Board Frame Card
                        KitaCard(
                          padding: const EdgeInsets.all(6),
                          child: Column(
                            children: [
                              // Optional Interactive status banner & reset
                              if (page.isInteractive &&
                                  !(page.pageNumber == 3 && _currentCardIndex == 0))
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _interactiveCompleted
                                              ? AppColors.winGreen.withValues(alpha: 0.16)
                                              : AppColors.accent.withValues(alpha: 0.16),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _interactiveCompleted
                                                  ? Icons.check_circle_rounded
                                                  : Icons.touch_app_rounded,
                                              size: 15,
                                              color: _interactiveCompleted
                                                  ? AppColors.winGreen
                                                  : AppColors.accentSecondary,
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              _interactiveCompleted
                                                  ? 'common.success'.tr()
                                                  : (page.tryItKey?.tr() ?? 'tutorial.tryIt'.tr()),
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: _interactiveCompleted
                                                    ? AppColors.winGreen
                                                    : AppColors.accentSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Spacer(),
                                      TextButton.icon(
                                        onPressed: _onResetStep,
                                        icon: const Icon(Icons.refresh_rounded, size: 14),
                                        label: Text(
                                          'tutorial.reset'.tr(),
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        style: TextButton.styleFrom(
                                          foregroundColor: AppColors.getTextMuted(isDark),
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              // Unified Game Board
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 500),
                                switchInCurve: Curves.easeInOut,
                                switchOutCurve: Curves.easeInOut,
                                child: KeyedSubtree(
                                  key: ValueKey(
                                    'board-$_currentPageIndex-$_currentCardIndex',
                                  ),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: KitaGameBoard(
                                      displayEngine: displayEngine,
                                      myTeam: 'white',
                                      isMyTurn: true,
                                      isInteractive: isBoardInteractive,
                                      customSelectedPos: displaySelectedPos,
                                      customValidMoves: displayValidMoves,
                                      tintedTiles: displayTintedTiles,
                                      grayTiles: displayGrayTiles,
                                      lastMoves: displayEngine.lastTwoMoves.isNotEmpty
                                          ? displayEngine.lastTwoMoves
                                          : [
                                              if (displayEngine.lastMoveWhite != null)
                                                displayEngine.lastMoveWhite!,
                                              if (displayEngine.lastMoveBlack != null)
                                                displayEngine.lastMoveBlack!,
                                            ],
                                      lastMove: displayEngine.mostRecentMove ??
                                          displayEngine.lastMoveBlack ??
                                          displayEngine.lastMoveWhite,
                                      isHorizontal: true,
                                      flipBoard: false,
                                      theme: theme,
                                      onMakeMove: _handleInteractiveMove,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Text Explanation Card
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          child: KeyedSubtree(
                            key: ValueKey(
                              'card-$_currentPageIndex-$_currentCardIndex-${_interactiveCompleted ? 'done' : 'active'}',
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Optional Badge Header (e.g. "1-Value Tiles" in yellow)
                                if (card.badgeKey != null) ...[
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.accentGold.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      card.badgeKey!.tr(),
                                      style: const TextStyle(
                                        color: AppColors.accentGold,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],

                                // Main Text Card
                                KitaCard(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  child: _buildRichText(cardRawText, isDark),
                                ),

                                // Interactive Retry Feedback
                                if (_interactiveFeedback != null && !_interactiveCompleted) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.lossRed.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: AppColors.lossRed.withValues(alpha: 0.35),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.replay_rounded,
                                          color: AppColors.lossRed,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _interactiveFeedback!,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.lossRed,
                                            ),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: _onResetStep,
                                          child: Text(
                                            'tutorial.reset'.tr(),
                                            style: const TextStyle(color: AppColors.lossRed),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                // Interactive Success Card Banner
                                if (page.isInteractive &&
                                    _interactiveCompleted &&
                                    page.successKey != null) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.winGreen.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: AppColors.winGreen.withValues(alpha: 0.35),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          color: AppColors.winGreen,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            (page.pageNumber == 6)
                                                ? (_currentCardIndex == 0
                                                    ? 'tutorial.page6SuccessKing'.tr()
                                                    : 'tutorial.page6SuccessTrap'.tr())
                                                : page.successKey!.tr(),
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w700,
                                              color: isDark
                                                  ? Colors.white
                                                  : AppColors.lightTextPrimary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Navigation Indicator
                Builder(
                  builder: (context) {
                    if (isBoardInteractive && !_interactiveCompleted) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ScaleTransition(
                          scale: _pulseAnimation,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                            decoration: BoxDecoration(
                              color: AppColors.accentGold.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.accentGold.withValues(alpha: 0.35),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.touch_app_rounded,
                                  size: 16,
                                  color: AppColors.accentGold,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'tutorial.makeYourMove'.tr(),
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.accentGold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    if (_interactiveFeedback != null && !_interactiveCompleted) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ScaleTransition(
                          scale: _pulseAnimation,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                            decoration: BoxDecoration(
                              color: AppColors.lossRed.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.lossRed.withValues(alpha: 0.35),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.replay_rounded,
                                  size: 16,
                                  color: AppColors.lossRed,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'tutorial.reset'.tr(),
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.lossRed,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    // Default dual-zone indicator: Left = Geri (Back), Right = İleri (Next)
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurfaceElevated
                              : AppColors.lightSurfaceElevated,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Left Zone: Geri (Back)
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _onTapLeft,
                              child: Opacity(
                                opacity: _canGoPrevious ? 0.9 : 0.35,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.arrow_back_ios_new_rounded,
                                      size: 13,
                                      color: AppColors.getTextSecondary(isDark),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'common.back'.tr(),
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.getTextSecondary(isDark),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Container(
                              height: 14,
                              width: 1,
                              margin: const EdgeInsets.symmetric(horizontal: 14),
                              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                            ),
                            // Right Zone: İleri (Next)
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _onTapRight,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'tutorial.next'.tr(),
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.getBrandPrimary(isDark),
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 13,
                                    color: AppColors.getBrandPrimary(isDark),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
              ],
            ),
          ),
        ],
      ),
    ),
  ),
);
  }
}
