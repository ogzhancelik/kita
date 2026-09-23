import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/friend_models.dart';
import '../../providers/friends_provider.dart';
import '../../providers/online_game_provider.dart';
import '../../widgets/matchmaking/friend_challenge_dialog.dart';
import '../game/online_match_screen.dart';

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
      context.read<FriendsProvider>().loadAll();
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
    final onlineProv = context.watch<OnlineGameProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Navigate to match if online match starts
    if (onlineProv.matchState.value == OnlineMatchState.inMatch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const OnlineMatchScreen()),
          );
        }
      });
    }

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
                  if (friendsProv.pendingIncomingCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.lossRed,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${friendsProv.pendingIncomingCount}',
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
            onRemove: () => friendsProv.removeFriend(friend.userId),
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
      onRefresh: friendsProv.loadAll,
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
                onAccept: () => friendsProv.acceptRequest(r.friendshipId),
                onDecline: () => friendsProv.declineRequest(r.friendshipId),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (outgoing.isNotEmpty) ...[
            Text(
              'Sent Requests',
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

  const _FriendCard({
    required this.friend,
    required this.isDark,
    required this.onInvite,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.getCard(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.getBorder(isDark)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.ratingGold.withValues(alpha: 0.2),
            child: Text(
              friend.username.isNotEmpty ? friend.username[0].toUpperCase() : '?',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.ratingGold,
              ),
            ),
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
                ),
                Text(
                  'Rating: ${friend.rating}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.ratingGold,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: onInvite,
            icon: const Icon(Icons.sports_esports, size: 16),
            label: Text('online.sendInvite'.tr()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: AppColors.darkTextPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, size: 18),
            color: AppColors.getTextMuted(isDark),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _IncomingRequestCard extends StatelessWidget {
  final FriendItemModel request;
  final bool isDark;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _IncomingRequestCard({
    required this.request,
    required this.isDark,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.getCard(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.getBorder(isDark)),
      ),
      child: Row(
        children: [
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
                  'Rating: ${request.rating}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.getTextMuted(isDark),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.check_circle, color: AppColors.primaryGreen),
            onPressed: onAccept,
          ),
          IconButton(
            icon: const Icon(Icons.cancel, color: AppColors.lossRed),
            onPressed: onDecline,
          ),
        ],
      ),
    );
  }
}

class _OutgoingRequestCard extends StatelessWidget {
  final FriendItemModel request;
  final bool isDark;
  final VoidCallback onCancel;

  const _OutgoingRequestCard({
    required this.request,
    required this.isDark,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.getCard(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.getBorder(isDark)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              request.username,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.getTextSecondary(isDark),
              ),
            ),
          ),
          Text(
            'Pending...',
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: AppColors.getTextMuted(isDark),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            color: AppColors.getTextMuted(isDark),
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

