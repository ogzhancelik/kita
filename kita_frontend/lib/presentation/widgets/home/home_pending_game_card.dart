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
import '../../screens/game/ready_phase_screen.dart';
import '../common/countdown_circle_timer.dart';
import '../common/kita_avatar.dart';
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

  String _formatTimeControl(int ms) => TimeControlPreset.format(ms);

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
    final isRoomOpen =
        matchState == OnlineMatchState.inRoom &&
        onlineProv.currentRoomCode != null &&
        onlineProv.currentRoomCode!.isNotEmpty;
    final pendingChallenges = onlineProv.pendingOutgoingChallenges.value;
    final pendingRematch = onlineProv.pendingOutgoingRematch.value;
    final isInOnlineMatch = matchState == OnlineMatchState.inMatch;
    final isReadyPhase = matchState == OnlineMatchState.readyPhase;
    final hasActiveOnline = isInOnlineMatch;
    final hasActiveOffline = offlineProv.hasActiveMatch;
    final hasBothActive = hasActiveOnline && hasActiveOffline;

    if (hasBothActive) {
      return _buildBothActiveGamesCard(
        context,
        onlineProv,
        offlineProv,
        isDark,
      );
    }

    Widget? onlineSection;
    if (isInOnlineMatch) {
      onlineSection = _buildActiveOnlineGameCard(
        context,
        onlineProv,
        isDark,
      );
    } else if (isReadyPhase) {
      onlineSection = _buildReadyPhaseCard(
        context,
        onlineProv,
        isDark,
      );
    } else if (pendingRematch != null) {
      onlineSection = _buildPendingRematchCard(
        context,
        onlineProv,
        isDark,
        pendingRematch,
      );
    } else if (isRoomOpen) {
      onlineSection = _buildOpenRoomCard(context, onlineProv, isDark);
    } else if (pendingChallenges.isNotEmpty) {
      onlineSection = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < pendingChallenges.length; i++)
            _buildPendingChallengeCard(
              context,
              onlineProv,
              isDark,
              pendingChallenges[i],
              margin: EdgeInsets.only(
                bottom: i == pendingChallenges.length - 1 ? 12.0 : 6.0,
              ),
            ),
        ],
      );
    }

    Widget? offlineSection;
    if (offlineProv.hasActiveMatch) {
      offlineSection = _buildActiveOfflineGameCard(
        context,
        offlineProv,
        isDark,
      );
    }

    if (onlineSection != null && offlineSection != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [onlineSection, offlineSection],
      );
    } else if (onlineSection != null) {
      return onlineSection;
    } else if (offlineSection != null) {
      return offlineSection;
    }

    // Nothing pending or active -> completely invisible
    return const SizedBox.shrink();
  }

  // ─── Unified & Single Active Match Cards ─────────────────────────────

  Widget _buildBothActiveGamesCard(
    BuildContext context,
    OnlineGameProvider onlineProv,
    OfflineGameProvider offlineProv,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.accent,
            AppColors.primary,
          ],
          stops: [0.5, 0.5],
        ),
        boxShadow: [
          // Top online glow (accent)
          BoxShadow(
            color: AppColors.accent.withValues(alpha: isDark ? 0.35 : 0.22),
            blurRadius: 14,
            offset: const Offset(0, -3),
          ),
          // Bottom offline glow (primary)
          BoxShadow(
            color: AppColors.primary.withValues(alpha: isDark ? 0.40 : 0.25),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(1.5),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.getCard(isDark),
          borderRadius: BorderRadius.circular(14.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14.5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildActiveOnlineGameRow(context, onlineProv, isDark),
              Divider(
                height: 1,
                thickness: 1,
                color: AppColors.getBorder(isDark),
              ),
              _buildActiveOfflineGameRow(context, offlineProv, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveOnlineGameCard(
    BuildContext context,
    OnlineGameProvider onlineProv,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: AppColors.getCard(isDark),
        borderRadius: BorderRadius.circular(16),
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14.5),
        child: _buildActiveOnlineGameRow(context, onlineProv, isDark),
      ),
    );
  }

  Widget _buildReadyPhaseCard(
    BuildContext context,
    OnlineGameProvider onlineProv,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: AppColors.getCard(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryAmber.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryAmber.withValues(alpha: isDark ? 0.2 : 0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ReadyPhaseScreen(),
                settings: const RouteSettings(name: '/ready_phase'),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primaryAmber.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.timer_outlined,
                    color: AppColors.primaryAmber,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'online.readyPhaseTitle'.tr(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.getTextPrimary(isDark),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'online.readyPhaseSubtitle'.tr(),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.getTextSecondary(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder<int>(
                  valueListenable: onlineProv.readyCountdownSeconds,
                  builder: (context, countdown, _) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.primaryAmber,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${countdown}s',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveOfflineGameCard(
    BuildContext context,
    OfflineGameProvider offlineProv,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: AppColors.getCard(isDark),
        borderRadius: BorderRadius.circular(16),
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14.5),
        child: _buildActiveOfflineGameRow(context, offlineProv, isDark),
      ),
    );
  }

  // ─── 1. Active Online Game Row ───────────────────────────────────────

  Widget _buildActiveOnlineGameRow(
    BuildContext context,
    OnlineGameProvider onlineProv,
    bool isDark,
  ) {
    final opponentName =
        onlineProv.opponentInfo?.name ?? 'online.opponent'.tr();
    final oppInfo = onlineProv.opponentInfo;
    final isOpponentGuest = (oppInfo != null &&
            (oppInfo.id.startsWith('guest_') ||
                oppInfo.id.startsWith('guest-'))) ||
        opponentName.toLowerCase().startsWith('guest');

    return Dismissible(
      key: ValueKey('active_online_game_${onlineProv.matchId ?? "current"}'),
      direction: DismissDirection.horizontal,
      confirmDismiss: (_) => _confirmResignDialog(context, isDark),
      onDismissed: (_) {
        onlineProv.resignAndClear();
      },
      background: _buildDismissibleBackground(
        label: 'dashboard.pendingSection.resign'.tr(),
        icon: Icons.flag_rounded,
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: _buildDismissibleBackground(
        label: 'dashboard.pendingSection.resign'.tr(),
        icon: Icons.flag_rounded,
        alignment: Alignment.centerRight,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _rejoinOnlineGame(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Opponent User Avatar
                KitaAvatar(
                  avatarIndex: oppInfo?.avatarIndex ?? 0,
                  avatarCustom: oppInfo?.avatarCustom,
                  isGuest: isOpponentGuest,
                  size: 42,
                ),
                const SizedBox(width: 12),

                // Game Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Top Line: NAME / ELO
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: (isOpponentGuest
                                      ? AppColors.guestOrange
                                      : AppColors.getRatingGold(isDark))
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isOpponentGuest
                                      ? Icons.person_outline_rounded
                                      : Icons.emoji_events_rounded,
                                  size: 11,
                                  color: isOpponentGuest
                                      ? AppColors.guestOrange
                                      : AppColors.getRatingGold(isDark),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  isOpponentGuest
                                      ? 'guest.badge'.tr()
                                      : (oppInfo?.displayRating ?? '1200'),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isOpponentGuest
                                        ? AppColors.guestOrange
                                        : AppColors.getRatingGold(isDark),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Bottom Line: TURN / time remaining
                      ValueListenableBuilder<String>(
                        valueListenable: onlineProv.currentTurn,
                        builder: (context, currentTurn, _) {
                          final isMyTurn = currentTurn == onlineProv.myTeam;
                          final activeClock = currentTurn == 'white'
                              ? onlineProv.whiteRemainingMs
                              : onlineProv.blackRemainingMs;

                          return ValueListenableBuilder<int>(
                            valueListenable: activeClock,
                            builder: (context, ms, _) {
                              final String timeStr;
                              if (onlineProv.timeControl <= 0) {
                                timeStr = _formatTimeControl(0);
                              } else if (ms > 0) {
                                final totalSec = (ms / 1000).ceil();
                                final mins = totalSec ~/ 60;
                                final secs = totalSec % 60;
                                timeStr = '$mins:${secs.toString().padLeft(2, '0')}';
                              } else {
                                timeStr = _formatTimeControl(onlineProv.timeControl);
                              }

                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isMyTurn
                                          ? AppColors.getAccentGold(isDark)
                                          : AppColors.getTextMuted(isDark),
                                      boxShadow: isMyTurn
                                          ? [
                                              BoxShadow(
                                                color: AppColors.getAccentGold(
                                                        isDark)
                                                    .withValues(alpha: 0.6),
                                                blurRadius: 4,
                                                spreadRadius: 0.5,
                                              ),
                                            ]
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      isMyTurn
                                          ? 'dashboard.pendingSection.yourTurn'
                                                .tr()
                                          : 'dashboard.pendingSection.opponentTurn'
                                                .tr(),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isMyTurn
                                            ? AppColors.getAccentGold(isDark)
                                            : AppColors.getTextMuted(isDark),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '•',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.getTextMuted(isDark),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.schedule_rounded,
                                    size: 11,
                                    color: AppColors.getTextSecondary(isDark),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    timeStr,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.getTextSecondary(isDark),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // Right: Play / Join Gamepad button
                _buildPlayButton(isOnline: true),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── 1.5 Active Offline Game Row ─────────────────────────────────────

  Widget _buildActiveOfflineGameRow(
    BuildContext context,
    OfflineGameProvider offlineProv,
    bool isDark,
  ) {
    final isBot = offlineProv.offlinePlayMode == PlayMode.vsAi;
    final isLocalCoop = offlineProv.offlinePlayMode == PlayMode.localCoop;
    final opponentName = isLocalCoop
        ? (offlineProv.opponentInfo?.name ?? 'game.localCoop'.tr())
        : 'game.aiBot'.tr();

    return Dismissible(
      key: ValueKey('active_offline_game_${offlineProv.matchId ?? "current"}'),
      direction: DismissDirection.horizontal,
      confirmDismiss: (_) => _confirmResignDialog(context, isDark),
      onDismissed: (_) {
        offlineProv.resignAndClear();
      },
      background: _buildDismissibleBackground(
        label: 'dashboard.pendingSection.resign'.tr(),
        icon: Icons.flag_rounded,
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: _buildDismissibleBackground(
        label: 'dashboard.pendingSection.resign'.tr(),
        icon: Icons.flag_rounded,
        alignment: Alignment.centerRight,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _rejoinOfflineGame(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Bot / Coop Icon Avatar
                if (isBot)
                  const KitaAvatar(
                    avatarIndex: 0,
                    isBot: true,
                    size: 42,
                  )
                else
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primaryLight,
                        width: 2.0,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.people_alt_rounded,
                        color: AppColors.primaryLight,
                        size: 22,
                      ),
                    ),
                  ),
                const SizedBox(width: 12),

                // Game Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Top Line: Mode Name & Bot Difficulty (no 2P badge for Local Coop)
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
                          if (isBot) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryAmber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                offlineProv.offlineBotDifficultyLabel,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryAmber,
                                ),
                              ),
                            ),
                          ] else if (isLocalCoop) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'game.localCoop'.tr(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.accent,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Bottom Line: Elapsed match time (turn removed)
                      ValueListenableBuilder<int>(
                        valueListenable: offlineProv.elapsedSeconds,
                        builder: (context, totalSec, _) {
                          final mins = totalSec ~/ 60;
                          final secs = totalSec % 60;
                          final timeStr = '$mins:${secs.toString().padLeft(2, '0')}';

                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 11,
                                color: AppColors.getTextSecondary(isDark),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                timeStr,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.getTextSecondary(isDark),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // Right: Play / Join Gamepad button
                _buildPlayButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayButton({bool isOnline = false}) {
    final bgColor = isOnline ? AppColors.accent : AppColors.primaryAmber;
    final iconColor = isOnline ? AppColors.turnActiveCardDark : Colors.white;

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: bgColor.withValues(alpha: isOnline ? 0.45 : 0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.sports_esports_rounded,
          color: iconColor,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildDismissibleBackground({
    required String label,
    required IconData icon,
    required Alignment alignment,
  }) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: AppColors.lossRed.withValues(alpha: 0.15),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (alignment == Alignment.centerLeft) ...[
            Icon(icon, color: AppColors.lossRed, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.lossRed,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ] else ...[
            Text(
              label,
              style: const TextStyle(
                color: AppColors.lossRed,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 8),
            Icon(icon, color: AppColors.lossRed, size: 20),
          ],
        ],
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
              color: AppColors.getAccentGold(isDark).withValues(alpha: 0.5),
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
                  color: AppColors.getAccentGold(isDark).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.meeting_room_rounded,
                    color: AppColors.getAccentGold(isDark),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.getAccentGold(isDark)
                                .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'dashboard.pendingSection.openRoomTitle'
                                .tr()
                                .toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.getAccentGold(isDark),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.getAccentGold(isDark),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.getAccentGold(isDark)
                                    .withValues(alpha: 0.5),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.getSurface(isDark),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: AppColors.getBorder(isDark),
                            ),
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
                color: AppColors.getAccentGold(isDark),
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
      key: ValueKey(
        'rematch_${rematch.matchId}_${rematch.sentAt.millisecondsSinceEpoch}',
      ),
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
                rematch.opponentName.isNotEmpty
                    ? rematch.opponentName[0].toUpperCase()
                    : '?',
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.winBlue.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'dashboard.pendingSection.pendingRematchTitle'
                              .tr()
                              .toUpperCase(),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.getRatingGold(isDark)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '★ ${rematch.opponentRating}${rematch.opponentIsProvisional == true ? "?" : ""}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.getRatingGold(isDark),
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
    PendingOutgoingChallenge challenge, {
    BorderRadiusGeometry borderRadius = const BorderRadius.all(
      Radius.circular(16),
    ),
    EdgeInsetsGeometry margin = const EdgeInsets.only(bottom: 12.0),
  }) {
    final tcStr = _formatTimeControl(challenge.timeControl);

    return _buildDismissibleContainer(
      key: ValueKey(
        'challenge_${challenge.friendId}_${challenge.inviteId ?? challenge.sentAt.millisecondsSinceEpoch}',
      ),
      dismissLabel: 'dashboard.pendingSection.cancelInvite'.tr(),
      dismissIcon: Icons.cancel_schedule_send_rounded,
      onDismissed: () {
        onlineProv.cancelOutgoingChallenge(
          friendId: challenge.friendId,
          inviteId: challenge.inviteId,
        );
      },
      borderRadius: borderRadius,
      margin: margin,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.getCard(isDark),
          borderRadius: borderRadius,
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
                challenge.friendName.isNotEmpty
                    ? challenge.friendName[0].toUpperCase()
                    : '?',
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentSecondary.withValues(
                            alpha: 0.2,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'dashboard.pendingSection.pendingChallengeTitle'
                              .tr()
                              .toUpperCase(),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.getRatingGold(isDark)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '★ ${challenge.friendRating}${challenge.friendIsProvisional == true ? "?" : ""}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.getRatingGold(isDark),
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

            // Countdown timer circle that runs out
            CountdownCircleTimer(
              startTime: challenge.sentAt,
              expiresAt: challenge.expiresAt,
              totalDuration: challenge.expiresAt != null
                  ? challenge.expiresAt!.difference(challenge.sentAt)
                  : const Duration(hours: 24),
              size: 22,
              strokeWidth: 2.4,
              color: AppColors.accentSecondary,
              onTimeout: () {
                onlineProv.cancelOutgoingChallenge(
                  friendId: challenge.friendId,
                  inviteId: challenge.inviteId,
                );
              },
            ),

            const SizedBox(width: 4),

            // Cancel action button
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              color: AppColors.lossRed,
              tooltip: 'dashboard.pendingSection.cancelInvite'.tr(),
              onPressed: () {
                onlineProv.cancelOutgoingChallenge(
                  friendId: challenge.friendId,
                  inviteId: challenge.inviteId,
                );
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
    BorderRadiusGeometry borderRadius = const BorderRadius.all(
      Radius.circular(16),
    ),
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
