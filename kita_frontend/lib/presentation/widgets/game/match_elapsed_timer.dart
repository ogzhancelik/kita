import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../providers/online_game_provider.dart';

/// Reusable elapsed match timer widget.
/// Used in the bottom action bar when chat is closed, and to the left of the
/// "Type a message" container when chat is open.
class MatchElapsedTimer extends StatelessWidget {
  const MatchElapsedTimer({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OnlineGameProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<int>(
      valueListenable: provider.elapsedSeconds,
      builder: (ctx, seconds, _) {
        final mins = seconds ~/ 60;
        final secs = seconds % 60;
        final timeStr =
            '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

        return Tooltip(
          message: 'online.totalTime'.tr(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.getSurface(isDark),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.getBorder(isDark),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 13,
                  color: AppColors.getTextMuted(isDark),
                ),
                const SizedBox(width: 4),
                Text(
                  timeStr,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: AppColors.getTextSecondary(isDark),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
