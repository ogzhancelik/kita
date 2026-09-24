import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/friend_models.dart';
import '../../../data/models/ws_message_models.dart';
import '../../providers/online_game_provider.dart';
import 'activity_conflict_dialog.dart';


class FriendChallengeDialog extends StatefulWidget {
  final FriendItemModel friend;
  final OnlineGameProvider onlineProv;

  const FriendChallengeDialog({
    super.key,
    required this.friend,
    required this.onlineProv,
  });

  static Future<void> show({
    required BuildContext context,
    required FriendItemModel friend,
    required OnlineGameProvider onlineProv,
  }) async {
    if (friend.isOnline) {
      final canProceed = await ActivityConflictHelper.checkAndConfirm(
        context: context,
        provider: onlineProv,
      );
      if (!canProceed) return;
      if (!context.mounted) return;
    }

    return showDialog(
      context: context,
      builder: (ctx) => FriendChallengeDialog(
        friend: friend,
        onlineProv: onlineProv,
      ),
    );
  }

  @override
  State<FriendChallengeDialog> createState() => _FriendChallengeDialogState();
}

class _FriendChallengeDialogState extends State<FriendChallengeDialog> {
  String _selectedColor = 'random';
  int _selectedTimeControl = TimeControlPreset.threeMin;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOffline = !widget.friend.isOnline;

    return AlertDialog(
      backgroundColor: AppColors.getCard(isDark),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      title: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOffline
                  ? AppColors.warning.withValues(alpha: 0.15)
                  : AppColors.onlineLight.withValues(alpha: 0.2),
            ),
            child: Icon(
              isOffline ? Icons.cloud_off_rounded : Icons.sports_esports_rounded,
              size: 32,
              color: isOffline ? AppColors.warning : AppColors.online,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isOffline ? 'online.friendOffline'.tr() : 'online.sendInvite'.tr(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.getTextPrimary(isDark),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Opponent info badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.getSurface(isDark),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.getBorder(isDark)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: (isOffline ? AppColors.drawGray : AppColors.online)
                      .withValues(alpha: 0.2),
                  child: Text(
                    widget.friend.username.isNotEmpty
                        ? widget.friend.username[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isOffline ? AppColors.drawGray : AppColors.online,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.friend.username,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.getTextPrimary(isDark),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: widget.friend.isOnline
                                  ? AppColors.online
                                  : AppColors.drawGray,
                              shape: BoxShape.circle,
                              boxShadow: widget.friend.isOnline
                                  ? [
                                      BoxShadow(
                                        color: AppColors.online.withValues(alpha: 0.5),
                                        blurRadius: 3,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.friend.isOnline
                                ? 'online.onlineStatus'.tr()
                                : 'online.offlineStatus'.tr(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: widget.friend.isOnline ? FontWeight.w600 : FontWeight.normal,
                              color: widget.friend.isOnline
                                  ? AppColors.online
                                  : AppColors.getTextSecondary(isDark),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.ratingGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '★ ${widget.friend.rating}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: AppColors.ratingGold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isOffline) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
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
                    size: 20,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'online.friendOfflineWarning'.tr(),
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),

            // Choose Side
            Text(
              'online.chooseSide'.tr(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.getTextSecondary(isDark),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _buildChoiceChip(
                  label: 'online.colorRandom'.tr(),
                  icon: Icons.shuffle_rounded,
                  isSelected: _selectedColor == 'random',
                  isDark: isDark,
                  onSelected: () => setState(() => _selectedColor = 'random'),
                ),
                _buildChoiceChip(
                  label: 'online.colorWhite'.tr(),
                  icon: Icons.circle,
                  iconColor: AppColors.darkTextPrimary,
                  isSelected: _selectedColor == 'white',
                  isDark: isDark,
                  onSelected: () => setState(() => _selectedColor = 'white'),
                ),
                _buildChoiceChip(
                  label: 'online.colorBlack'.tr(),
                  icon: Icons.circle_outlined,
                  isSelected: _selectedColor == 'black',
                  isDark: isDark,
                  onSelected: () => setState(() => _selectedColor = 'black'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Time Control
            Text(
              'online.selectTimeControl'.tr(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.getTextSecondary(isDark),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildTimeChip('online.timeBullet'.tr(), TimeControlPreset.oneMin, isDark),
                _buildTimeChip('online.timeBlitz'.tr(), TimeControlPreset.threeMin, isDark),
                _buildTimeChip('online.timeRapid'.tr(), TimeControlPreset.fiveMin, isDark),
                _buildTimeChip('online.timeUnlimited'.tr(), TimeControlPreset.unlimited, isDark),
              ],
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'online.cancel'.tr(),
            style: TextStyle(
              color: isOffline ? AppColors.getTextPrimary(isDark) : AppColors.getTextSecondary(isDark),
              fontWeight: isOffline ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
        if (!isOffline)
          ElevatedButton(
            onPressed: () async {
              final canProceed = await ActivityConflictHelper.checkAndConfirm(
                context: context,
                provider: widget.onlineProv,
              );
              if (!canProceed) return;
              if (!context.mounted) return;

              Navigator.of(context).pop();
              widget.onlineProv.inviteToMatch(
                widget.friend.userId,
                friendName: widget.friend.username,
                friendRating: widget.friend.rating,
                timeControl: _selectedTimeControl,
                colorPreference: _selectedColor,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: AppColors.darkTextPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text('online.sendInvite'.tr()),
          ),
      ],
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required IconData icon,
    Color? iconColor,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected
            ? AppColors.darkTextPrimary
            : (iconColor ?? AppColors.getTextPrimary(isDark)),
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppColors.darkTextPrimary : AppColors.getTextPrimary(isDark),
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.primaryGreen,
      backgroundColor: AppColors.getSurface(isDark),
      onSelected: (_) => onSelected(),
    );
  }

  Widget _buildTimeChip(String label, int value, bool isDark) {
    final isSelected = _selectedTimeControl == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppColors.darkTextPrimary : AppColors.getTextPrimary(isDark),
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.primaryGreen,
      backgroundColor: AppColors.getSurface(isDark),
      onSelected: (_) => setState(() => _selectedTimeControl = value),
    );
  }
}
