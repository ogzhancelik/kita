import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../providers/online_game_provider.dart';
import '../../screens/game/online_match_screen.dart';

/// Modal bottom sheet for queueing into matchmaking.
/// Shows online player count, low activity warning, elapsed wait timer, and cancel option.
class MatchmakingSheet extends StatefulWidget {
  const MatchmakingSheet({super.key});

  static Future<void> show(BuildContext context) async {
    final nav = Navigator.of(context);
    final provider = context.read<OnlineGameProvider>();

    await showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => const MatchmakingSheet(),
    );

    // If bottom sheet was closed because match started, navigate cleanly to OnlineMatchScreen
    if (provider.matchState.value == OnlineMatchState.inMatch &&
        context.mounted &&
        !OnlineMatchScreen.isMatchScreenOpen) {
      await nav.push(
        MaterialPageRoute(
          builder: (_) => const OnlineMatchScreen(),
        ),
      );
    }
  }

  @override
  State<MatchmakingSheet> createState() => _MatchmakingSheetState();
}

class _MatchmakingSheetState extends State<MatchmakingSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Request fresh online count on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<OnlineGameProvider>();
      provider.requestOnlineCount();
      if (provider.matchState.value == OnlineMatchState.idle) {
        provider.joinQueue();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OnlineGameProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // If match has transitioned to inMatch, simply close sheet
    if (provider.matchState.value == OnlineMatchState.inMatch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final route = ModalRoute.of(context);
          if (route != null && route.isActive) {
            Navigator.of(context).removeRoute(route);
          }
        }
      });
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.getCard(isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: AppColors.getBorder(isDark)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.getBorder(isDark),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Online Count Badge & Low Activity Warning
          ValueListenableBuilder(
            valueListenable: provider.onlineCount,
            builder: (ctx, countData, _) {
              final total = countData?.totalOnline ?? 1;
              final isLow = total <= 3;

              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.getSurface(isDark),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.getBorder(isDark)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'online.playersOnlineCount'.tr(args: ['$total']),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.getTextSecondary(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (isLow) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: AppColors.warning,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'online.lowCountNotice'.tr(),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),

          const SizedBox(height: 28),

          // Animated Radar / Pulse Ring
          AnimatedBuilder(
            animation: _pulseController,
            builder: (ctx, child) {
              return Transform.scale(
                scale: 1.0 + (_pulseController.value * 0.12),
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryGreen.withValues(
                      alpha: 0.15 + (1 - _pulseController.value) * 0.15,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primaryGreen,
                      ),
                      child: const Icon(
                        Icons.search,
                        color: AppColors.darkTextPrimary,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 20),

          // Status Title
          Text(
            'online.searchingOpponent'.tr(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.getTextPrimary(isDark),
            ),
          ),
          const SizedBox(height: 6),

          // Elapsed Queue Timer
          ValueListenableBuilder<int>(
            valueListenable: provider.queueElapsedSeconds,
            builder: (ctx, seconds, _) {
              final mins = seconds ~/ 60;
              final secs = seconds % 60;
              final formatted =
                  '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

              return Text(
                'online.queueWaitTime'.tr(args: [formatted]),
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'monospace',
                  color: AppColors.getTextMuted(isDark),
                ),
              );
            },
          ),

          const SizedBox(height: 28),

          // Cancel Queue Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: () {
                provider.leaveQueue();
                Navigator.of(context).pop();
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.lossRed),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'online.cancelSearch'.tr(),
                style: const TextStyle(
                  color: AppColors.lossRed,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
