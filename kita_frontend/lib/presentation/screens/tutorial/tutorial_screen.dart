import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/feedback/haptic_service.dart';
import '../../../core/feedback/sound_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/game_models.dart';
import '../../providers/game_settings_provider.dart';
import '../../widgets/common/kita_button.dart';
import '../../widgets/common/kita_card.dart';
import '../../widgets/common/responsive_layout.dart';
import '../../widgets/game/kita_board_theme.dart';
import '../../widgets/game/kita_board_widget.dart';
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

class _TutorialScreenState extends State<TutorialScreen> {
  late final List<TutorialLesson> _lessons;
  int _currentLessonIndex = 0;
  int _currentStepIndex = 0;
  int _currentSubBoardIndex = 0;

  // Interactive step state
  KitaGameEngine? _interactiveEngine;
  Map<String, KitaPos>? _interactivePieces;
  KitaPos? _interactiveSelectedPos;
  String? _interactiveSelectedPieceId;
  Set<KitaPos> _interactiveValidMoves = {};
  bool _interactiveCompleted = false;
  String? _interactiveFeedback;

  // Board state carried over from Lesson 2 Step 2
  KitaGameEngine? _lesson2Step2Engine;
  KitaMove? _lesson2Step2Move;

  // Stage for undo demonstration (0 = initial, 1 = AI moving automatically, 2 = White turn)
  int _undoStage = 0;
  String? _undoFirstPieceId;

  @override
  void initState() {
    super.initState();
    TutorialScreen.isTutorialOpen = true;
    _lessons = TutorialLessonsData.getLessons();
    _initStepState();
  }

  @override
  void dispose() {
    TutorialScreen.isTutorialOpen = false;
    super.dispose();
  }

  void _initStepState() {
    final step = _currentStep;
    _currentSubBoardIndex = 0;
    _interactiveFeedback = null;
    _undoStage = 0;
    _undoFirstPieceId = null;

    if (step.interactiveType == InteractiveStepType.undoDemonstration) {
      // Keep the board from Lesson 2 Step 2 (or default WP1 A4 -> C4)
      final prevMove = _lesson2Step2Move ??
          const KitaMove(
            pieceId: 'WP1',
            fromPos: KitaPos(3, 3), // A4
            toPos: KitaPos(3, 1),   // C4
          );
      final whiteEngine = _lesson2Step2Engine ??
          KitaGameEngine().applyMove(prevMove);

      _interactiveEngine = whiteEngine;
      _interactivePieces = Map<String, KitaPos>.from(whiteEngine.activePositions);
      _interactiveSelectedPos = null;
      _interactiveSelectedPieceId = null;
      _interactiveValidMoves = {};
      _interactiveCompleted = false;
      _undoStage = 1;

      // When step 3 is opened, automatically make Black's move D4 -> D2
      // and automatically select White's last played piece
      Timer(const Duration(milliseconds: 350), () {
        if (!mounted || _undoStage != 1) return;
        // If white played king (A7A5), step count is 1, so Black plays D4 -> D3.
        // Otherwise step count is 2, so Black plays D4 -> D2.
        final KitaMove blackMove = (prevMove.pieceId == 'WK')
            ? const KitaMove(
                pieceId: 'BP1',
                fromPos: KitaPos(3, 0), // D4
                toPos: KitaPos(2, 0),   // D3
              )
            : const KitaMove(
                pieceId: 'BP1',
                fromPos: KitaPos(3, 0), // D4
                toPos: KitaPos(1, 0),   // D2
              );
        final aiEngine = _interactiveEngine!.applyMove(blackMove);
        final lastPid = prevMove.pieceId;
        final lastPos = prevMove.toPos;
        final legalMoves = aiEngine.getLegalMovesForPiece(lastPid);

        setState(() {
          _interactiveEngine = aiEngine;
          _interactivePieces = Map<String, KitaPos>.from(aiEngine.activePositions);
          _interactiveSelectedPieceId = lastPid;
          _interactiveSelectedPos = lastPos;
          _interactiveValidMoves = legalMoves;
          _undoStage = 2;
        });
        SoundService.instance.playMove();
        HapticService.instance.light();
      });
      return;
    }

    if (step.isInteractive) {
      _interactiveEngine = KitaGameEngine.custom(
        positions: Map<String, KitaPos?>.from(step.engine.positions),
        turn: step.engine.turn,
        lastMoveWhite: step.engine.lastMoveWhite,
        lastMoveBlack: step.engine.lastMoveBlack,
      );
      _interactivePieces = Map<String, KitaPos>.from(_interactiveEngine!.activePositions);
      _interactiveSelectedPos = step.selectedPos;
      if (step.selectedPos != null) {
        _interactiveSelectedPieceId = _interactivePieces!.entries
            .firstWhere(
              (e) => e.value == step.selectedPos,
              orElse: () => const MapEntry('', KitaPos(-1, -1)),
            )
            .key;
        if (_interactiveSelectedPieceId!.isNotEmpty) {
          _interactiveValidMoves = _interactiveEngine!.getLegalMovesForPiece(_interactiveSelectedPieceId!);
        } else {
          _interactiveValidMoves = Set<KitaPos>.from(step.validMoves);
        }
      } else {
        _interactiveSelectedPieceId = null;
        _interactiveValidMoves = Set<KitaPos>.from(step.validMoves);
      }
      _interactiveCompleted = false;
    } else {
      _interactiveEngine = null;
      _interactivePieces = null;
      _interactiveSelectedPos = null;
      _interactiveSelectedPieceId = null;
      _interactiveValidMoves = {};
      _interactiveCompleted = false;
    }
  }

  TutorialLesson get _currentLesson => _lessons[_currentLessonIndex];
  TutorialStep get _currentStep => _currentLesson.steps[_currentStepIndex];

  bool get _isFirstStepOverall =>
      _currentLessonIndex == 0 && _currentStepIndex == 0;

  bool get _isLastStepOverall =>
      _currentLessonIndex == _lessons.length - 1 &&
      _currentStepIndex == _currentLesson.steps.length - 1;

  Future<void> _markTutorialCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_tutorial', true);
  }

  void _onSkip() async {
    await _markTutorialCompleted();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _onPrevious() {
    if (_currentStepIndex > 0) {
      setState(() {
        _currentStepIndex--;
        _initStepState();
      });
    } else if (_currentLessonIndex > 0) {
      setState(() {
        _currentLessonIndex--;
        _currentStepIndex = _currentLesson.steps.length - 1;
        _initStepState();
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  void _onNext() async {
    if (_currentStep.isInteractive && !_interactiveCompleted) {
      return;
    }

    if (_isLastStepOverall) {
      await _markTutorialCompleted();
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    if (_currentStepIndex < _currentLesson.steps.length - 1) {
      setState(() {
        _currentStepIndex++;
        _initStepState();
      });
    } else if (_currentLessonIndex < _lessons.length - 1) {
      setState(() {
        _currentLessonIndex++;
        _currentStepIndex = 0;
        _initStepState();
      });
    }
  }

  void _onTileTap(KitaPos pos) {
    final step = _currentStep;
    if (!step.isInteractive || _interactiveCompleted || _interactiveEngine == null) return;
    if (_undoStage == 1) return; // Opponent is currently playing automatically

    // Check if user tapped one of their White pieces
    final pieceAtPos = _interactivePieces!.entries.cast<MapEntry<String, KitaPos>?>().firstWhere(
          (e) => e!.value == pos && e.key.startsWith('W'),
          orElse: () => null,
        );

    if (pieceAtPos != null) {
      // User tapped their own White piece: select it and display its legal moves
      final pid = pieceAtPos.key;
      final legalMoves = _interactiveEngine!.getLegalMovesForPiece(pid);
      setState(() {
        _interactiveSelectedPos = pos;
        _interactiveSelectedPieceId = pid;
        _interactiveValidMoves = legalMoves;
        _interactiveFeedback = null;
      });
      return;
    }

    // Check if user tapped a destination for currently selected piece
    if (_interactiveSelectedPos != null &&
        _interactiveSelectedPieceId != null &&
        _interactiveValidMoves.contains(pos)) {
      final fromPos = _interactiveSelectedPos!;
      final pieceId = _interactiveSelectedPieceId!;
      final move = KitaMove(pieceId: pieceId, fromPos: fromPos, toPos: pos);

      _handleInteractiveMove(step, move);
    }
  }

  void _handleInteractiveMove(TutorialStep step, KitaMove move) {
    switch (step.interactiveType) {
      case InteractiveStepType.freeMove:
        _executeFreeMove(move);
        break;
      case InteractiveStepType.undoDemonstration:
        _executeUndoDemonstrationMove(move);
        break;
      case InteractiveStepType.captureKing:
        _executeCaptureKingMove(move);
        break;
      case InteractiveStepType.trapNoLegalMoves:
        _executeTrapMove(move);
        break;
      case InteractiveStepType.retaliationDraw:
        _executeRetaliationMove(move);
        break;
      case InteractiveStepType.none:
        break;
    }
  }

  void _executeFreeMove(KitaMove move) {
    final nextEngine = _interactiveEngine!.applyMove(move);
    _lesson2Step2Engine = nextEngine;
    _lesson2Step2Move = move;
    setState(() {
      _interactiveEngine = nextEngine;
      _interactivePieces = Map<String, KitaPos>.from(nextEngine.activePositions);
      _interactiveSelectedPos = move.toPos;
      _interactiveValidMoves = {};
      _interactiveCompleted = true;
      _interactiveFeedback = null;
    });
    SoundService.instance.playMove();
    HapticService.instance.light();
  }

  void _executeUndoDemonstrationMove(KitaMove move) {
    final nextEngine = _interactiveEngine!.applyMove(move);
    setState(() {
      _interactiveEngine = nextEngine;
      _interactivePieces = Map<String, KitaPos>.from(nextEngine.activePositions);
      _interactiveSelectedPos = move.toPos;
      _interactiveValidMoves = {};
      _interactiveCompleted = true;
      _interactiveFeedback = null;
    });
    SoundService.instance.playMove();
    HapticService.instance.light();
  }

  void _executeCaptureKingMove(KitaMove move) {
    final bkPos = _interactivePieces!['BK'];
    if (move.toPos == bkPos) {
      // Captured Black King!
      final nextEngine = _interactiveEngine!.applyMove(move);
      setState(() {
        _interactiveEngine = nextEngine;
        _interactivePieces = Map<String, KitaPos>.from(nextEngine.activePositions);
        _interactiveSelectedPos = move.toPos;
        _interactiveValidMoves = {};
        _interactiveCompleted = true;
        _interactiveFeedback = null;
      });
      SoundService.instance.playCapture();
      HapticService.instance.medium();
    } else {
      // Made a legal move, but not the king capture
      setState(() {
        _interactiveFeedback = 'tutorial.tryAgain'.tr();
      });
    }
  }

  void _executeTrapMove(KitaMove move) {
    // Expected winning move: A7C7 (WK from (6, 3) to (6, 1))
    if (move.pieceId == 'WK' &&
        move.fromPos == const KitaPos(6, 3) &&
        move.toPos == const KitaPos(6, 1)) {
      final nextEngine = _interactiveEngine!.applyMove(move);
      setState(() {
        _interactiveEngine = nextEngine;
        _interactivePieces = Map<String, KitaPos>.from(nextEngine.activePositions);
        _interactiveSelectedPos = move.toPos;
        _interactiveValidMoves = {};
        _interactiveCompleted = true;
        _interactiveFeedback = null;
      });
      SoundService.instance.playMove();
      HapticService.instance.light();
    } else {
      setState(() {
        _interactiveFeedback = 'tutorial.tryAgain'.tr();
      });
    }
  }

  void _executeRetaliationMove(KitaMove move) {
    final bkPos = _interactivePieces!['BK'];
    if (move.toPos == bkPos) {
      // User captured Black King
      final afterWhiteMove = _interactiveEngine!.applyMove(move);
      setState(() {
        _interactiveEngine = afterWhiteMove;
        _interactivePieces = Map<String, KitaPos>.from(afterWhiteMove.activePositions);
        _interactiveSelectedPos = move.toPos;
        _interactiveValidMoves = {};
        _undoStage = 1;
        _interactiveFeedback = null;
      });
      SoundService.instance.playCapture();
      HapticService.instance.medium();

      // Automatic retaliation: Black BP1 at (6, 1) captures White King at (6, 3)
      Timer(const Duration(milliseconds: 650), () {
        if (!mounted) return;
        const retaliationMove = KitaMove(
          pieceId: 'BP1',
          fromPos: KitaPos(6, 1),
          toPos: KitaPos(6, 3),
        );
        final afterRetaliation = _interactiveEngine!.applyMove(retaliationMove);
        setState(() {
          _interactiveEngine = afterRetaliation;
          _interactivePieces = Map<String, KitaPos>.from(afterRetaliation.activePositions);
          _interactiveSelectedPos = null;
          _interactiveValidMoves = {};
          _interactiveCompleted = true;
          _undoStage = 0;
        });
        SoundService.instance.playCapture();
        HapticService.instance.medium();
      });
    } else {
      setState(() {
        _interactiveFeedback = 'tutorial.tryAgain'.tr();
      });
    }
  }

  void _resetInteractiveStep() {
    setState(() {
      _initStepState();
    });
  }

  void _showLessonListSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 12),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.menu_book_rounded,
                        color: AppColors.accentGold,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'tutorial.lessonList'.tr(),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _lessons.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, idx) {
                      final lesson = _lessons[idx];
                      final isCurrent = idx == _currentLessonIndex;

                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isCurrent
                                ? AppColors.primary
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        tileColor: isCurrent
                            ? AppColors.primary.withValues(alpha: 0.12)
                            : (isDark ? AppColors.darkCard : AppColors.lightCard),
                        leading: CircleAvatar(
                          backgroundColor: isCurrent
                              ? AppColors.primary
                              : (isDark
                                  ? AppColors.darkSurfaceElevated
                                  : AppColors.lightSurfaceElevated),
                          child: Icon(
                            lesson.icon,
                            color: isCurrent ? Colors.white : AppColors.accentGold,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          '${lesson.lessonNumber}. ${lesson.titleKey.tr()}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                        trailing: isCurrent
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.winGreen,
                                size: 20,
                              )
                            : null,
                        onTap: () {
                          Navigator.of(ctx).pop();
                          setState(() {
                            _currentLessonIndex = idx;
                            _currentStepIndex = 0;
                            _initStepState();
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardText(String text, bool isDark) {
    final regex = RegExp(r'<mint>(.*?)</mint>');
    final matches = regex.allMatches(text);
    if (matches.isEmpty) {
      return Text(
        text,
        style: TextStyle(
          fontSize: 14.5,
          height: 1.45,
          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        ),
      );
    }

    final spans = <InlineSpan>[];
    int currentIndex = 0;
    for (final match in matches) {
      if (match.start > currentIndex) {
        spans.add(
          TextSpan(
            text: text.substring(currentIndex, match.start),
            style: TextStyle(
              fontSize: 14.5,
              height: 1.45,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        );
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: const TextStyle(
            fontSize: 14.5,
            height: 1.45,
            fontWeight: FontWeight.w700,
            color: AppColors.accent, // Soft Mint
          ),
        ),
      );
      currentIndex = match.end;
    }
    if (currentIndex < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(currentIndex),
          style: TextStyle(
            fontSize: 14.5,
            height: 1.45,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
      );
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final step = _currentStep;
    final lesson = _currentLesson;

    final gameSettings = context.watch<GameSettingsProvider?>();
    final theme = (gameSettings != null)
        ? gameSettings.currentBoardTheme(isDark)
        : KitaBoardTheme.amberSunset();

    // Determine current sub-board if active
    final hasSubBoards = step.subBoards != null && step.subBoards!.isNotEmpty;
    final currentSub = hasSubBoards ? step.subBoards![_currentSubBoardIndex] : null;

    final Map<String, KitaPos> displayPieces = _interactivePieces ??
        (currentSub != null
            ? Map<String, KitaPos>.from(currentSub.engine.activePositions)
            : Map<String, KitaPos>.from(step.engine.activePositions));

    final KitaPos? displaySelectedPos = _interactivePieces != null
        ? _interactiveSelectedPos
        : (currentSub != null ? currentSub.selectedPos : step.selectedPos);

    final Set<KitaPos> displayValidMoves = _interactivePieces != null
        ? _interactiveValidMoves
        : (currentSub != null ? currentSub.validMoves : step.validMoves);

    final bool nextDisabled = step.isInteractive && !_interactiveCompleted;

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      body: SafeArea(
        child: ResponsiveLayout(
          maxWidth: 580,
          child: Column(
            children: [
              // Top Navigation Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                    const SizedBox(width: 4),
                    // Lesson selector pill
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _showLessonListSheet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurface
                              : AppColors.lightSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              lesson.icon,
                              color: AppColors.accentGold,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'tutorial.lessonOf'.tr(namedArgs: {
                                'current': '${lesson.lessonNumber}',
                                'total': '${_lessons.length}',
                              }),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.getTextPrimary(isDark),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 16,
                              color: AppColors.getTextMuted(isDark),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (widget.isFirstLaunch)
                      TextButton(
                        onPressed: _onSkip,
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
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                  ],
                ),
              ),

              // Scrollable Content: Board + Explanation Cards
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Board Frame Card
                      KitaCard(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            // Interactive mode status banner & reset
                            if (step.isInteractive)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
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
                                                : (step.tryItKey?.tr() ?? 'tutorial.tryIt'.tr()),
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
                                      onPressed: _resetInteractiveStep,
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

                            // Sub-board selector tabs (for tile values & dynamic steps)
                            if (hasSubBoards)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(
                                      step.subBoards!.length,
                                      (idx) {
                                        final isSelected = idx == _currentSubBoardIndex;
                                        final sub = step.subBoards![idx];
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 4),
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(16),
                                            onTap: () {
                                              setState(() {
                                                _currentSubBoardIndex = idx;
                                              });
                                            },
                                            child: AnimatedContainer(
                                              duration: const Duration(milliseconds: 200),
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 6,
                                              ),
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? AppColors.primary
                                                    : (isDark
                                                        ? AppColors.darkSurfaceElevated
                                                        : AppColors.lightSurfaceElevated),
                                                borderRadius: BorderRadius.circular(16),
                                                border: Border.all(
                                                  color: isSelected
                                                      ? AppColors.primary
                                                      : (isDark
                                                          ? AppColors.darkBorder
                                                          : AppColors.lightBorder),
                                                ),
                                              ),
                                              child: Text(
                                                sub.labelKey.tr(),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: isSelected
                                                      ? FontWeight.w700
                                                      : FontWeight.w500,
                                                  color: isSelected
                                                      ? Colors.white
                                                      : AppColors.getTextSecondary(isDark),
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),

                            // Kita Board with smooth transition fade
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 700),
                              switchInCurve: Curves.easeInOut,
                              switchOutCurve: Curves.easeInOut,
                              transitionBuilder: (child, animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: child,
                                );
                              },
                              child: KeyedSubtree(
                                key: ValueKey(
                                  'board-$_currentLessonIndex-$_currentStepIndex-$_currentSubBoardIndex',
                                ),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: KitaBoardWidget(
                                    pieces: displayPieces,
                                    selectedPos: displaySelectedPos,
                                    validMoves: displayValidMoves,
                                    onTileTap: step.isInteractive ? _onTileTap : null,
                                    isHorizontal: true,
                                    flipBoard: false,
                                    theme: theme,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Animated Instruction Explanation Cards (Without titles)
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.05),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: KeyedSubtree(
                          key: ValueKey('cards-$_currentLessonIndex-$_currentStepIndex'),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (int i = 0; i < step.textKeys.length; i++) ...[
                                KitaCard(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  child: _buildCardText(step.textKeys[i].tr(), isDark),
                                ),
                                if (i < step.textKeys.length - 1)
                                  const SizedBox(height: 8),
                              ],

                              // Undo prompt guidance during stage 2
                              if (step.interactiveType == InteractiveStepType.undoDemonstration &&
                                  _undoStage == 2 &&
                                  !_interactiveCompleted) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentGold.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppColors.accentGold.withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.info_outline_rounded,
                                        color: AppColors.accentGold,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'tutorial.lesson2Step3SubPrompt'.tr(),
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? AppColors.darkTextPrimary
                                                : AppColors.lightTextPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // Retry feedback if wrong move was made
                              if (_interactiveFeedback != null && !_interactiveCompleted) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: AppColors.lossRed.withValues(alpha: 0.12),
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
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? AppColors.darkTextPrimary
                                                : AppColors.lightTextPrimary,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: _resetInteractiveStep,
                                        style: TextButton.styleFrom(
                                          foregroundColor: AppColors.lossRed,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        child: Text('tutorial.reset'.tr()),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // Interactive Success Banner
                              if (step.isInteractive && _interactiveCompleted && step.successDescKey != null) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.winGreen.withValues(alpha: 0.12),
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
                                          step.successDescKey!.tr(),
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? AppColors.darkTextPrimary
                                                : AppColors.lightTextPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ] else if (step.isInteractive && !_interactiveCompleted && _interactiveFeedback == null) ...[
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.lightbulb_outline_rounded,
                                      size: 16,
                                      color: AppColors.accentGold,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'tutorial.interactiveHint'.tr(),
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontStyle: FontStyle.italic,
                                          color: AppColors.getTextMuted(isDark),
                                        ),
                                      ),
                                    ),
                                  ],
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

              // Bottom Navigation Dock
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  border: Border(
                    top: BorderSide(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // Back button
                    if (!_isFirstStepOverall)
                      KitaButton(
                        text: 'common.back'.tr(),
                        icon: Icons.chevron_left_rounded,
                        variant: KitaButtonVariant.secondary,
                        width: 105,
                        height: 44,
                        onPressed: _onPrevious,
                      )
                    else
                      const SizedBox(width: 105),

                    const Spacer(),

                    // Step Dots Indicator
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        _currentLesson.steps.length,
                        (index) {
                          final isActive = index == _currentStepIndex;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: isActive ? 20 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppColors.primary
                                  : (isDark ? Colors.white24 : Colors.black12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        },
                      ),
                    ),

                    const Spacer(),

                    // Next / Finish Button
                    KitaButton(
                      text: _isLastStepOverall
                          ? 'tutorial.finish'.tr()
                          : 'tutorial.next'.tr(),
                      icon: _isLastStepOverall
                          ? Icons.check_rounded
                          : Icons.chevron_right_rounded,
                      variant: KitaButtonVariant.primary,
                      width: 105,
                      height: 44,
                      onPressed: nextDisabled ? null : _onNext,
                    ),
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
