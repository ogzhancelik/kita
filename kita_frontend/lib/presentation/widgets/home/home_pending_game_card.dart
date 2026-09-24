import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/ws_message_models.dart';
import '../../providers/online_game_provider.dart';
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
    return '$mins min';
  }

  void _rejoinGame(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const OnlineMatchScreen(),
        settings: const RouteSettings(name: '/online_match'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onlineProv = context.watch<OnlineGameProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final matchState = onlineProv.matchState.value;
    final isRoomOpen = matchState == OnlineMatchState.inRoom &&
        onlineProv.currentRoomCode != null &&
        onlineProv.currentRoomCode!.isNotEmpty;
    final pendingChallenge = onlineProv.pendingOutgoingChallenge.value;
    final isInMatch = matchState == OnlineMatchState.inMatch;

    // Mutually exclusive priority check
    if (isInMatch) {
      return _buildActiveGameCard(context, onlineProv, isDark);
    } else if (isRoomOpen) {
      return _buildOpenRoomCard(context, onlineProv, isDark);
    } else if (pendingChallenge != null) {
      return _buildPendingChallengeCard(context, onlineProv, isDark, pendingChallenge);
    }

    // Nothing pending or active -> completely invisible
    return const SizedBox.shrink();
  }

  // ─── 1. Active Game Card ─────────────────────────────────────────────

  Widget _buildActiveGameCard(
    BuildContext context,
    OnlineGameProvider onlineProv,
    bool isDark,
  ) {
    final opponentName = onlineProv.isOffline
        ? (onlineProv.offlinePlayMode == PlayMode.localCoop
            ? 'game.player2'.tr()
            : (onlineProv.opponentInfo?.name ?? 'game.aiBot'.tr()))
        : (onlineProv.opponentInfo?.name ?? 'online.opponent'.tr());

    final opponentRating = onlineProv.opponentInfo?.rating ?? 1200;
    final isMyTurn = onlineProv.isOffline
        ? true
        : (onlineProv.currentTurn.value == onlineProv.myTeam);

    final tcStr = _formatTimeControl(onlineProv.timeControl);

    return _buildDismissibleContainer(
      key: ValueKey('active_game_${onlineProv.matchId}'),
      dismissLabel: 'dashboard.pendingSection.resign'.tr(),
      dismissIcon: Icons.flag_rounded,
      onDismissed: () {
        onlineProv.resign();
      },
      child: InkWell(
        onTap: () => _rejoinGame(context),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
          child: Row(
            children: [
              // Pulsing green/primary game controller indicator
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.sports_esports_rounded,
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
                        Text(
                          isMyTurn
                              ? 'dashboard.pendingSection.yourTurn'.tr()
                              : 'dashboard.pendingSection.opponentTurn'.tr(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isMyTurn ? AppColors.accentGold : AppColors.getTextMuted(isDark),
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
                        if (!onlineProv.isOffline) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.ratingGold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '★ $opponentRating',
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

              // Rejoin Action Button
              ElevatedButton.icon(
                onPressed: () => _rejoinGame(context),
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: Text(
                  'dashboard.pendingSection.rejoin'.tr(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 2,
                ),
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
                      const SizedBox(width: 8),
                      Text(
                        'dashboard.pendingSection.waitingResponse'.tr(),
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

  // ─── Swipe-to-Cancel Dismissible Container ───────────────────────────

  Widget _buildDismissibleContainer({
    required Key key,
    required String dismissLabel,
    required IconData dismissIcon,
    required VoidCallback onDismissed,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: Dismissible(
        key: key,
        direction: DismissDirection.horizontal,
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: AppColors.lossRed.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
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
            borderRadius: BorderRadius.circular(16),
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
