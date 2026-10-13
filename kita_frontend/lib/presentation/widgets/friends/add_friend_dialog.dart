import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'player_search_view.dart';

/// Modal dialog for global player search and sending friend requests.
class AddFriendDialog extends StatelessWidget {
  const AddFriendDialog({super.key});

  /// Display the AddFriendDialog modal.
  static Future<bool?> show(BuildContext context) {
    FocusManager.instance.primaryFocus?.unfocus();
    return showDialog<bool>(
      context: context,
      barrierColor: AppColors.dialogBarrier,
      builder: (_) => const AddFriendDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      backgroundColor: AppColors.getCard(isDark),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppColors.getBorder(isDark), width: 1.2),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: screenHeight * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 6),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.getBrandPrimary(isDark).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_search_rounded,
                      color: AppColors.getBrandPrimary(isDark),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'online.searchPlayers'.tr(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.getTextPrimary(isDark),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'online.searchPlayersSubtitle'.tr(),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.getTextSecondary(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: AppColors.getTextMuted(isDark),
                    ),
                    onPressed: () => Navigator.of(context).pop(false),
                    splashRadius: 18,
                    tooltip: 'common.cancel'.tr(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Search View Content
            const Expanded(
              child: PlayerSearchView(isModal: true),
            ),
          ],
        ),
      ),
    );
  }
}
