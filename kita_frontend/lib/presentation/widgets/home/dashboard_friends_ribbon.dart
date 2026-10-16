import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/dm_models.dart';
import '../../../data/models/friend_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dm_provider.dart';
import '../../providers/friends_provider.dart';
import '../../providers/online_game_provider.dart';
import '../../screens/friends/friends_screen.dart';
import '../common/kita_avatar.dart';
import '../common/kita_card.dart';
import '../friends/add_friend_dialog.dart';
import 'user_profile_dialog.dart';

import '../matchmaking/friend_challenge_dialog.dart';

class DashboardFriendsRibbon extends StatefulWidget {
  const DashboardFriendsRibbon({super.key});

  @override
  State<DashboardFriendsRibbon> createState() => _DashboardFriendsRibbonState();
}

class _DashboardFriendsRibbonState extends State<DashboardFriendsRibbon> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final authProv = context.read<AuthProvider>();
        if (!authProv.isGuest && authProv.isAuthenticated) {
          context.read<FriendsProvider>().loadAll();
        }
      }
    });
  }

  void _quickInvite(FriendItemModel friend) {
    final onlineProv = context.read<OnlineGameProvider>();
    FriendChallengeDialog.show(
      context: context,
      friend: friend,
      onlineProv: onlineProv,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final friendsProv = context.watch<FriendsProvider>();
    final authProv = context.watch<AuthProvider>();
    final dmProv = Provider.of<DmProvider?>(context);
    final isGuest = authProv.isGuest;
    final myId = authProv.currentUser?.id ?? '';

    if (isGuest) {
      return const SizedBox.shrink();
    }

    final totalBadgeCount =
        (dmProv?.totalUnread ?? 0) + friendsProv.pendingIncomingCount;

    // Sort friends: online first, then by last interaction recency (match/chat)
    final sortedFriends = List<FriendItemModel>.from(friendsProv.friends)
      ..sort((a, b) {
        if (a.isOnline != b.isOnline) {
          return a.isOnline ? -1 : 1;
        }
        if (a.isOnline && b.isOnline && a.isAfk != b.isAfk) {
          return a.isAfk ? 1 : -1;
        }
        return b.lastInteractionAt.compareTo(a.lastInteractionAt);
      });

    final hasMoreThanTen = sortedFriends.length >= 10;
    final displayFriends = sortedFriends.take(10).toList();

    return KitaCard(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FriendsScreen()),
                ),
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.people_alt_rounded,
                      color: AppColors.sectionFriends,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'dashboard.friends'.tr(),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    if (totalBadgeCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryVibrant,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          totalBadgeCount > 99 ? '99+' : '$totalBadgeCount',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                  ],
                ),
              ),
              // Explicit "+ Add Friend" Header Action (Matches "Create Room" styling)
              TextButton.icon(
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.primaryAmber.withValues(
                    alpha: 0.15,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => AddFriendDialog.show(context),
                icon: const Icon(
                  Icons.person_add_alt_1_rounded,
                  size: 16,
                  color: AppColors.primaryAmber,
                ),
                label: Text(
                  'dashboard.addFriend'.tr(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryAmber,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (friendsProv.isLoading && sortedFriends.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (sortedFriends.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'online.noFriendsYet'.tr(),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: () => AddFriendDialog.show(context),
                      icon: const Icon(
                        Icons.person_add_alt_1_rounded,
                        size: 15,
                      ),
                      label: Text(
                        'dashboard.addFriend'.tr(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryAmber,
                        foregroundColor: AppColors.darkTextPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 136,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: displayFriends.length + (hasMoreThanTen ? 1 : 0) + 1,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  if (index < displayFriends.length) {
                    final friend = displayFriends[index];
                    final convId = dmConversationId(myId, friend.userId);
                    final friendUnread = dmProv?.unreadFor(convId) ?? 0;
                    return _buildFriendCard(friend, isDark, friendUnread);
                  } else if (hasMoreThanTen && index == displayFriends.length) {
                    return _buildViewAllCard(isDark);
                  } else {
                    return SizedBox.shrink();
                  }
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFriendCard(
    FriendItemModel friend,
    bool isDark,
    int unreadCount,
  ) {
    return Container(
      width: 108,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBg : AppColors.lightBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            UserProfileDialog.show(
              context,
              userId: friend.userId,
              fallbackName: friend.username,
              fallbackAvatarIndex: friend.avatarIndex,
              fallbackAvatarCustom: friend.avatarCustom,
              fallbackRating: friend.rating,
              onInvite: () => _quickInvite(friend),
            );
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Avatar + Online status indicator + Unread badge
                        Stack(
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
                              child: Builder(
                                builder: (context) {
                                  final statusColor = !friend.isOnline
                                      ? AppColors.offline
                                      : (friend.isAfk ? AppColors.afk : AppColors.online);
                                  return Container(
                                    width: 11,
                                    height: 11,
                                    decoration: BoxDecoration(
                                      color: statusColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isDark
                                            ? AppColors.darkBg
                                            : AppColors.lightBg,
                                        width: 1.5,
                                      ),
                                      boxShadow: friend.isOnline
                                          ? [
                                              BoxShadow(
                                                color: statusColor.withValues(
                                                  alpha: 0.5,
                                                ),
                                                blurRadius: 3,
                                                spreadRadius: 0.5,
                                              ),
                                            ]
                                          : null,
                                    ),
                                  );
                                },
                              ),
                            ),
                            if (unreadCount > 0)
                              Positioned(
                                top: -4,
                                right: -4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryVibrant,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isDark
                                          ? AppColors.darkBg
                                          : AppColors.lightBg,
                                      width: 1.5,
                                    ),
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    unreadCount > 9 ? '9+' : '$unreadCount',
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      height: 1.0,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 5),

                        // Friend Username
                        Text(
                          friend.username,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),

                        // Rating
                        Text(
                          '${friend.rating}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.getRatingGold(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Direct Challenge Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: friend.isOnline
                          ? AppColors.primaryAmber
                          : AppColors.getSurface(isDark),
                      elevation: friend.isOnline ? 1 : 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 5,
                      ),
                      minimumSize: const Size(0, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                        side: friend.isOnline
                            ? BorderSide.none
                            : BorderSide(color: AppColors.getBorder(isDark)),
                      ),
                    ),
                    onPressed: () => _quickInvite(friend),
                    child: Text(
                      'dashboard.quickChallenge'.tr(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: friend.isOnline
                            ? AppColors.darkTextPrimary
                            : (isDark
                                  ? AppColors.darkTextPrimary.withValues(
                                      alpha: 0.9,
                                    )
                                  : AppColors.lightTextPrimary),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildViewAllCard(bool isDark) {
    return InkWell(
      onTap: () =>
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const FriendsScreen())),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 90,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBg : AppColors.lightBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isDark
                    ? AppColors.darkSurface
                    : AppColors.lightSurface),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_forward_rounded,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
                size: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'common.viewAll'.tr(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
