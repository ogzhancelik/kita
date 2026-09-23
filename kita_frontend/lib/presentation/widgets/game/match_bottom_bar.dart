import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../providers/online_game_provider.dart';
import 'match_elapsed_timer.dart';
import 'match_menu_dialog.dart';

/// Bottom action bar in the portrait match screen.
/// Layout:
/// - Left: Menu button (hamburger icon) for resign, draw, report; and Chat toggle button.
/// - Center: Total elapsed match time.
/// - Right: History step backward (<) and step forward (>) buttons.
/// Spans full width with zero outer page margins and equal horizontal padding inside.
class MatchBottomBar extends StatelessWidget {
  const MatchBottomBar({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OnlineGameProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          // 1. Menu Button (Hamburger)
          IconButton(
            icon: const Icon(Icons.menu_rounded),
            color: AppColors.getTextPrimary(isDark),
            tooltip: 'online.matchMenu'.tr(),
            onPressed: () => MatchMenuDialog.show(context),
          ),
          const SizedBox(width: 4),

          // 2. Chat Toggle Button with unread badge
          ValueListenableBuilder<int>(
            valueListenable: provider.unreadChatCount,
            builder: (ctx, unread, _) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: Icon(
                      provider.isChatOpen
                          ? Icons.chat_rounded
                          : Icons.chat_bubble_outline_rounded,
                    ),
                    color: provider.isChatOpen
                        ? AppColors.primaryGreen
                        : AppColors.getTextSecondary(isDark),
                    tooltip: 'online.toggleChat'.tr(),
                    onPressed: provider.toggleChat,
                  ),
                  if (unread > 0 && !provider.isChatOpen)
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
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          unread > 9 ? '9+' : '$unread',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
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

          const Spacer(),

          // 3. Center: Elapsed Match Time
          const MatchElapsedTimer(),

          const Spacer(),

          // 4. Right: Move Step Backward & Forward Buttons (reactively rebuilt on index change)
          ValueListenableBuilder<int>(
            valueListenable: provider.viewingMoveIndex,
            builder: (ctx, viewIdx, _) {
              final canBack = provider.canStepBackward;
              final canForward = provider.canStepForward;

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, size: 28),
                    color: canBack
                        ? AppColors.getTextPrimary(isDark)
                        : AppColors.getTextMuted(isDark),
                    tooltip: 'online.stepBackward'.tr(),
                    onPressed: canBack ? provider.stepBackward : null,
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, size: 28),
                    color: canForward
                        ? AppColors.getTextPrimary(isDark)
                        : AppColors.getTextMuted(isDark),
                    tooltip: 'online.stepForward'.tr(),
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
