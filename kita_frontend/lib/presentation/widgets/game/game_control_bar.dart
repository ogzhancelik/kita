import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../providers/online_game_provider.dart';

/// Control bar displayed at the bottom of the online match screen.
/// Provides resign, chat toggle with unread badge, and game timer.
class GameControlBar extends StatelessWidget {
  const GameControlBar({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OnlineGameProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.getCard(isDark),
        border: Border(
          top: BorderSide(
            color: AppColors.getBorder(isDark),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Resign Button
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            color: AppColors.lossRed,
            tooltip: 'online.resign'.tr(),
            onPressed: () => _confirmResign(context, provider),
          ),

          const Spacer(),

          // Total Match Elapsed Time
          ValueListenableBuilder<int>(
            valueListenable: provider.elapsedSeconds,
            builder: (ctx, seconds, _) {
              final mins = seconds ~/ 60;
              final secs = seconds % 60;
              final timeStr =
                  '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.getSurface(isDark),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.getBorder(isDark)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 15,
                      color: AppColors.getTextMuted(isDark),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.getTextSecondary(isDark),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const Spacer(),

          // Chat Toggle with unread badge
          ValueListenableBuilder<int>(
            valueListenable: provider.unreadChatCount,
            builder: (ctx, unread, _) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: Icon(
                      provider.isChatOpen
                          ? Icons.chat
                          : Icons.chat_bubble_outline,
                    ),
                    color: provider.isChatOpen
                        ? AppColors.primaryGreen
                        : AppColors.getTextSecondary(isDark),
                    tooltip: 'online.chat'.tr(),
                    onPressed: provider.toggleChat,
                  ),
                  if (unread > 0)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.lossRed,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          unread > 9 ? '9+' : '$unread',
                          style: const TextStyle(
                            color: AppColors.darkTextPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _confirmResign(BuildContext context, OnlineGameProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('online.resignTitle'.tr()),
        content: Text('online.resignConfirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('online.cancel'.tr()),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              provider.resign();
            },
            child: Text(
              'online.resign'.tr(),
              style: const TextStyle(color: AppColors.lossRed),
            ),
          ),
        ],
      ),
    );
  }
}
