import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/friend_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/friends_provider.dart';
import '../../providers/online_game_provider.dart';
import '../../screens/friends/friends_screen.dart';
import '../common/avatar_picker.dart';
import '../common/kita_card.dart';

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
    final isGuest = authProv.isGuest;

    if (isGuest) {
      return const SizedBox.shrink();
    }

    // Sort friends: online first, then by activity/recency (consistent with Friends tab, not by ELO)
    final sortedFriends = List<FriendItemModel>.from(friendsProv.friends)
      ..sort((a, b) {
        if (a.isOnline != b.isOnline) {
          return a.isOnline ? -1 : 1;
        }
        return 0;
      });

    final hasMoreThanTen = sortedFriends.length >= 10;
    final displayFriends = sortedFriends.take(10).toList();

    return KitaCard(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
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
                  color: AppColors.accentGold,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'dashboard.friendsQuick'.tr(),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ],
            ),
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
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'online.noFriendsYet'.tr(),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 124,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: displayFriends.length + (hasMoreThanTen ? 1 : 0),
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  if (index < displayFriends.length) {
                    final friend = displayFriends[index];
                    return _buildFriendCard(friend, isDark);
                  } else {
                    return _buildViewAllCard(isDark);
                  }
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFriendCard(FriendItemModel friend, bool isDark) {
    // Generate deterministic avatar icon from username hashCode
    final avatarIndex = friend.username.hashCode.abs() % AvatarPicker.avatars.length;
    final avatar = AvatarPicker.avatars[avatarIndex];

    return Container(
      width: 108,
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
          // Avatar + Online status indicator
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: avatar.accentColor.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: avatar.accentColor,
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  avatar.icon,
                  color: avatar.accentColor,
                  size: 20,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: friend.isOnline ? AppColors.online : AppColors.drawGray,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? AppColors.darkBg : AppColors.lightBg,
                      width: 1.5,
                    ),
                    boxShadow: friend.isOnline
                        ? [
                            BoxShadow(
                              color: AppColors.online.withValues(alpha: 0.5),
                              blurRadius: 3,
                              spreadRadius: 0.5,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Friend Username
          Text(
            friend.username,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),

          // Rating
          Text(
            '${friend.rating}',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.ratingGold,
            ),
          ),
          const SizedBox(height: 6),

          // Direct Challenge Button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: friend.isOnline
                  ? AppColors.primaryGreen
                  : AppColors.getSurface(isDark),
              elevation: friend.isOnline ? 1 : 0,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              minimumSize: Size.zero,
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
                fontSize: 10,
                fontWeight: friend.isOnline ? FontWeight.bold : FontWeight.normal,
                color: friend.isOnline
                    ? AppColors.darkTextPrimary
                    : AppColors.getTextSecondary(isDark),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewAllCard(bool isDark) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const FriendsScreen()),
      ),
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
                color: (isDark ? AppColors.darkSurface : AppColors.lightSurface),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_forward_rounded,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                size: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'dashboard.allFriends'.tr(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
