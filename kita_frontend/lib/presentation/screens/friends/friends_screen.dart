import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/friend_models.dart';
import '../../../data/models/notification_model.dart';
import '../../providers/friends_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/online_game_provider.dart';
import '../../widgets/common/avatar_picker.dart';
import '../../widgets/home/user_profile_dialog.dart';
import '../../widgets/matchmaking/friend_challenge_dialog.dart';

/// Screen managing friends list, incoming/outgoing requests, and direct challenges.
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FriendsProvider>().loadAll().then((_) {
        if (mounted) {
          final incoming = context.read<FriendsProvider>().incomingRequests;
          context.read<NotificationProvider>().syncFromFriendRequests(incoming);
        }
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final friendsProv = context.watch<FriendsProvider>();
    final notifProv = context.watch<NotificationProvider>();
    final onlineProv = context.watch<OnlineGameProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final pendingFriendCount = notifProv.pendingNotifications
        .where((n) => n.type == KitaNotificationType.friendRequest)
        .length;


    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        title: Text('online.friendsTitle'.tr()),
        backgroundColor: AppColors.getCard(isDark),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryGreen,
          labelColor: AppColors.primaryGreen,
          unselectedLabelColor: AppColors.getTextMuted(isDark),
          tabs: [
            Tab(text: 'online.friends'.tr()),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('online.friendRequests'.tr()),
                  if (pendingFriendCount > 0 || friendsProv.pendingIncomingCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.lossRed,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${pendingFriendCount > 0 ? pendingFriendCount : friendsProv.pendingIncomingCount}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.darkTextPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded),
            tooltip: 'online.addFriend'.tr(),
            onPressed: () => _showAddFriendDialog(context, friendsProv),
          ),
        ],
      ),
      body: friendsProv.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                // 1. Friends list
                _buildFriendsTab(context, friendsProv, onlineProv, isDark),

                // 2. Friend requests
                _buildRequestsTab(context, friendsProv, isDark),
              ],
            ),
    );
  }

  Widget _buildFriendsTab(
    BuildContext context,
    FriendsProvider friendsProv,
    OnlineGameProvider onlineProv,
    bool isDark,
  ) {
    final friends = friendsProv.friends;
    if (friends.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline_rounded,
              size: 56,
              color: AppColors.getTextMuted(isDark),
            ),
            const SizedBox(height: 12),
            Text(
              'online.noFriendsYet'.tr(),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.getTextSecondary(isDark),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showAddFriendDialog(context, friendsProv),
              icon: const Icon(Icons.add, size: 18),
              label: Text('online.addFriend'.tr()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: AppColors.darkTextPrimary,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primaryGreen,
      onRefresh: friendsProv.loadAll,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: friends.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (ctx, index) {
          final friend = friends[index];
          return _FriendCard(
            friend: friend,
            isDark: isDark,
            onInvite: () => _inviteFriendToMatch(context, onlineProv, friend),
            onRemove: () => _confirmRemoveFriend(context, friendsProv, friend),
            onTap: () {
              UserProfileDialog.show(
                context,
                userId: friend.userId,
                fallbackName: friend.username,
                fallbackAvatarIndex: friend.avatarIndex,
                fallbackRating: friend.rating,
                onInvite: () => _inviteFriendToMatch(context, onlineProv, friend),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildRequestsTab(
    BuildContext context,
    FriendsProvider friendsProv,
    bool isDark,
  ) {
    final incoming = friendsProv.incomingRequests;
    final outgoing = friendsProv.outgoingRequests;

    if (incoming.isEmpty && outgoing.isEmpty) {
      return Center(
        child: Text(
          'online.noFriendsYet'.tr(),
          style: TextStyle(
            fontSize: 14,
            color: AppColors.getTextMuted(isDark),
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primaryGreen,
      onRefresh: () async {
        final notifProv = context.read<NotificationProvider>();
        await friendsProv.loadAll();
        notifProv.syncFromFriendRequests(friendsProv.incomingRequests);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (incoming.isNotEmpty) ...[
            Text(
              'online.friendRequests'.tr(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppColors.getTextPrimary(isDark),
              ),
            ),
            const SizedBox(height: 8),
            ...incoming.map(
              (r) => _IncomingRequestCard(
                request: r,
                isDark: isDark,
                onTap: () {
                  UserProfileDialog.show(
                    context,
                    userId: r.userId,
                    fallbackName: r.username,
                    fallbackAvatarIndex: r.avatarIndex,
                    fallbackRating: r.rating,
                  );
                },
                onAccept: () async {
                  final notifId = 'friend_request_${r.friendshipId}';
                  final notifProv = context.read<NotificationProvider>();
                  await notifProv.acceptNotification(context, notifId);
                  await friendsProv.acceptRequest(r.friendshipId);
                  notifProv.syncFriendshipActioned(r.friendshipId, NotificationStatus.accepted);
                },
                onDecline: () async {
                  final notifId = 'friend_request_${r.friendshipId}';
                  final notifProv = context.read<NotificationProvider>();
                  await notifProv.declineNotification(context, notifId);
                  await friendsProv.declineRequest(r.friendshipId);
                  notifProv.syncFriendshipActioned(r.friendshipId, NotificationStatus.declined);
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (outgoing.isNotEmpty) ...[
            Text(
              'online.friendRequests'.tr(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppColors.getTextPrimary(isDark),
              ),
            ),
            const SizedBox(height: 8),
            ...outgoing.map(
              (r) => _OutgoingRequestCard(
                request: r,
                isDark: isDark,
                onTap: () {
                  UserProfileDialog.show(
                    context,
                    userId: r.userId,
                    fallbackName: r.username,
                    fallbackAvatarIndex: r.avatarIndex,
                    fallbackRating: r.rating,
                  );
                },
                onCancel: () => friendsProv.declineRequest(r.friendshipId),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _inviteFriendToMatch(
    BuildContext context,
    OnlineGameProvider onlineProv,
    FriendItemModel friend,
  ) {
    FriendChallengeDialog.show(
      context: context,
      friend: friend,
      onlineProv: onlineProv,
    );
  }

  void _confirmRemoveFriend(
    BuildContext context,
    FriendsProvider provider,
    FriendItemModel friend,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.getCard(isDark),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.getBorder(isDark)),
        ),
        title: Text(
          'online.removeFriend'.tr(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.getTextPrimary(isDark),
          ),
        ),
        content: Text(
          'online.removeFriendConfirm'.tr(args: [friend.username]),
          style: TextStyle(
            fontSize: 14,
            color: AppColors.getTextSecondary(isDark),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'online.cancel'.tr(),
              style: TextStyle(color: AppColors.getTextMuted(isDark)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              provider.removeFriend(friend.userId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('online.removeFriend'.tr()),
          ),
        ],
      ),
    );
  }

  void _showAddFriendDialog(BuildContext context, FriendsProvider provider) {
    final controller = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.getCard(isDark),
        title: Text(
          'online.addFriend'.tr(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.getTextPrimary(isDark),
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: AppColors.getTextPrimary(isDark)),
          decoration: InputDecoration(
            hintText: 'Enter username...',
            hintStyle: TextStyle(color: AppColors.getTextMuted(isDark)),
            filled: true,
            fillColor: AppColors.getSurface(isDark),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('online.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () async {
              final username = controller.text.trim();
              if (username.isNotEmpty) {
                Navigator.of(ctx).pop();
                final ok = await provider.sendRequest(username);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok
                          ? 'Friend request sent!'
                          : provider.errorMessage ?? 'Failed to send request'),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: AppColors.darkTextPrimary,
            ),
            child: Text('online.addFriend'.tr()),
          ),
        ],
      ),
    );
  }
}

class _FriendCard extends StatelessWidget {
  final FriendItemModel friend;
  final bool isDark;
  final VoidCallback onInvite;
  final VoidCallback onRemove;
  final VoidCallback? onTap;

  const _FriendCard({
    required this.friend,
    required this.isDark,
    required this.onInvite,
    required this.onRemove,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final avatarItem = AvatarPicker.avatars[friend.avatarIndex % AvatarPicker.avatars.length];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.getCard(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.getBorder(isDark)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: avatarItem.accentColor.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: avatarItem.accentColor,
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        avatarItem.icon,
                        color: avatarItem.accentColor,
                        size: 22,
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
                            color: isDark ? AppColors.darkCard : AppColors.lightCard,
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
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        friend.username,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.getTextPrimary(isDark),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '★ ${friend.rating}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ratingGold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Quick Invite Button
                Tooltip(
                  message: 'online.sendInvite'.tr(),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onInvite,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: friend.isOnline
                              ? AppColors.primaryGreen.withValues(alpha: 0.15)
                              : AppColors.getSurface(isDark),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: friend.isOnline
                                ? AppColors.primaryGreen.withValues(alpha: 0.4)
                                : AppColors.getBorder(isDark),
                          ),
                        ),
                        child: Icon(
                          Icons.sports_esports_rounded,
                          size: 18,
                          color: friend.isOnline
                              ? AppColors.primaryGreen
                              : AppColors.getTextSecondary(isDark),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),

                // Remove Friend Button
                IconButton(
                  tooltip: 'online.removeFriend'.tr(),
                  icon: const Icon(Icons.person_remove_rounded, size: 20),
                  color: AppColors.getTextMuted(isDark),
                  hoverColor: AppColors.error.withValues(alpha: 0.1),
                  splashRadius: 20,
                  onPressed: onRemove,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IncomingRequestCard extends StatelessWidget {
  final FriendItemModel request;
  final bool isDark;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback? onTap;

  const _IncomingRequestCard({
    required this.request,
    required this.isDark,
    required this.onAccept,
    required this.onDecline,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final avatarItem = AvatarPicker.avatars[request.avatarIndex % AvatarPicker.avatars.length];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.getCard(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.getBorder(isDark)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: avatarItem.accentColor.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: avatarItem.accentColor,
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    avatarItem.icon,
                    color: avatarItem.accentColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.username,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.getTextPrimary(isDark),
                        ),
                      ),
                      Text(
                        '★ ${request.rating}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ratingGold,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.check_circle, color: AppColors.accentSecondary),
                  onPressed: onAccept,
                ),
                IconButton(
                  icon: const Icon(Icons.cancel, color: AppColors.lossRed),
                  onPressed: onDecline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OutgoingRequestCard extends StatelessWidget {
  final FriendItemModel request;
  final bool isDark;
  final VoidCallback onCancel;
  final VoidCallback? onTap;

  const _OutgoingRequestCard({
    required this.request,
    required this.isDark,
    required this.onCancel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final avatarItem = AvatarPicker.avatars[request.avatarIndex % AvatarPicker.avatars.length];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.getCard(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.getBorder(isDark)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: avatarItem.accentColor.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: avatarItem.accentColor,
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    avatarItem.icon,
                    color: avatarItem.accentColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.username,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.getTextSecondary(isDark),
                        ),
                      ),
                      Text(
                        '★ ${request.rating}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ratingGold,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  color: AppColors.getTextMuted(isDark),
                  onPressed: onCancel,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

