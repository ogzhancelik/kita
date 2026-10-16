import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/feedback/haptic_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/user_presence_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/online_game_provider.dart';
import '../../widgets/common/avatar_picker.dart';
import 'online_match_screen.dart';

/// Dedicated screen for the pre-game "Ready" confirmation phase.
/// Both players confirm readiness before the clock begins.
class ReadyPhaseScreen extends StatefulWidget {
  static bool isReadyPhaseScreenOpen = false;

  const ReadyPhaseScreen({super.key});

  @override
  State<ReadyPhaseScreen> createState() => _ReadyPhaseScreenState();
}

class _ReadyPhaseScreenState extends State<ReadyPhaseScreen> {
  OnlineGameProvider? _provider;

  @override
  void initState() {
    super.initState();
    ReadyPhaseScreen.isReadyPhaseScreenOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final prov = context.read<OnlineGameProvider>();
        if (!prov.myReadyState.value && !UserPresenceService.instance.isAfk) {
          prov.confirmReady();
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final prov = context.read<OnlineGameProvider>();
    if (_provider != prov) {
      _provider?.matchState.removeListener(_onMatchStateChanged);
      _provider = prov;
      _provider?.matchState.addListener(_onMatchStateChanged);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !prov.myReadyState.value && !UserPresenceService.instance.isAfk) {
        prov.confirmReady();
      }
    });
  }

  @override
  void dispose() {
    ReadyPhaseScreen.isReadyPhaseScreenOpen = false;
    _provider?.matchState.removeListener(_onMatchStateChanged);
    super.dispose();
  }

  void _onMatchStateChanged() {
    if (!mounted) return;
    final state = _provider?.matchState.value;

    if (state == OnlineMatchState.inMatch) {
      if (!OnlineMatchScreen.isMatchScreenOpen) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const OnlineMatchScreen(),
            settings: const RouteSettings(name: '/online_match'),
          ),
        );
      } else {
        Navigator.of(context).pop();
      }
    } else if (state == OnlineMatchState.inRoom || state == OnlineMatchState.idle) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }

  String _formatTimeControl(int ms) {
    if (ms <= 0) return 'online.roomBadgeNoClock'.tr();
    final minutes = ms ~/ 60000;
    return 'online.timeMinutes'.tr(args: ['$minutes']);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OnlineGameProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProv = context.watch<AuthProvider>();

    final myReady = provider.myReadyState.value;
    final opponentReady = provider.opponentReadyState.value;
    final isHostOnline = provider.isHostOnline.value;
    final bothReady = myReady && opponentReady;

    final myTeam = provider.myTeam ?? 'white';
    final opponentTeam = myTeam == 'white' ? 'black' : 'white';
    final oppInfo = provider.opponentInfo;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _confirmLeave(context, provider);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.getBackground(isDark),
        appBar: AppBar(
          backgroundColor: AppColors.getSurface(isDark),
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.close_rounded,
              color: AppColors.getTextSecondary(isDark),
            ),
            tooltip: 'online.leaveReadyPhase'.tr(),
            onPressed: () => _confirmLeave(context, provider),
          ),
          centerTitle: true,
          title: Text(
            'online.readyPhaseTitle'.tr(),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.getTextPrimary(isDark),
            ),
          ),
          actions: [
            if (provider.currentRoomCode != null && provider.currentRoomCode!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: provider.currentRoomCode!));
                      HapticService.instance.light();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('online.codeCopied'.tr()),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.getCard(isDark),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.getBorder(isDark)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.tag_rounded, size: 14, color: AppColors.primaryAmber),
                          const SizedBox(width: 4),
                          Text(
                            provider.currentRoomCode!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.getTextPrimary(isDark),
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Top: Time control & Status chip
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primaryAmber.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.primaryAmber.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.timer_outlined, size: 15, color: AppColors.primaryAmber),
                                const SizedBox(width: 6),
                                Text(
                                  _formatTimeControl(provider.timeControl),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryAmber,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Countdown Visualizer Ring
                          ValueListenableBuilder<int>(
                            valueListenable: provider.readyCountdownSeconds,
                            builder: (context, countdown, _) {
                              return _buildCountdownBadge(
                                countdown: countdown,
                                bothReady: bothReady,
                                isDark: isDark,
                              );
                            },
                          ),
                          const SizedBox(height: 12),

                          // Status text
                          Text(
                            bothReady
                                ? 'online.bothPlayersReady'.tr()
                                : (!isHostOnline
                                    ? 'online.hostWaitingReturn'.tr()
                                    : 'online.readyPhaseSubtitle'.tr()),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: bothReady
                                  ? AppColors.winGreen
                                  : (!isHostOnline
                                      ? AppColors.primaryAmber
                                      : AppColors.getTextSecondary(isDark)),
                              fontWeight: bothReady ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Middle: Head-to-Head Player Cards
                      Column(
                        children: [
                          // 1. My Card (User)
                          _buildPlayerCard(
                            isUser: true,
                            name: authProv.currentUser?.username ?? 'online.readyPhaseYou'.tr(),
                            rating: authProv.currentUser?.rating ?? 1200,
                            isProvisional: authProv.currentUser?.isProvisional ?? false,
                            team: myTeam,
                            avatarIdx: authProv.avatarIndex,
                            avatarCustom: authProv.avatarCustom,
                            isReady: myReady,
                            isOnline: true,
                            isDark: isDark,
                            onReadyPressed: () {
                              UserPresenceService.instance.recordActivity();
                              provider.confirmReady();
                            },
                          ),

                          const SizedBox(height: 12),

                          // VS Divider with Accent
                          Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: AppColors.getBorder(isDark),
                                  thickness: 1,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.getSurface(isDark),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.getBorder(isDark)),
                                  ),
                                  child: Text(
                                    'VS',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.getTextSecondary(isDark),
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: AppColors.getBorder(isDark),
                                  thickness: 1,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // 2. Opponent Card
                          _buildPlayerCard(
                            isUser: false,
                            name: oppInfo?.name ?? 'online.readyPhaseChallenger'.tr(),
                            rating: oppInfo?.rating ?? 1200,
                            isProvisional: oppInfo?.isProvisional ?? false,
                            team: opponentTeam,
                            avatarIdx: oppInfo?.avatarIndex ?? 0,
                            avatarCustom: oppInfo?.avatarCustom,
                            isReady: opponentReady,
                            isOnline: isHostOnline,
                            isDark: isDark,
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Bottom: Action Buttons
                      Column(
                        children: [
                          if (!myReady)
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  UserPresenceService.instance.recordActivity();
                                  provider.confirmReady();
                                },
                                icon: const Icon(Icons.check_circle_rounded, size: 22),
                                label: Text(
                                  'online.imReady'.tr(),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.winGreen,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 3,
                                  shadowColor: AppColors.winGreen.withValues(alpha: 0.4),
                                ),
                              ),
                            )
                          else
                            Container(
                              width: double.infinity,
                              height: 52,
                              decoration: BoxDecoration(
                                color: AppColors.winGreen.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.winGreen.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      color: AppColors.winGreen,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      bothReady
                                          ? 'online.bothPlayersReady'.tr()
                                          : 'online.waitingForOpponentReady'.tr(),
                                      style: const TextStyle(
                                        color: AppColors.winGreen,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          const SizedBox(height: 12),

                          TextButton.icon(
                            onPressed: () => _confirmLeave(context, provider),
                            icon: const Icon(
                              Icons.exit_to_app_rounded,
                              size: 16,
                              color: AppColors.lossRed,
                            ),
                            label: Text(
                              'online.leaveReadyPhase'.tr(),
                              style: const TextStyle(
                                color: AppColors.lossRed,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCountdownBadge({
    required int countdown,
    required bool bothReady,
    required bool isDark,
  }) {
    final progress = (countdown / 60.0).clamp(0.0, 1.0);
    final color = bothReady
        ? AppColors.winGreen
        : (countdown <= 10 ? AppColors.lossRed : AppColors.primaryAmber);

    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 78,
          height: 78,
          child: CircularProgressIndicator(
            value: bothReady ? 1.0 : progress,
            strokeWidth: 4.5,
            backgroundColor: AppColors.getBorder(isDark),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.getCard(isDark),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.2),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Center(
            child: bothReady
                ? const Icon(Icons.check_rounded, color: AppColors.winGreen, size: 30)
                : Text(
                    '$countdown',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerCard({
    required bool isUser,
    required String name,
    required int rating,
    required bool isProvisional,
    required String team,
    required int avatarIdx,
    String? avatarCustom,
    required bool isReady,
    required bool isOnline,
    required bool isDark,
    VoidCallback? onReadyPressed,
  }) {
    final isWhite = team == 'white';
    final teamRingColor = isWhite
        ? (isDark ? AppColors.pieceWhite : AppColors.getBorder(isDark))
        : (isDark ? AppColors.getTextSecondary(isDark) : AppColors.pieceBlack);
    final badgeBg = isWhite
        ? (isDark ? AppColors.pieceWhite.withValues(alpha: 0.15) : AppColors.getBorder(isDark))
        : (isDark ? AppColors.getBorder(isDark) : AppColors.pieceBlack.withValues(alpha: 0.12));
    final badgeTextColor = isWhite
        ? (isDark ? AppColors.pieceWhite : AppColors.getTextPrimary(isDark))
        : (isDark ? AppColors.getTextSecondary(isDark) : AppColors.pieceBlack);
    final avatarItem = AvatarPicker.avatars[avatarIdx % AvatarPicker.avatars.length];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.getCard(isDark),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isReady
              ? AppColors.winGreen.withValues(alpha: 0.6)
              : AppColors.getBorder(isDark),
          width: isReady ? 1.8 : 1.0,
        ),
        boxShadow: [
          if (isReady)
            BoxShadow(
              color: AppColors.winGreen.withValues(alpha: 0.15),
              blurRadius: 8,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Row(
        children: [
          // Avatar with team ring
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: avatarItem.accentColor.withValues(alpha: 0.15),
              border: Border.all(color: teamRingColor, width: 2.2),
            ),
            child: Center(
              child: (avatarCustom != null && avatarCustom.trim().isNotEmpty)
                  ? Text(
                      avatarCustom.trim(),
                      style: const TextStyle(fontSize: 22, height: 1.0),
                    )
                  : Icon(avatarItem.icon, size: 24, color: avatarItem.accentColor),
            ),
          ),
          const SizedBox(width: 14),

          // Name, Rating & Role
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.getTextPrimary(isDark),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isWhite ? 'common.white'.tr() : 'common.black'.tr(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: badgeTextColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      isProvisional ? '$rating?' : '$rating',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.getRatingGold(isDark),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // Ready Status Badge
          if (isReady)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.winGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.winGreen.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_rounded, color: AppColors.winGreen, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'online.readyConfirmed'.tr(),
                    style: const TextStyle(
                      color: AppColors.winGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          else if (isUser)
            ElevatedButton(
              onPressed: onReadyPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.winGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'online.imReady'.tr(),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.getSurface(isDark),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.getBorder(isDark)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.getTextSecondary(isDark),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'online.waitingForOpponentReady'.tr(),
                    style: TextStyle(
                      color: AppColors.getTextSecondary(isDark),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _confirmLeave(BuildContext context, OnlineGameProvider provider) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.getCard(Theme.of(context).brightness == Brightness.dark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'online.leaveReadyPhase'.tr(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.getTextPrimary(Theme.of(context).brightness == Brightness.dark),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.lossRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              provider.leaveRoom();
            },
            child: Text('online.leaveReadyPhase'.tr()),
          ),
        ],
      ),
    );
  }
}
