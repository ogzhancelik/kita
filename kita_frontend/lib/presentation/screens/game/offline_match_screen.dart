import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/navigation/app_route_observer.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/game_models.dart';
import '../../../data/models/ws_message_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/game_settings_provider.dart';
import '../../providers/offline_game_provider.dart';
import '../../widgets/game/game_over_dialog.dart';
import '../../widgets/game/kita_game_board.dart';
import '../../widgets/game/move_history_panel.dart';
import '../../widgets/game/offline_match_menu_dialog.dart';
import '../../widgets/game/player_info_bar.dart';
import 'match_replay_screen.dart';

/// Screen dedicated to playing offline matches (VS AI Bot & Local Co-op).
class OfflineMatchScreen extends StatefulWidget {
  static bool isMatchScreenOpen = false;

  const OfflineMatchScreen({super.key});

  @override
  State<OfflineMatchScreen> createState() => _OfflineMatchScreenState();
}

class _OfflineMatchScreenState extends State<OfflineMatchScreen>
    with WidgetsBindingObserver, RouteAware {
  OfflineGameProvider? _provider;
  bool _isGameOverDialogShowing = false;
  Timer? _gameOverDialogTimer;
  bool _routeSubscribed = false;

  @override
  void initState() {
    super.initState();
    OfflineMatchScreen.isMatchScreenOpen = true;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_routeSubscribed) {
      final modalRoute = ModalRoute.of(context);
      if (modalRoute != null) {
        appRouteObserver.subscribe(this, modalRoute);
        _routeSubscribed = true;
      }
    }
    final prov = context.read<OfflineGameProvider>();
    if (_provider != prov) {
      _provider?.gameOverData.removeListener(_onGameOver);
      _provider = prov;
      _provider?.gameOverData.addListener(_onGameOver);
    }
    // Set in-game and resume clock if this screen is current/visible
    final isCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    if (isCurrent) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _provider?.setInGameScreen(true);
        }
      });
    }
  }

  @override
  void dispose() {
    if (_routeSubscribed) {
      appRouteObserver.unsubscribe(this);
    }
    WidgetsBinding.instance.removeObserver(this);
    OfflineMatchScreen.isMatchScreenOpen = false;
    _gameOverDialogTimer?.cancel();
    _provider?.gameOverData.removeListener(_onGameOver);
    _provider?.setInGameScreen(false);
    super.dispose();
  }

  @override
  void didPush() {
    _provider?.resumeGameClock();
  }

  @override
  void didPopNext() {
    _provider?.resumeGameClock();
  }

  @override
  void didPushNext() {
    _provider?.pauseGameClock();
  }

  @override
  void didPop() {
    _provider?.pauseGameClock();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      final isCurrent = ModalRoute.of(context)?.isCurrent ?? true;
      if (isCurrent) {
        _provider?.resumeGameClock();
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _provider?.pauseGameClock();
    }
  }

  void _onGameOver() {
    final provider = _provider ?? context.read<OfflineGameProvider>();
    final data = provider.gameOverData.value;
    if (data == null || !mounted) return;
    if (_isGameOverDialogShowing || provider.isGameOverDialogActive.value) return;

    _gameOverDialogTimer?.cancel();
    _gameOverDialogTimer = Timer(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      final currentProv = _provider ?? context.read<OfflineGameProvider>();
      if (_isGameOverDialogShowing || currentProv.isGameOverDialogActive.value) return;
      if (!currentProv.isGameOver) return;
      _showGameOverDialog(data);
    });
  }

  void _showGameOverDialog(GameOverPayload data) {
    _gameOverDialogTimer?.cancel();
    final provider = _provider ?? context.read<OfflineGameProvider>();
    if (!mounted || _isGameOverDialogShowing || provider.isGameOverDialogActive.value) return;
    _isGameOverDialogShowing = true;
    provider.isGameOverDialogActive.value = true;

    final isVsAi = provider.offlinePlayMode == PlayMode.vsAi;
    final isCoop = provider.offlinePlayMode == PlayMode.localCoop;
    final isWhiteWinner = data.winnerTeam == 'white';
    final isPlayerWhite = provider.myTeam == 'white';
    final winnerName = isCoop
        ? (isWhiteWinner == isPlayerWhite
            ? (provider.offlinePlayerName ?? 'game.player1'.tr())
            : (provider.opponentInfo?.name ?? 'game.player2'.tr()))
        : null;

    GameOverDialog.show(
      context: context,
      gameOverData: data,
      myUserId: provider.offlinePlayerId ?? 'local',
      isLocalCoop: isCoop,
      winnerName: winnerName,
      myTeam: provider.myTeam,
      elapsedSeconds: provider.elapsedSeconds.value,
      movesCount: provider.moveHistory.value.length,
      isOffline: true,
      onRematch: () {
        provider.requestRematch();
      },
      onBackToMenu: () {
        _isGameOverDialogShowing = false;
        provider.resignAndClear();
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
      onReviewMatch: isVsAi
          ? () {
              final matchRecord = provider.lastOfflineMatchRecord ??
                  provider.buildCurrentOfflineMatchRecord(data);
              if (matchRecord != null) {
                Navigator.of(context, rootNavigator: true).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MatchReplayScreen(match: matchRecord),
                  ),
                );
              }
            }
          : null,
    ).then((_) {
      _isGameOverDialogShowing = false;
      provider.isGameOverDialogActive.value = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OfflineGameProvider>();
    final authProv = context.watch<AuthProvider>();
    final settings = context.watch<GameSettingsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isVsAi = provider.offlinePlayMode == PlayMode.vsAi;
    final isLocalCoop = provider.offlinePlayMode == PlayMode.localCoop;
    final isBlack = provider.myTeam == 'black';

    final opponentName = isLocalCoop
        ? (provider.opponentInfo?.name ?? 'game.player2'.tr())
        : 'game.aiBot'.tr();

    final opponentRatingLabel = isVsAi
        ? provider.offlineBotDifficultyLabel
        : (isLocalCoop ? '2P' : null);

    final myDisplayName = isLocalCoop
        ? (provider.offlinePlayerName ?? (authProv.isAuthenticated ? authProv.displayName : 'game.player1'.tr()))
        : (authProv.isAuthenticated ? authProv.displayName : 'game.you'.tr());

    final myRatingLabel = isLocalCoop ? '1P' : null;

    final myRating = (authProv.isAuthenticated && authProv.currentUser?.rating != null)
        ? authProv.currentUser!.rating
        : 1200;

    final isHorizontal = isLocalCoop
        ? provider.localCoopIsHorizontal
        : settings.isHorizontal;

    final effectiveFlip = settings.shouldFlipBoard(provider.myTeam);
    final flipBoard = isLocalCoop ? (provider.myTeam == 'black') : effectiveFlip;

    final opponentTeam = isBlack ? 'white' : 'black';
    final opponentRemainingMs = provider.timeControl > 0
        ? (opponentTeam == 'white' ? provider.whiteRemainingMs : provider.blackRemainingMs)
        : provider.elapsedSeconds;

    final myRemainingMs = provider.timeControl > 0
        ? (provider.myTeam == 'white' ? provider.whiteRemainingMs : provider.blackRemainingMs)
        : provider.elapsedSeconds;

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Move History Panel (Scrubbable)
            MoveHistoryPanel(
              moveHistory: provider.moveHistory,
              viewingMoveIndex: provider.viewingMoveIndex,
              onSelectMove: provider.viewMoveAt,
              onLive: provider.goLive,
            ),

            // 2. Opponent Player Info Bar
            ValueListenableBuilder<bool>(
              valueListenable: provider.isAiThinking,
              builder: (_, thinking, _) {
                return PlayerInfoBar(
                  isOpponent: true,
                  name: opponentName,
                  rating: isVsAi ? (provider.opponentInfo?.rating ?? 1200) : 1200,
                  ratingLabel: opponentRatingLabel,
                  team: opponentTeam,
                  remainingMs: opponentRemainingMs,
                  isActiveTurn: provider.currentTurn,
                  timeControl: provider.timeControl,
                  avatarIndex: isVsAi
                      ? 7
                      : (isLocalCoop
                          ? (provider.opponentInfo?.avatarIndex ?? 1)
                          : 1),
                  isGameOver: provider.isGameOver,
                  isBot: isVsAi,
                  isGuest: false,
                );
              },
            ),

            // 3. Central Board Area
            Expanded(
              child: Center(
                child: ValueListenableBuilder<int>(
                  valueListenable: provider.viewingMoveIndex,
                  builder: (ctx, viewIdx, _) {
                    return ValueListenableBuilder<KitaGameEngine>(
                      valueListenable: provider.gameEngine,
                      builder: (c1, engine, _) {
                        return ValueListenableBuilder<bool>(
                          valueListenable: provider.isAiThinking,
                          builder: (c2, aiThinking, _) {
                            return ValueListenableBuilder<KitaMove?>(
                              valueListenable: provider.lastMove,
                              builder: (c0, currentLastMove, _) {
                                return ValueListenableBuilder<List<KitaMove>>(
                                  valueListenable: provider.legalMoves,
                                  builder: (c3, legal, _) {
                                    final displayEngine = provider.displayEngine;
                                    final isLive = !provider.isViewingHistory;
                                    final isMyTurn = isLocalCoop ||
                                        (provider.myTeam == displayEngine.turn.name && !aiThinking && isLive);
                                    final canInteract = isLive && !provider.isGameOver && !aiThinking;

                                    return KitaGameBoard(
                                      displayEngine: displayEngine,
                                      myTeam: provider.myTeam,
                                      isMyTurn: isMyTurn,
                                      isInteractive: canInteract,
                                      isLocalCoop: isLocalCoop,
                                      legalMoves: isLive ? legal : const [],
                                      lastMoves: displayEngine.lastTwoMoves,
                                      lastMove: currentLastMove,
                                      flipBoard: flipBoard,
                                      isHorizontal: isHorizontal,
                                      onMakeMove: provider.makeMove,
                                    );
                                  },
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),

            // 4. Current User Player Info Bar
            PlayerInfoBar(
              isOpponent: false,
              name: myDisplayName,
              rating: myRating,
              ratingLabel: myRatingLabel,
              team: provider.myTeam,
              remainingMs: myRemainingMs,
              isActiveTurn: provider.currentTurn,
              timeControl: provider.timeControl,
              avatarIndex: isLocalCoop
                  ? (provider.offlinePlayerAvatarIndex ?? authProv.avatarIndex)
                  : authProv.avatarIndex,
              isGameOver: provider.isGameOver,
              isGuest: false,
            ),

            // 5. Offline Match Bottom Bar
            _buildBottomBar(context, provider, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, OfflineGameProvider provider, bool isDark) {
    return Container(
      width: double.infinity,
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.getCard(isDark),
        border: Border(
          top: BorderSide(
            color: AppColors.getBorder(isDark),
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        children: [
          // 1. Menu Button
          IconButton(
            icon: const Icon(Icons.menu_rounded),
            color: AppColors.getTextPrimary(isDark),
            tooltip: 'online.matchMenu'.tr(),
            onPressed: () {
              FocusManager.instance.primaryFocus?.unfocus();
              OfflineMatchMenuDialog.show(context);
            },
          ),

          const Spacer(),

          // 2. Center: Total Elapsed Match Time
          ValueListenableBuilder<int>(
            valueListenable: provider.elapsedSeconds,
            builder: (ctx, elapsed, _) {
              final mins = (elapsed ~/ 60).toString().padLeft(2, '0');
              final secs = (elapsed % 60).toString().padLeft(2, '0');
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.getBorder(isDark),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: AppColors.getTextSecondary(isDark),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$mins:$secs',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.getTextPrimary(isDark),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const Spacer(),

          // 3. Move Navigation: Back (<) and Forward (>)
          ValueListenableBuilder<int>(
            valueListenable: provider.viewingMoveIndex,
            builder: (ctx, viewIdx, _) {
              final canBack = provider.canStepBackward;
              final canForward = provider.canStepForward;

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    color: canBack
                        ? AppColors.getTextPrimary(isDark)
                        : AppColors.getTextMuted(isDark),
                    tooltip: 'common.prevMove'.tr(),
                    onPressed: canBack ? provider.stepBackward : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded),
                    color: canForward
                        ? AppColors.getTextPrimary(isDark)
                        : AppColors.getTextMuted(isDark),
                    tooltip: 'common.nextMove'.tr(),
                    onPressed: canForward ? provider.stepForward : null,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
