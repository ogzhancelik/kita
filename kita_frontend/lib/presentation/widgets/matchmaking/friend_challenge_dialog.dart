import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/friend_models.dart';
import '../../../data/models/ws_message_models.dart';
import '../../providers/online_game_provider.dart';
import '../common/kita_avatar.dart';
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
        allowOutgoingChallenges: true,
      );
      if (!canProceed) return;
      if (!context.mounted) return;
    }

    return showDialog(
      context: context,
      builder: (ctx) =>
          FriendChallengeDialog(friend: friend, onlineProv: onlineProv),
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
                  : (widget.friend.isAfk
                      ? AppColors.afk.withValues(alpha: 0.18)
                      : AppColors.onlineLight.withValues(alpha: 0.2)),
            ),
            child: Icon(
              isOffline
                  ? Icons.schedule_rounded
                  : (widget.friend.isAfk
                      ? Icons.access_time_filled_rounded
                      : Icons.sports_esports_rounded),
              size: 32,
              color: isOffline
                  ? AppColors.warning
                  : (widget.friend.isAfk ? AppColors.getAfk(isDark) : AppColors.online),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isOffline
                ? 'online.sendInviteOffline'.tr()
                : 'online.sendInvite'.tr(),
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
                KitaAvatar(
                  size: 34,
                  avatarIndex: widget.friend.avatarIndex,
                  avatarCustom: widget.friend.avatarCustom,
                  borderWidth: 1.8,
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
                      Builder(
                        builder: (context) {
                          final statusColor = isOffline
                              ? AppColors.offline
                              : (widget.friend.isAfk ? AppColors.afk : AppColors.online);
                          final statusText = isOffline
                              ? 'common.offline'.tr()
                              : (widget.friend.isAfk ? 'common.afk'.tr() : 'common.online'.tr());

                          return Row(
                            children: [
                              Container(
                                width: 9,
                                height: 9,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                  boxShadow: widget.friend.isOnline
                                      ? [
                                          BoxShadow(
                                            color: statusColor.withValues(
                                              alpha: 0.5,
                                            ),
                                            blurRadius: 3,
                                          ),
                                        ]
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                statusText,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: widget.friend.isOnline
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: isOffline
                                      ? AppColors.getTextSecondary(isDark)
                                      : (widget.friend.isAfk
                                          ? AppColors.getAfk(isDark)
                                          : AppColors.online),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.ratingGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '★ ${widget.friend.displayRating}',
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
          Row(
            children: [
              Expanded(
                child: _buildSideToggleItem(
                  label: 'common.random'.tr(),
                  icon: Icons.shuffle_rounded,
                  isSelected: _selectedColor == 'random',
                  isDark: isDark,
                  onTap: () => setState(() => _selectedColor = 'random'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSideToggleItem(
                  label: 'common.white'.tr(),
                  icon: Icons.circle,
                  iconColor: AppColors.pieceWhite,
                  isSelected: _selectedColor == 'white',
                  isDark: isDark,
                  onTap: () => setState(() => _selectedColor = 'white'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSideToggleItem(
                  label: 'common.black'.tr(),
                  icon: Icons.circle_outlined,
                  isSelected: _selectedColor == 'black',
                  isDark: isDark,
                  onTap: () => setState(() => _selectedColor = 'black'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Time Control (2x2 Grid with equal width)
          Text(
            'online.selectTimeControl'.tr(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.getTextSecondary(isDark),
            ),
          ),
          const SizedBox(height: 8),
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildTimeOption(
                      label: TimeControlPreset.format(
                        TimeControlPreset.defaultPresets[0],
                      ),
                      value: TimeControlPreset.defaultPresets[0],
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildTimeOption(
                      label: TimeControlPreset.format(
                        TimeControlPreset.defaultPresets[1],
                      ),
                      value: TimeControlPreset.defaultPresets[1],
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildTimeOption(
                      label: TimeControlPreset.format(
                        TimeControlPreset.defaultPresets[2],
                      ),
                      value: TimeControlPreset.defaultPresets[2],
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildTimeOption(
                      label: TimeControlPreset.format(
                        TimeControlPreset.defaultPresets[3],
                      ),
                      value: TimeControlPreset.defaultPresets[3],
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.getTextSecondary(isDark),
                  side: BorderSide(color: AppColors.getBorder(isDark)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'common.cancel'.tr(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  if (!isOffline) {
                    final canProceed =
                        await ActivityConflictHelper.checkAndConfirm(
                          context: context,
                          provider: widget.onlineProv,
                          allowOutgoingChallenges: true,
                        );
                    if (!canProceed) return;
                    if (!context.mounted) return;
                  }

                  Navigator.of(context).pop();
                  widget.onlineProv.inviteToMatch(
                    widget.friend.userId,
                    friendName: widget.friend.username,
                    friendRating: widget.friend.rating,
                    friendIsProvisional: widget.friend.isProvisional,
                    timeControl: _selectedTimeControl,
                    colorPreference: _selectedColor,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryAmber,
                  foregroundColor: AppColors.darkTextPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  isOffline
                      ? 'online.sendInviteOfflineBtn'.tr()
                      : 'online.sendInvite'.tr(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSideToggleItem({
    required String label,
    required IconData icon,
    Color? iconColor,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryAmber.withValues(alpha: 0.15)
              : AppColors.getSurface(isDark),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryAmber
                : AppColors.getBorder(isDark),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? AppColors.primaryAmber
                  : (iconColor ?? AppColors.getTextSecondary(isDark)),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? AppColors.primaryAmber
                      : AppColors.getTextPrimary(isDark),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeOption({
    required String label,
    required int value,
    required bool isDark,
  }) {
    final isSelected = _selectedTimeControl == value;
    return InkWell(
      onTap: () => setState(() => _selectedTimeControl = value),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryAmber.withValues(alpha: 0.15)
              : AppColors.getSurface(isDark),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryAmber
                : AppColors.getBorder(isDark),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? AppColors.primaryAmber
                  : AppColors.getTextPrimary(isDark),
            ),
          ),
        ),
      ),
    );
  }
}
