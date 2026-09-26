import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/game_models.dart';
import '../../../data/models/ws_message_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/game_settings_provider.dart';
import '../../providers/online_game_provider.dart';
import '../../widgets/game/chat_panel.dart';
import '../../widgets/game/game_over_dialog.dart';
import '../../widgets/game/kita_board_widget.dart';
import '../../widgets/game/match_bottom_bar.dart';
import '../../widgets/game/move_history_panel.dart';
import '../../widgets/game/player_info_bar.dart';
import '../../widgets/home/user_profile_dialog.dart';
import 'match_replay_screen.dart';

/// Online match screen (Portrait/Default) with space-efficient layout.
///
/// Layout order (Top to Bottom):
///   1. MoveHistoryPanel (horizontal scrollable ribbon)
///   2. Opponent PlayerInfoBar (left avatar/name/elo, right clock)
///   3. Board Container (Stack with centered board fitting its container, and rotate button at top-left)
///   4. User PlayerInfoBar (left clock, right name/elo/avatar, tap to open profile)
///   5. ChatPanel (inline; thin header and input timer only when typing; pinned to bottom)
///   6. MatchBottomBar (menu, chat toggle, centered timer, move back/forward buttons)
class OnlineMatchScreen extends StatefulWidget {
  static bool isMatchScreenOpen = false;

  const OnlineMatchScreen({super.key});

  @override
  State<OnlineMatchScreen> createState() => _OnlineMatchScreenState();
}

class _OnlineMatchScreenState extends State<OnlineMatchScreen> {
  OnlineGameProvider? _provider;
  bool _isGameOverDialogShowing = false;
  final GlobalKey _chatPanelKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    OnlineMatchScreen.isMatchScreenOpen = true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final prov = context.read<OnlineGameProvider>();
    if (_provider != prov) {
      _provider?.gameOverData.removeListener(_onGameOver);
      _provider?.matchState.removeListener(_onMatchStateChanged);
      _provider = prov;
      _provider?.gameOverData.addListener(_onGameOver);
      _provider?.matchState.addListener(_onMatchStateChanged);
    }
  }

  @override
  void dispose() {
    OnlineMatchScreen.isMatchScreenOpen = false;
    _provider?.gameOverData.removeListener(_onGameOver);
    _provider?.matchState.removeListener(_onMatchStateChanged);
    super.dispose();
  }

  void _onMatchStateChanged() {
    final state = _provider?.matchState.value;
    if (state == OnlineMatchState.idle && mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    if (state == OnlineMatchState.inMatch) {
      _isGameOverDialogShowing = false;
    }
  }

  void _onGameOver() {
    final provider = _provider ?? context.read<OnlineGameProvider>();
    final data = provider.gameOverData.value;
    if (data == null) return;
    if (_isGameOverDialogShowing || provider.isGameOverDialogActive.value) return;

    // Show game over dialog
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isGameOverDialogShowing || provider.isGameOverDialogActive.value) return;
      _showGameOverDialog(data);
    });
  }

  void _showGameOverDialog(GameOverPayload data) {
    final provider = _provider ?? context.read<OnlineGameProvider>();
    if (!mounted || _isGameOverDialogShowing || provider.isGameOverDialogActive.value) return;
    _isGameOverDialogShowing = true;
    context.read<AuthProvider>().refreshProfile();

    final isVsAi = provider.isOffline && provider.offlinePlayMode == PlayMode.vsAi;

    GameOverDialog.show(
      context: context,
      gameOverData: data,
      myUserId: provider.myUserId ?? '',
      onRematch: () {
        provider.requestRematch();
      },
      onBackToMenu: () {
        _isGameOverDialogShowing = false;
        provider.leaveFinishedMatch();
        context.read<AuthProvider>().refreshProfile();
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OnlineGameProvider>();
    final authProv = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBlack = provider.myTeam == 'black';

    final opponentName = provider.isOffline
        ? (provider.offlinePlayMode == PlayMode.localCoop
            ? (isBlack ? 'game.playWhite'.tr() : 'game.playBlack'.tr())
            : (provider.opponentInfo?.name ?? 'game.aiBot'.tr()))
        : (provider.opponentInfo?.name ?? 'online.opponent'.tr());

    final opponentRating = provider.opponentInfo?.rating ?? 1200;

    final isBot = provider.isOffline && provider.offlinePlayMode == PlayMode.vsAi;
    final isLocalCoop = provider.isOffline && provider.offlinePlayMode == PlayMode.localCoop;
    final opponentRatingLabel = isBot
        ? provider.offlineBotDifficultyLabel
        : (isLocalCoop ? '2P' : null);

    final myDisplayName = provider.isOffline
        ? (provider.offlinePlayMode == PlayMode.localCoop
            ? (isBlack ? 'game.playBlack'.tr() : 'game.playWhite'.tr())
            : (authProv.isAuthenticated ? authProv.displayName : 'game.you'.tr()))
        : ((provider.myUsername != null && provider.myUsername!.isNotEmpty)
            ? provider.myUsername!
            : authProv.displayName);

    final myRating = provider.isOffline
        ? (authProv.isAuthenticated && authProv.currentUser?.rating != null
            ? authProv.currentUser!.rating
            : 1200)
        : ((authProv.isAuthenticated && authProv.currentUser?.rating != null)
            ? authProv.currentUser!.rating
            : provider.myRating);

    final canLeaveFreely =
        provider.matchState.value == OnlineMatchState.gameOver ||
            provider.matchState.value == OnlineMatchState.idle;

    // Detect if soft keyboard is currently open
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardOpen = keyboardHeight > 60;
    final isChatOpen = provider.isChatOpen && !provider.isOffline;

    return PopScope(
      canPop: canLeaveFreely,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _showLeaveConfirmation(context);
        } else if (canLeaveFreely) {
          provider.leaveFinishedMatch();
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Draw offer banner (shown when opponent offers a draw)
              ValueListenableBuilder<DrawOfferPayload?>(
                valueListenable: provider.drawOffer,
                builder: (context, drawOffer, _) {
                  if (drawOffer == null) return const SizedBox.shrink();
                  return _buildDrawOfferBanner(context, provider, isDark, drawOffer);
                },
              ),

              // Post-game status & controls banner (shown when dialog is dismissed)
              if (provider.gameOverData.value != null && !isKeyboardOpen)
                _buildGameOverBanner(context, provider, isDark),

              // 1. Moves ribbon (hidden when keyboard is open to maximize space)
              if (!isKeyboardOpen) const MoveHistoryPanel(),

              // Middle dynamic game area: Opponent Card, Board, User Card, Chat Panel
              // Sized so that Opponent Card, Board, User Card, and Chat stick together without gaps.
              // When the board orientation flips, board panel and chat panel resize accordingly.
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final gameSettings = context.watch<GameSettingsProvider>();
                    final isLocalCoop = provider.isOffline && provider.offlinePlayMode == PlayMode.localCoop;
                    final isHorizontal = isLocalCoop
                        ? provider.localCoopIsHorizontal
                        : gameSettings.isHorizontal;
                    final effectiveFlip = gameSettings.shouldFlipBoard(provider.myTeam ?? 'white');

                    final totalHeight = constraints.maxHeight;
                    final totalWidth = constraints.maxWidth;

                    final boardWidget = _BoardSection(
                      provider: provider,
                      flipBoard: effectiveFlip,
                      isHorizontal: isHorizontal,
                    );

                    // When typing, player cards are hidden to maximize board & chat visibility
                    if (isKeyboardOpen) {
                      final double boardHeight = isHorizontal
                          ? min(totalWidth * (4.0 / 7.0), totalHeight * 0.55)
                          : min(totalHeight * 0.50, totalWidth * (7.0 / 4.0));
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: boardHeight,
                            width: totalWidth,
                            child: boardWidget,
                          ),
                          Expanded(
                            child: ChatPanel(
                              key: _chatPanelKey,
                              isKeyboardOpen: true,
                            ),
                          ),
                        ],
                      );
                    }

                    final isGameOver = provider.matchState.value == OnlineMatchState.gameOver;

                    final opponentCard = PlayerInfoBar(
                      isOpponent: true,
                      name: opponentName,
                      rating: opponentRating,
                      ratingLabel: opponentRatingLabel,
                      avatarIndex: provider.opponentInfo?.avatarIndex,
                      team: isBlack ? 'white' : 'black',
                      remainingMs: isBlack
                          ? provider.whiteRemainingMs
                          : provider.blackRemainingMs,
                      isActiveTurn: provider.currentTurn,
                      timeControl: provider.timeControl,
                      isGameOver: isGameOver,
                      onTap: () {
                        final opp = provider.opponentInfo;
                        final isBot = (provider.isOffline && provider.offlinePlayMode == PlayMode.vsAi) || opp?.id == 'bot';
                        final isGuest = (opp?.id != null && opp!.id.startsWith('guest-')) ||
                            (opponentName.toLowerCase().startsWith('guest') && !isBot);
                        UserProfileDialog.show(
                          context,
                          userId: opp?.id,
                          fallbackName: opponentName,
                          fallbackAvatarIndex: opp?.avatarIndex,
                          fallbackRating: opponentRating,
                          isBot: isBot,
                          isGuest: isGuest,
                        );
                      },
                    );

                    final userCard = PlayerInfoBar(
                      isOpponent: false,
                      name: myDisplayName,
                      rating: myRating,
                      avatarIndex: authProv.avatarIndex,
                      team: provider.myTeam ?? 'white',
                      remainingMs: isBlack
                          ? provider.blackRemainingMs
                          : provider.whiteRemainingMs,
                      isActiveTurn: provider.currentTurn,
                      timeControl: provider.timeControl,
                      isGameOver: isGameOver,
                      onTap: () => UserProfileDialog.show(context),
                    );

                    const double cardsHeight = 96.0; // Two PlayerInfoBars (~48px each)

                    // Case A: Chat is toggled OFF (cards stick to up/down panels, board centered)
                    if (!isChatOpen) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          opponentCard,
                          Expanded(
                            child: Center(
                              child: boardWidget,
                            ),
                          ),
                          userCard,
                        ],
                      );
                    }

                    // Case B: Chat is toggled ON (default)
                    const double minChatHeight = 140.0;
                    final double availableForBoardAndChat = max(minChatHeight + 60.0, totalHeight - cardsHeight);
                    final double maxBoardHeight = max(60.0, availableForBoardAndChat - minChatHeight);

                    final double boardHeight;
                    if (isHorizontal) {
                      final double naturalHorizontalHeight = totalWidth * (4.0 / 7.0);
                      boardHeight = min(naturalHorizontalHeight, maxBoardHeight);
                    } else {
                      // Vertical orientation (4 cols x 7 rows)
                      final double targetVerticalHeight = availableForBoardAndChat * 0.58;
                      final double naturalVerticalHeight = totalWidth * (7.0 / 4.0);
                      boardHeight = min(min(targetVerticalHeight, maxBoardHeight), naturalVerticalHeight);
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        opponentCard,
                        SizedBox(
                          height: boardHeight,
                          width: totalWidth,
                          child: boardWidget,
                        ),
                        userCard,
                        Expanded(
                          child: ChatPanel(
                            key: _chatPanelKey,
                            isKeyboardOpen: false,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              // 6. Bottom Action Bar (Menu, Chat toggle, Centered Timer, Step Back/Forward - hidden when typing)
              if (!isKeyboardOpen) const MatchBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawOfferBanner(
    BuildContext context,
    OnlineGameProvider provider,
    bool isDark,
    DrawOfferPayload offer,
  ) {
    final opponentName = offer.username.isNotEmpty
        ? offer.username
        : (provider.opponentInfo?.name ?? 'online.opponent'.tr());

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.getCard(isDark),
        border: Border(
          bottom: BorderSide(
            color: AppColors.primaryGreen.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.handshake_rounded, color: AppColors.primaryGreen, size: 20),
            const SizedBox(width: 8),
            Text(
              'online.drawOfferReceived'.tr(args: [opponentName]),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.getTextPrimary(isDark),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () => provider.acceptDrawOffer(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('online.accept'.tr()),
            ),
            const SizedBox(width: 6),
            OutlinedButton(
              onPressed: () => provider.declineDrawOffer(),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.lossRed,
                side: const BorderSide(color: AppColors.lossRed),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('online.decline'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameOverBanner(
    BuildContext context,
    OnlineGameProvider provider,
    bool isDark,
  ) {
    final data = provider.gameOverData.value;
    if (data == null) return const SizedBox.shrink();

    final isDraw = data.isDraw;
    final isWinner = !isDraw &&
        ((data.winnerId != null && data.winnerId == provider.myUserId) ||
            (provider.myTeam != null && provider.myTeam == data.winner));

    final Color statusColor = isDraw
        ? AppColors.drawGray
        : (isWinner ? AppColors.victory : AppColors.lossRed);

    final IconData statusIcon = isDraw
        ? Icons.handshake_outlined
        : (isWinner ? Icons.emoji_events : Icons.sentiment_dissatisfied);

    final String titleKey = isDraw
        ? 'online.resultDraw'
        : (isWinner ? 'online.resultVictory' : 'online.resultDefeat');

    return ValueListenableBuilder<bool>(
      valueListenable: provider.isRematchRequested,
      builder: (ctx, isRequested, _) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.getCard(isDark),
            border: Border(
              bottom: BorderSide(
                color: statusColor.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Result badge
                Icon(statusIcon, color: statusColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  titleKey.tr(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 12),

                // Show Results dialog button
                TextButton.icon(
                  onPressed: () => _showGameOverDialog(data),
                  icon: const Icon(Icons.analytics_outlined, size: 16),
                  label: Text('online.showResults'.tr()),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.getTextPrimary(isDark),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Rematch action: Incoming offer, Waiting for requested rematch, or Request button
                ValueListenableBuilder<RematchOfferedPayload?>(
                  valueListenable: provider.rematchOffer,
                  builder: (ctx, offer, _) {
                    if (offer != null) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => provider.acceptRematch(),
                            icon: const Icon(Icons.check_rounded, size: 14),
                            label: Text('online.accept'.tr()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryGreen,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              textStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            onPressed: () => provider.declineRematch(),
                            tooltip: 'online.decline'.tr(),
                            icon: const Icon(Icons.close_rounded, size: 16),
                            color: AppColors.lossRed,
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      );
                    }

                    if (isRequested) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.primaryGreen),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'online.waitingForRematch'.tr(),
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            onPressed: () => provider.cancelRematchRequest(),
                            icon: const Icon(Icons.close_rounded, size: 16),
                            color: AppColors.lossRed,
                            tooltip: 'online.cancelRematch'.tr(),
                            padding: const EdgeInsets.all(2),
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      );
                    }

                    return ElevatedButton.icon(
                      onPressed: () => provider.requestRematch(),
                      icon: const Icon(Icons.replay_rounded, size: 14),
                      label: Text('online.rematch'.tr()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: AppColors.darkTextPrimary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(width: 8),

                // Exit to menu button
                IconButton(
                  icon: const Icon(Icons.exit_to_app_rounded, size: 18),
                  color: AppColors.lossRed,
                  tooltip: 'online.backToMenu'.tr(),
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    provider.leaveFinishedMatch();
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLeaveConfirmation(BuildContext context) {
    final provider = context.read<OnlineGameProvider>();
    if (provider.matchState.value == OnlineMatchState.gameOver ||
        provider.matchState.value == OnlineMatchState.idle) {
      provider.leaveFinishedMatch();
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }

    if (provider.isOffline) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.getCard(isDark),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'online.returnToMenu'.tr(),
            style: TextStyle(
              color: AppColors.getTextPrimary(isDark),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'online.returnToMenuDesc'.tr(),
            style: TextStyle(color: AppColors.getTextSecondary(isDark)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'online.cancel'.tr(),
                style: TextStyle(color: AppColors.getTextMuted(isDark)),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: Text(
                'online.returnToMenu'.tr(),
                style: TextStyle(
                  color: isDark ? AppColors.accentGold : AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                provider.resign();
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: Text(
                'online.resignAndLeave'.tr(),
                style: const TextStyle(color: AppColors.lossRed),
              ),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          title: Text('online.leaveTitle'.tr()),
          content: Text('online.leaveMessage'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('online.cancel'.tr()),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: Text(
              'online.returnToMenu'.tr(),
              style: TextStyle(
                color: isDark ? AppColors.accentGold : AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              provider.resignAndClear();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: Text(
              'online.resignAndLeave'.tr(),
              style: const TextStyle(color: AppColors.lossRed),
            ),
          ),
        ],
      );
    },
  );
  }
}

/// Board section that uses ValueListenableBuilder for granular rebuilds.
class _BoardSection extends StatelessWidget {
  final OnlineGameProvider provider;
  final bool flipBoard;
  final bool isHorizontal;

  const _BoardSection({
    required this.provider,
    required this.flipBoard,
    this.isHorizontal = true,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: provider.viewingMoveIndex,
      builder: (ctx, viewIdx, _) {
        return ValueListenableBuilder<KitaGameEngine>(
          valueListenable: provider.gameEngine,
          builder: (c1, engine, _) {
            final displayEngine = provider.displayEngine;
            final isLive = !provider.isViewingHistory;
            final isMyTurn = provider.isOffline
                ? (provider.offlinePlayMode == PlayMode.localCoop
                    ? isLive
                    : (provider.myTeam == displayEngine.turn.name &&
                        !provider.isAiThinking.value &&
                        isLive))
                : (provider.myTeam == displayEngine.turn.name && isLive);

            final isLocalCoop = provider.isOffline && provider.offlinePlayMode == PlayMode.localCoop;
            final isBlackTurn = displayEngine.turn == PieceTeam.black;
            final activePlayerIsAtTop = flipBoard ? !isBlackTurn : isBlackTurn;
            final pieceRotation = isLocalCoop ? (activePlayerIsAtTop ? 0.5 : 0.0) : 0.0;

            return ValueListenableBuilder<List<KitaMove>>(
              valueListenable: provider.legalMoves,
              builder: (c2, legal, _) {
                return _BoardInteraction(
                  provider: provider,
                  displayEngine: displayEngine,
                  flipBoard: flipBoard,
                  isHorizontal: isHorizontal,
                  pieceRotation: pieceRotation,
                  isMyTurn: isMyTurn,
                  legalMoves: isLive ? legal : [],
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Handles piece selection and move interaction on the board.
class _BoardInteraction extends StatefulWidget {
  final OnlineGameProvider provider;
  final KitaGameEngine displayEngine;
  final bool flipBoard;
  final bool isHorizontal;
  final double pieceRotation;
  final bool isMyTurn;
  final List<KitaMove> legalMoves;

  const _BoardInteraction({
    required this.provider,
    required this.displayEngine,
    required this.flipBoard,
    this.isHorizontal = true,
    this.pieceRotation = 0.0,
    required this.isMyTurn,
    required this.legalMoves,
  });

  @override
  State<_BoardInteraction> createState() => _BoardInteractionState();
}

class _BoardInteractionState extends State<_BoardInteraction> {
  KitaPos? _selectedPos;
  Set<KitaPos> _validMoves = {};

  @override
  void didUpdateWidget(covariant _BoardInteraction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.displayEngine != widget.displayEngine ||
        oldWidget.isMyTurn != widget.isMyTurn ||
        oldWidget.legalMoves != widget.legalMoves) {
      if (_selectedPos != null) {
        _updateOrReselectPiece();
      }
    }
  }

  void _updateOrReselectPiece() {
    if (_selectedPos == null) return;
    final pos = _selectedPos!;
    final activePositions = widget.displayEngine.activePositions;
    String? pieceId;
    for (final entry in activePositions.entries) {
      if (entry.value == pos) {
        pieceId = entry.key;
        break;
      }
    }
    if (pieceId == null) {
      _selectedPos = null;
      _validMoves = {};
      return;
    }
    final piece = KitaPiece.allPieces[pieceId];
    if (piece == null) {
      _selectedPos = null;
      _validMoves = {};
      return;
    }

    final isOurPiece = widget.provider.isOffline
        ? (widget.provider.offlinePlayMode == PlayMode.localCoop
            ? true
            : ((widget.provider.myTeam == 'white' && piece.isWhite) ||
                (widget.provider.myTeam == 'black' && piece.isBlack)))
        : ((widget.provider.myTeam == 'white' && piece.isWhite) ||
            (widget.provider.myTeam == 'black' && piece.isBlack));

    if (!isOurPiece) {
      _selectedPos = null;
      _validMoves = {};
      return;
    }

    final Set<KitaPos> movesForPiece;
    if (widget.isMyTurn &&
        piece.team == widget.displayEngine.turn &&
        widget.legalMoves.isNotEmpty) {
      movesForPiece = widget.legalMoves
          .where((m) => m.pieceId == pieceId)
          .map((m) => m.toPos)
          .toSet();
    } else {
      movesForPiece = widget.displayEngine.getMovesForPiece(pieceId);
    }

    _selectedPos = pos;
    _validMoves = movesForPiece;
  }

  bool get _isCurrentTurnSelection {
    if (!widget.isMyTurn) return false;
    if (_selectedPos == null) return true;
    final activePositions = widget.displayEngine.activePositions;
    for (final entry in activePositions.entries) {
      if (entry.value == _selectedPos) {
        final piece = KitaPiece.allPieces[entry.key];
        return piece?.team == widget.displayEngine.turn;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final gameSettings = context.watch<GameSettingsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final boardTheme = gameSettings.currentBoardTheme(isDark);
    final canInteract = !widget.provider.isViewingHistory &&
        widget.displayEngine.getStatus() == GameStatus.ongoing;

    return KitaBoardWidget(
      pieces: widget.displayEngine.activePositions,
      selectedPos: _selectedPos,
      validMoves: _validMoves,
      flipBoard: widget.flipBoard,
      isHorizontal: widget.isHorizontal,
      pieceRotation: widget.pieceRotation,
      isCurrentTurn: _isCurrentTurnSelection,
      theme: boardTheme,
      onTileTap: canInteract ? _onTileTap : null,
      onPieceDropped: canInteract ? _onPieceDropped : null,
      onPieceDragStarted: canInteract ? _onPieceDragStarted : null,
      onPieceDragCancelled: canInteract ? _onPieceDragCancelled : null,
      isPieceDraggable: canInteract ? _isPieceDraggable : null,
    );
  }

  bool _isPieceDraggable(KitaPos pos) {
    if (!widget.isMyTurn && !widget.provider.isOffline) {
      return false;
    }
    if (widget.provider.isOffline &&
        widget.provider.offlinePlayMode != PlayMode.localCoop &&
        !widget.isMyTurn) {
      return false;
    }

    final activePositions = widget.displayEngine.activePositions;
    String? pieceId;
    for (final entry in activePositions.entries) {
      if (entry.value == pos) {
        pieceId = entry.key;
        break;
      }
    }
    if (pieceId == null) return false;
    final piece = KitaPiece.allPieces[pieceId];
    if (piece == null) return false;

    if (piece.team != widget.displayEngine.turn) {
      return false;
    }

    if (widget.provider.isOffline &&
        widget.provider.offlinePlayMode == PlayMode.localCoop) {
      return true;
    }

    return (widget.provider.myTeam == 'white' && piece.isWhite) ||
        (widget.provider.myTeam == 'black' && piece.isBlack);
  }

  void _onPieceDragStarted(KitaPos pos) {
    if (_selectedPos != pos) {
      _selectPiece(pos);
    }
  }

  void _onPieceDragCancelled(KitaPos pos) {
    setState(() {
      _selectedPos = null;
      _validMoves = {};
    });
  }

  void _onPieceDropped(KitaPos fromPos, KitaPos toPos) {
    if (fromPos == toPos) {
      return;
    }

    if (widget.isMyTurn) {
      final activePositions = widget.displayEngine.activePositions;
      String? selectedPieceId;
      for (final entry in activePositions.entries) {
        if (entry.value == fromPos) {
          selectedPieceId = entry.key;
          break;
        }
      }
      final selectedPiece = selectedPieceId != null
          ? KitaPiece.allPieces[selectedPieceId]
          : null;
      final canMove = selectedPiece != null &&
          selectedPiece.team == widget.displayEngine.turn;

      if (canMove) {
        final move = widget.legalMoves.firstWhere(
          (m) => m.fromPos == fromPos && m.toPos == toPos,
          orElse: () => KitaMove(
            pieceId: '',
            fromPos: fromPos,
            toPos: toPos,
          ),
        );

        if (move.pieceId.isNotEmpty) {
          widget.provider.makeMove(move);
        }
      }
    }

    setState(() {
      _selectedPos = null;
      _validMoves = {};
    });
  }

  void _selectPiece(KitaPos pos) {
    final activePositions = widget.displayEngine.activePositions;
    String? tappedPieceId;
    for (final entry in activePositions.entries) {
      if (entry.value == pos) {
        tappedPieceId = entry.key;
        break;
      }
    }

    if (tappedPieceId != null) {
      final piece = KitaPiece.allPieces[tappedPieceId];
      if (piece != null) {
        final isOurPiece = widget.provider.isOffline
            ? (widget.provider.offlinePlayMode == PlayMode.localCoop
                ? true
                : ((widget.provider.myTeam == 'white' && piece.isWhite) ||
                    (widget.provider.myTeam == 'black' && piece.isBlack)))
            : ((widget.provider.myTeam == 'white' && piece.isWhite) ||
                (widget.provider.myTeam == 'black' && piece.isBlack));

        if (isOurPiece) {
          final Set<KitaPos> movesForPiece;
          if (widget.isMyTurn &&
              piece.team == widget.displayEngine.turn &&
              widget.legalMoves.isNotEmpty) {
            movesForPiece = widget.legalMoves
                .where((m) => m.pieceId == tappedPieceId)
                .map((m) => m.toPos)
                .toSet();
          } else {
            // Allows player to inspect piece moves even during opponent's turn
            movesForPiece = widget.displayEngine.getMovesForPiece(tappedPieceId);
          }

          setState(() {
            _selectedPos = pos;
            _validMoves = movesForPiece;
          });
        }
      }
    }
  }

  void _onTileTap(KitaPos pos) {
    // 1. If tapping the already selected tile → deselect it
    if (_selectedPos != null && _selectedPos == pos) {
      setState(() {
        _selectedPos = null;
        _validMoves = {};
      });
      return;
    }

    // 2. If tapping a valid move destination → make the move if our turn, otherwise deselect
    if (_selectedPos != null && _validMoves.contains(pos)) {
      if (widget.isMyTurn) {
        _onPieceDropped(_selectedPos!, pos);
      } else {
        setState(() {
          _selectedPos = null;
          _validMoves = {};
        });
      }
      return;
    }

    // 3. If tapping a piece → check if it's player's piece and show valid moves
    final activePositions = widget.displayEngine.activePositions;
    final hasPiece = activePositions.values.any((p) => p == pos);
    if (hasPiece) {
      _selectPiece(pos);
      return;
    }

    // 4. Tapped empty space or opponent piece → deselect
    setState(() {
      _selectedPos = null;
      _validMoves = {};
    });
  }
}
