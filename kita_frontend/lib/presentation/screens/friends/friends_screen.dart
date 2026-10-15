import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/dm_models.dart';
import '../../../data/models/friend_models.dart';
import '../../../data/models/notification_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dm_provider.dart';
import '../../providers/friends_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/online_game_provider.dart';
import '../../widgets/common/kita_app_bar.dart';
import '../../widgets/common/kita_avatar.dart';
import '../../widgets/common/responsive_layout.dart';
import '../../widgets/friends/add_friend_dialog.dart';
import '../../widgets/home/user_profile_dialog.dart';
import '../../widgets/matchmaking/friend_challenge_dialog.dart';
import 'dm_chat_screen.dart';

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
    _tabController = TabController(length: 2, vsync: this);
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

  Widget _buildFilterSelector(bool isDark, int pendingCount) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: AnimatedBuilder(
        animation: _tabController.animation ?? _tabController,
        builder: (context, _) {
          final animValue =
              _tabController.animation?.value ?? _tabController.index.toDouble();
          final t = animValue.clamp(0.0, 1.0);

          return LayoutBuilder(
            builder: (context, constraints) {
              final tabWidth = constraints.maxWidth / 2;

              return Stack(
                children: [
                  // Smooth sliding indicator pill
                  Positioned(
                    left: t * tabWidth,
                    top: 0,
                    bottom: 0,
                    width: tabWidth,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primaryAmber,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color:
                                AppColors.primaryAmber.withValues(alpha: 0.35),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Tab interactive labels on top
                  Row(
                    children: [
                      Expanded(
                        child: _buildFilterTabItem(
                          label: 'online.friends'.tr(),
                          icon: Icons.people_alt_rounded,
                          activeProgress: 1.0 - t,
                          onTap: () => _tabController.animateTo(0),
                          isDark: isDark,
                        ),
                      ),
                      Expanded(
                        child: _buildFilterTabItem(
                          label: 'online.friendRequests'.tr(),
                          icon: Icons.mail_outline_rounded,
                          activeProgress: t,
                          badgeCount: pendingCount,
                          onTap: () => _tabController.animateTo(1),
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFilterTabItem({
    required String label,
    required IconData icon,
    required double activeProgress,
    required VoidCallback onTap,
    required bool isDark,
    int badgeCount = 0,
  }) {
    final activeColor = AppColors.darkTextPrimary;
    final inactiveColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    final color = Color.lerp(inactiveColor, activeColor, activeProgress)!;
    final badgeBg =
        Color.lerp(AppColors.lossRed, Colors.white, activeProgress)!;
    final badgeFg =
        Color.lerp(Colors.white, AppColors.primaryAmberDark, activeProgress)!;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        splashColor: AppColors.primaryAmber.withValues(alpha: 0.12),
        highlightColor: Colors.transparent,
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: color,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: activeProgress > 0.5
                        ? FontWeight.bold
                        : FontWeight.w600,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badgeCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: TextStyle(
                      fontSize: 10,
                      color: badgeFg,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
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
    final totalPendingRequests = pendingFriendCount > 0
        ? pendingFriendCount
        : friendsProv.pendingIncomingCount;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: KitaAppBar(
        title: 'online.friends'.tr(),
        iconColor: AppColors.sectionFriends,
        leadingIcon: Icons.group,
        showBack: true,
        showAuthActions: false,
        showLanguageToggle: false,
        showThemeToggle: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => AddFriendDialog.show(context),
        backgroundColor: AppColors.primaryAmber,
        elevation: 4,
        icon: const Icon(
          Icons.person_add_alt_1_rounded,
          color: AppColors.darkTextPrimary,
        ),
        label: Text(
          'online.searchPlayers'.tr(),
          style: const TextStyle(
            color: AppColors.darkTextPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ResponsiveLayout(
        maxWidth: 640,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: _buildFilterSelector(isDark, totalPendingRequests),
            ),
            Expanded(
              child: friendsProv.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryAmber,
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        // 1. Friends list
                        _buildFriendsTab(
                          context,
                          friendsProv,
                          onlineProv,
                          isDark,
                        ),

                        // 2. Friend requests
                        _buildRequestsTab(context, friendsProv, isDark),
                      ],
                    ),
            ),
          ],
        ),
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
              onPressed: () => AddFriendDialog.show(context),
              icon: const Icon(Icons.person_search_rounded, size: 18),
              label: Text('online.searchPlayers'.tr()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryAmber,
                foregroundColor: AppColors.darkTextPrimary,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primaryAmber,
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
            onChat: () {
              final myId = context.read<AuthProvider>().currentUser?.id ?? '';
              if (myId.isNotEmpty) {
                final convId = dmConversationId(myId, friend.userId);
                final dmProv = context.read<DmProvider?>();
                if (dmProv != null) {
                  dmProv.clearUnread(convId, userId: friend.userId);
                  dmProv.setActiveConversation(convId);
                }
                context.read<NotificationProvider>().deleteChatNotifications(
                  convId,
                  actorId: friend.userId,
                );
              }
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => DmChatScreen(friend: friend)),
              );
            },
            onTap: () {
              UserProfileDialog.show(
                context,
                userId: friend.userId,
                fallbackName: friend.username,
                fallbackAvatarIndex: friend.avatarIndex,
                fallbackRating: friend.rating,
                onInvite: () =>
                    _inviteFriendToMatch(context, onlineProv, friend),
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
          style: TextStyle(fontSize: 14, color: AppColors.getTextMuted(isDark)),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primaryAmber,
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
                  notifProv.syncFriendshipActioned(
                    r.friendshipId,
                    NotificationStatus.accepted,
                  );
                },
                onDecline: () async {
                  final notifId = 'friend_request_${r.friendshipId}';
                  final notifProv = context.read<NotificationProvider>();
                  await notifProv.declineNotification(context, notifId);
                  await friendsProv.declineRequest(r.friendshipId);
                  notifProv.syncFriendshipActioned(
                    r.friendshipId,
                    NotificationStatus.declined,
                  );
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
              'common.cancel'.tr(),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('online.removeFriend'.tr()),
          ),
        ],
      ),
    );
  }
}

enum _FriendAction { challenge, chat, remove }

class _FriendCard extends StatelessWidget {
  final FriendItemModel friend;
  final bool isDark;
  final VoidCallback onInvite;
  final VoidCallback onRemove;
  final VoidCallback? onChat;
  final VoidCallback? onTap;

  const _FriendCard({
    required this.friend,
    required this.isDark,
    required this.onInvite,
    required this.onRemove,
    this.onChat,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
                    KitaAvatar(
                      size: 40,
                      avatarIndex: friend.avatarIndex,
                      avatarCustom: friend.avatarCustom,
                      borderWidth: 1.5,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: friend.isOnline
                              ? AppColors.online
                              : AppColors.offline,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkCard
                                : AppColors.lightCard,
                            width: 1.5,
                          ),
                          boxShadow: friend.isOnline
                              ? [
                                  BoxShadow(
                                    color: AppColors.online.withValues(
                                      alpha: 0.5,
                                    ),
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
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.getRatingGold(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // More Options Menu (Three dots)
                Consumer<DmProvider>(
                  builder: (context, dmProv, _) {
                    final convId = dmConversationId(
                      context.read<AuthProvider>().currentUser?.id ?? '',
                      friend.userId,
                    );
                    final unread = dmProv.unreadFor(convId);
                    return Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        PopupMenuButton<_FriendAction>(
                          tooltip: 'common.moreOptions'.tr(),
                          icon: Icon(
                            Icons.more_vert_rounded,
                            size: 22,
                            color: AppColors.getTextSecondary(isDark),
                          ),
                          position: PopupMenuPosition.under,
                          color: AppColors.getCard(isDark),
                          elevation: 6,
                          shadowColor: Colors.black.withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: AppColors.getBorder(isDark),
                              width: 1,
                            ),
                          ),
                          onSelected: (action) {
                            switch (action) {
                              case _FriendAction.challenge:
                                onInvite();
                                break;
                              case _FriendAction.chat:
                                onChat?.call();
                                break;
                              case _FriendAction.remove:
                                onRemove();
                                break;
                            }
                          },
                          itemBuilder: (ctx) => [
                            PopupMenuItem<_FriendAction>(
                              value: _FriendAction.challenge,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.sports_esports_rounded,
                                    size: 20,
                                    color: friend.isOnline
                                        ? AppColors.accent
                                        : AppColors.getTextSecondary(isDark),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'dashboard.quickChallenge'.tr(),
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.getTextPrimary(isDark),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem<_FriendAction>(
                              value: _FriendAction.chat,
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    size: 20,
                                    color: AppColors.primaryVibrant,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'online.chat'.tr(),
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.getTextPrimary(isDark),
                                      ),
                                    ),
                                  ),
                                  if (unread > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.lossRed,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        unread > 9 ? '9+' : '$unread',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.darkTextPrimary,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const PopupMenuDivider(height: 1),
                            PopupMenuItem<_FriendAction>(
                              value: _FriendAction.remove,
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.person_remove_rounded,
                                    size: 20,
                                    color: AppColors.lossRed,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'online.removeFriend'.tr(),
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.lossRed,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (unread > 0)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: IgnorePointer(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.lossRed,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isDark
                                        ? AppColors.darkCard
                                        : AppColors.lightCard,
                                    width: 1.5,
                                  ),
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  unread > 9 ? '9+' : '$unread',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.darkTextPrimary,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
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
                KitaAvatar(
                  size: 36,
                  avatarIndex: request.avatarIndex,
                  avatarCustom: request.avatarCustom,
                  borderWidth: 1.5,
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
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.getRatingGold(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.check_circle,
                    color: AppColors.accentSecondary,
                  ),
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
                KitaAvatar(
                  size: 36,
                  avatarIndex: request.avatarIndex,
                  avatarCustom: request.avatarCustom,
                  borderWidth: 1.5,
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
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.getRatingGold(isDark),
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
