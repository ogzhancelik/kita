import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/game_models.dart';
import '../../../data/models/ws_message_models.dart';
import '../../providers/offline_game_provider.dart';
import '../../providers/online_game_provider.dart';
import '../../screens/game/offline_match_screen.dart';
import '../../screens/game/online_match_screen.dart';
import '../room/room_dialog.dart';

/// Single-item priority card displayed directly above the notifications section.
///
/// Contains mutually exclusive states:
/// 1. Active game (online match or offline AI/local in progress) -> quick Rejoin or swipe to resign.
/// 2. Open room (host waiting for opponent) -> room code/details, tap to view/copy, swipe to cancel.
/// 3. Pending friend challenge -> outgoing match invitation, swipe to cancel.
///
/// If none of the 3 exist, it renders invisible ([SizedBox.shrink]).
class HomePendingGameCard extends StatelessWidget {
  const HomePendingGameCard({super.key});

  String _formatTimeControl(int ms) {
    if (ms <= 0) return 'online.timeUnlimited'.tr();
    if (ms == TimeControlPreset.oneMin) return 'online.timeBullet'.tr();
    if (ms == TimeControlPreset.threeMin) return 'online.timeBlitz'.tr();
    if (ms == TimeControlPreset.fiveMin) return 'online.timeRapid'.tr();
    final mins = ms ~/ 60000;
    return 'online.minuteShort'.tr(args: ['$mins']);
  }

  void _rejoinOnlineGame(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const OnlineMatchScreen(),
        settings: const RouteSettings(name: '/online_match'),
      ),
    );
  }

  void _rejoinOfflineGame(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const OfflineMatchScreen(),
        settings: const RouteSettings(name: '/offline_match'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onlineProv = context.watch<OnlineGameProvider>();
    final offlineProv = context.watch<OfflineGameProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final matchState = onlineProv.matchState.value;
    final isRoomOpen = matchState == OnlineMatchState.inRoom &&
        onlineProv.currentRoomCode != null &&
        onlineProv.currentRoomCode!.isNotEmpty;
    final pendingChallenge = onlineProv.pendingOutgoingChallenge.value;
    final pendingRematch = onlineProv.pendingOutgoingRematch.value;
    final isInOnlineMatch = matchState == OnlineMatchState.inMatch;
    final hasActiveOnline = isInOnlineMatch;
    final hasActiveOffline = offlineProv.hasActiveMatch;
    final hasBothActive = hasActiveOnline && hasActiveOffline;

    Widget? onlineSection;
    if (isInOnlineMatch) {
      onlineSection = _buildActiveOnlineGameCard(
        context,
        onlineProv,
        isDark,
        borderRadius: hasBothActive
            ? const BorderRadius.vertical(top: Radius.circular(16))
            : BorderRadius.circular(16),
        margin: hasBothActive ? EdgeInsets.zero : const EdgeInsets.only(bottom: 12.0),
      );
    } else if (pendingRematch != null) {
      onlineSection = _buildPendingRematchCard(context, onlineProv, isDark, pendingRematch);
    } else if (isRoomOpen) {
      onlineSection = _buildOpenRoomCard(context, onlineProv, isDark);
    } else if (pendingChallenge != null) {
      onlineSection = _buildPendingChallengeCard(context, onlineProv, isDark, pendingChallenge);
    }

    Widget? offlineSection;
    if (offlineProv.hasActiveMatch) {
      offlineSection = _buildActiveOfflineGameCard(
        context,
        offlineProv,
        isDark,
        borderRadius: hasBothActive
            ? const BorderRadius.vertical(bottom: Radius.circular(16))
            : BorderRadius.circular(16),
        margin: const EdgeInsets.only(bottom: 12.0),
      );
    }

    if (onlineSection != null && offlineSection != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          onlineSection,
          offlineSection,
        ],
      );
    } else if (onlineSection != null) {
      return onlineSection;
    } else if (offlineSection != null) {
      return offlineSection;
    }

    // Nothing pending or active -> completely invisible
    return const SizedBox.shrink();
  }

  // ─── 1. Active Online Game Card ──────────────────────────────────────

  Widget _buildActiveOnlineGameCard(
    BuildContext context,
    OnlineGameProvider onlineProv,
    bool isDark, {
    BorderRadiusGeometry borderRadius = const BorderRadius.all(Radius.circular(16)),
    EdgeInsetsGeometry margin = const EdgeInsets.only(bottom: 12.0),
  }) {
    final opponentName = onlineProv.opponentInfo?.name ?? 'online.opponent'.tr();
    final opponentRating = onlineProv.opponentInfo?.rating ?? 1200;
    final badgeLabel = '★ $opponentRating';
    final isMyTurn = (onlineProv.currentTurn.value == onlineProv.myTeam);
    final tcStr = _formatTimeControl(onlineProv.timeControl);

    return _buildDismissibleContainer(
      key: ValueKey('active_online_game_${onlineProv.matchId ?? "current"}'),
      dismissLabel: 'dashboard.pendingSection.resign'.tr(),
      dismissIcon: Icons.flag_rounded,
      confirmDismiss: () => _confirmResignDialog(context, isDark),
      onDismissed: () {
        onlineProv.resignAndClear();
      },
      borderRadius: borderRadius,
      margin: margin,
      child: InkWell(
        onTap: () => _rejoinOnlineGame(context),
        borderRadius: borderRadius is BorderRadius ? borderRadius : BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.getCard(isDark),
            borderRadius: borderRadius,
            border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: isDark ? 0.2 : 0.1),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.sports_esports_rounded,
                    color: isDark ? AppColors.accent : AppColors.accentSecondary,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Game Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'dashboard.pendingSection.activeGameTitle'.tr().toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF143026),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            isMyTurn
                                ? 'dashboard.pendingSection.yourTurn'.tr()
                                : 'dashboard.pendingSection.opponentTurn'.tr(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isMyTurn ? AppColors.accentGold : AppColors.getTextMuted(isDark),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            opponentName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.getTextPrimary(isDark),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.ratingGold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badgeLabel,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.ratingGold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Right: Time Control badge & Rejoin Button
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(6),
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
                          size: 11,
                          color: AppColors.getTextSecondary(isDark),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          tcStr,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.getTextSecondary(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'dashboard.pendingSection.rejoin'.tr(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── 1.5 Active Offline Game Card ────────────────────────────────────

  Widget _buildActiveOfflineGameCard(
    BuildContext context,
    OfflineGameProvider offlineProv,
    bool isDark, {
    BorderRadiusGeometry borderRadius = const BorderRadius.all(Radius.circular(16)),
    EdgeInsetsGeometry margin = const EdgeInsets.only(bottom: 12.0),
  }) {
    final isBot = offlineProv.offlinePlayMode == PlayMode.vsAi;
    final isLocalCoop = offlineProv.offlinePlayMode == PlayMode.localCoop;

    final opponentName = isLocalCoop
        ? 'game.player2'.tr()
        : (offlineProv.opponentInfo?.name ?? 'game.aiBot'.tr());

    final badgeLabel = isBot ? offlineProv.offlineBotDifficultyLabel : '2P';

    final isMyTurn = isLocalCoop
        ? (offlineProv.currentTurn.value == 'white' ? 'game.playWhite'.tr() : 'game.playBlack'.tr())
        : (offlineProv.currentTurn.value == offlineProv.myTeam
            ? 'dashboard.pendingSection.yourTurn'.tr()
            : 'dashboard.pendingSection.opponentTurn'.tr());

    return _buildDismissibleContainer(
      key: ValueKey('active_offline_game_${offlineProv.matchId ?? "current"}'),
      dismissLabel: 'dashboard.pendingSection.resign'.tr(),
      dismissIcon: Icons.flag_rounded,
      confirmDismiss: () => _confirmResignDialog(context, isDark),
      onDismissed: () {
        offlineProv.resignAndClear();
      },
      borderRadius: borderRadius,
      margin: margin,
      child: InkWell(
        onTap: () => _rejoinOfflineGame(context),
        borderRadius: borderRadius is BorderRadius ? borderRadius : BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.getCard(isDark),
            borderRadius: borderRadius,
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    isBot ? Icons.smart_toy_rounded : Icons.people_outline_rounded,
                    color: AppColors.primaryLight,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Game Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'dashboard.pendingSection.activeGameTitle'.tr().toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            isMyTurn,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isLocalCoop
                                  ? AppColors.getTextPrimary(isDark)
                                  : (offlineProv.currentTurn.value == offlineProv.myTeam
                                      ? AppColors.accentGold
                                      : AppColors.getTextMuted(isDark)),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            opponentName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.getTextPrimary(isDark),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.ratingGold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badgeLabel,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.ratingGold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Right: Offline label & Rejoin Button
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppColors.getBorder(isDark),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.devices_rounded,
                          size: 11,
                          color: AppColors.getTextSecondary(isDark),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'dashboard.badgeOffline'.tr(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.getTextSecondary(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'dashboard.pendingSection.rejoin'.tr(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── 2. Open Room Card ───────────────────────────────────────────────

  Widget _buildOpenRoomCard(
    BuildContext context,
    OnlineGameProvider onlineProv,
    bool isDark,
  ) {
    final code = onlineProv.currentRoomCode ?? '';
    final tcStr = _formatTimeControl(onlineProv.roomTimeControl);

    return _buildDismissibleContainer(
      key: ValueKey('open_room_$code'),
      dismissLabel: 'dashboard.pendingSection.cancelRoom'.tr(),
      dismissIcon: Icons.close_rounded,
      onDismissed: () {
        onlineProv.leaveRoom();
      },
      child: InkWell(
        onTap: () {
          // Re-open Create Room dialog to view full waiting room
          CreateRoomDialog.show(context);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.getCard(isDark),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.accentGold.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              // Room icon badge
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.accentGold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.meeting_room_rounded,
                    color: AppColors.accentGold,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Room Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accentGold.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'dashboard.pendingSection.openRoomTitle'.tr().toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.accentGold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'dashboard.pendingSection.waitingForOpponent'.tr(),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.getTextSecondary(isDark),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '#$code',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                            color: AppColors.getTextPrimary(isDark),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.getSurface(isDark),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.getBorder(isDark)),
                          ),
                          child: Text(
                            tcStr,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.getTextSecondary(isDark),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Copy Code Quick Action
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 20),
                color: AppColors.accentGold,
                tooltip: 'online.codeCopied'.tr(),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('online.codeCopied'.tr()),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── 2. Pending Rematch Card ────────────────────────────────────────

  Widget _buildPendingRematchCard(
    BuildContext context,
    OnlineGameProvider onlineProv,
    bool isDark,
    PendingOutgoingRematch rematch,
  ) {
    final tcStr = _formatTimeControl(rematch.timeControl);

    return _buildDismissibleContainer(
      key: ValueKey('rematch_${rematch.matchId}_${rematch.sentAt.millisecondsSinceEpoch}'),
      dismissLabel: 'dashboard.pendingSection.cancelRematch'.tr(),
      dismissIcon: Icons.cancel_schedule_send_rounded,
      onDismissed: () {
        onlineProv.cancelRematchRequest();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.getCard(isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.winBlue.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Outgoing rematch avatar
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.winBlue.withValues(alpha: 0.2),
              child: Text(
                rematch.opponentName.isNotEmpty ? rematch.opponentName[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.winBlue,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Rematch Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.winBlue.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'dashboard.pendingSection.pendingRematchTitle'.tr().toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.winBlue,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          rematch.opponentName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.getTextPrimary(isDark),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (rematch.opponentRating != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.ratingGold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '★ ${rematch.opponentRating}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.ratingGold,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Text(
                        '• $tcStr',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.getTextMuted(isDark),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Cancel action button
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              color: AppColors.lossRed,
              tooltip: 'dashboard.pendingSection.cancelRematch'.tr(),
              onPressed: () {
                onlineProv.cancelRematchRequest();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─── 3. Pending Friend Challenge Card ────────────────────────────────

  Widget _buildPendingChallengeCard(
    BuildContext context,
    OnlineGameProvider onlineProv,
    bool isDark,
    PendingOutgoingChallenge challenge,
  ) {
    final tcStr = _formatTimeControl(challenge.timeControl);

    return _buildDismissibleContainer(
      key: ValueKey('challenge_${challenge.friendId}_${challenge.sentAt.millisecondsSinceEpoch}'),
      dismissLabel: 'dashboard.pendingSection.cancelInvite'.tr(),
      dismissIcon: Icons.cancel_schedule_send_rounded,
      onDismissed: () {
        onlineProv.cancelOutgoingChallenge();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.getCard(isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.accentSecondary.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Outgoing challenge avatar
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.accentSecondary.withValues(alpha: 0.2),
              child: Text(
                challenge.friendName.isNotEmpty ? challenge.friendName[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.accentSecondary,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Challenge Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accentSecondary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'dashboard.pendingSection.pendingChallengeTitle'.tr().toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.accentSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          challenge.friendName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.getTextPrimary(isDark),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (challenge.friendRating != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.ratingGold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '★ ${challenge.friendRating}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.ratingGold,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Text(
                        '• $tcStr',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.getTextMuted(isDark),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Cancel action button
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              color: AppColors.lossRed,
              tooltip: 'dashboard.pendingSection.cancelInvite'.tr(),
              onPressed: () {
                onlineProv.cancelOutgoingChallenge();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmResignDialog(BuildContext context, bool isDark) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.getCard(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'dashboard.pendingSection.resignDialogTitle'.tr(),
          style: TextStyle(
            color: AppColors.getTextPrimary(isDark),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'dashboard.pendingSection.resignDialogDesc'.tr(),
          style: TextStyle(color: AppColors.getTextSecondary(isDark)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'common.cancel'.tr(),
              style: TextStyle(color: AppColors.getTextSecondary(isDark)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.lossRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('dashboard.pendingSection.resign'.tr()),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ─── Swipe-to-Cancel Dismissible Container ───────────────────────────

  Widget _buildDismissibleContainer({
    required Key key,
    required String dismissLabel,
    required IconData dismissIcon,
    required VoidCallback onDismissed,
    Future<bool?> Function()? confirmDismiss,
    required Widget child,
    BorderRadiusGeometry borderRadius = const BorderRadius.all(Radius.circular(16)),
    EdgeInsetsGeometry margin = const EdgeInsets.only(bottom: 12.0),
  }) {
    return Container(
      margin: margin,
      child: Dismissible(
        key: key,
        direction: DismissDirection.horizontal,
        confirmDismiss: confirmDismiss != null ? (_) => confirmDismiss() : null,
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: AppColors.lossRed.withValues(alpha: 0.15),
            borderRadius: borderRadius,
          ),
          child: Row(
            children: [
              Icon(dismissIcon, color: AppColors.lossRed, size: 20),
              const SizedBox(width: 8),
              Text(
                dismissLabel,
                style: const TextStyle(
                  color: AppColors.lossRed,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        secondaryBackground: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: AppColors.lossRed.withValues(alpha: 0.15),
            borderRadius: borderRadius,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                dismissLabel,
                style: const TextStyle(
                  color: AppColors.lossRed,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
              Icon(dismissIcon, color: AppColors.lossRed, size: 20),
            ],
          ),
        ),
        onDismissed: (_) => onDismissed(),
        child: child,
      ),
    );
  }
}
