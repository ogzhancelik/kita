import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/friend_models.dart';
import '../common/kita_avatar.dart';

/// Bottom sheet modal for searching and selecting a friend to share content with (e.g. replays).
class FriendPickerSheet extends StatefulWidget {
  final List<FriendItemModel> friends;
  final bool isDark;
  final ValueChanged<FriendItemModel> onSelectFriend;
  final String? title;

  const FriendPickerSheet({
    super.key,
    required this.friends,
    required this.isDark,
    required this.onSelectFriend,
    this.title,
  });

  static Future<FriendItemModel?> show({
    required BuildContext context,
    required List<FriendItemModel> friends,
    required bool isDark,
    String? title,
  }) {
    return showModalBottomSheet<FriendItemModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FriendPickerSheet(
        friends: friends,
        isDark: isDark,
        title: title,
        onSelectFriend: (friend) {
          Navigator.of(ctx).pop(friend);
        },
      ),
    );
  }

  @override
  State<FriendPickerSheet> createState() => _FriendPickerSheetState();
}

class _FriendPickerSheetState extends State<FriendPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final filtered = widget.friends.where((f) {
      if (_filter.isEmpty) return true;
      return f.username.toLowerCase().contains(_filter.toLowerCase());
    }).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
        maxWidth: 520,
      ),
      decoration: BoxDecoration(
        color: AppColors.getCard(isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(
          color: AppColors.getBorder(isDark),
          width: 1,
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.getBorder(isDark),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryAmber.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_search_rounded,
                      color: AppColors.primaryAmber,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.title ?? 'replay.selectFriendToSend'.tr(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.getTextPrimary(isDark),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Search bar
              Container(
                decoration: BoxDecoration(
                  color: AppColors.getSurface(isDark),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.getBorder(isDark),
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _filter = val),
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.getTextPrimary(isDark),
                  ),
                  decoration: InputDecoration(
                    hintText: 'chats.search'.tr(),
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: AppColors.getTextMuted(isDark),
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: AppColors.getTextMuted(isDark),
                      size: 18,
                    ),
                    suffixIcon: _filter.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear_rounded,
                              color: AppColors.getTextMuted(isDark),
                              size: 16,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _filter = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Friends list
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.people_outline_rounded,
                              size: 40,
                              color: AppColors.getTextMuted(isDark),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'chats.noFriendsFound'.tr(),
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.getTextSecondary(isDark),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (ctx, index) {
                          final friend = filtered[index];
                          return ListTile(
                            onTap: () => widget.onSelectFriend(friend),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            tileColor: AppColors.getSurface(isDark).withValues(alpha: 0.6),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 2,
                            ),
                            leading: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                KitaAvatar(
                                  size: 38,
                                  avatarIndex: friend.avatarIndex,
                                  avatarCustom: friend.avatarCustom,
                                  borderWidth: 1.5,
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: friend.isOnline
                                          ? AppColors.online
                                          : AppColors.offline,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.getCard(isDark),
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            title: Text(
                              friend.username,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.getTextPrimary(isDark),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '★ ${friend.rating}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ratingGold,
                              ),
                            ),
                            trailing: ElevatedButton.icon(
                              onPressed: () => widget.onSelectFriend(friend),
                              icon: const Icon(Icons.send_rounded, size: 14),
                              label: Text('replay.sendToFriend'.tr()),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryAmber,
                                foregroundColor: AppColors.darkTextPrimary,
                                elevation: 0,
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
