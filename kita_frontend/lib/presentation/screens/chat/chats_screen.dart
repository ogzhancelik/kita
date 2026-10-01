import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/dm_models.dart';
import '../../../data/models/friend_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dm_provider.dart';
import '../../providers/friends_provider.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/common/avatar_picker.dart';
import '../../widgets/common/responsive_layout.dart';
import '../friends/dm_chat_screen.dart';

/// ChatsScreen displays all active direct-message conversations,
/// allows searching chats, and lets users start new conversations with friends.
class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final authProv = context.read<AuthProvider>();
        if (authProv.isAuthenticated && !authProv.isGuest) {
          context.read<FriendsProvider>().loadAll();
          context.read<DmProvider>().loadPreviews();
        }
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openChat(FriendItemModel friend) {
    final myId = context.read<AuthProvider>().currentUser?.id ?? '';
    if (myId.isNotEmpty) {
      final convId = dmConversationId(myId, friend.userId);
      context.read<NotificationProvider>().deleteChatNotifications(
            convId,
            actorId: friend.userId,
          );
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DmChatScreen(friend: friend),
      ),
    );
  }

  void _showNewChatSheet(BuildContext context, List<FriendItemModel> friends) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _NewChatBottomSheet(
          friends: friends,
          isDark: isDark,
          onSelectFriend: (friend) {
            Navigator.of(ctx).pop();
            _openChat(friend);
          },
        );
      },
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final localDt = dt.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(localDt.year, localDt.month, localDt.day);

    if (msgDay == today) {
      final hour = localDt.hour.toString().padLeft(2, '0');
      final minute = localDt.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } else if (today.difference(msgDay).inDays == 1) {
      return 'dm.yesterday'.tr();
    } else {
      final day = localDt.day.toString().padLeft(2, '0');
      final month = localDt.month.toString().padLeft(2, '0');
      if (localDt.year == now.year) {
        return '$day.$month';
      }
      return '$day.$month.${localDt.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProv = context.watch<AuthProvider>();
    final dmProv = context.watch<DmProvider>();
    final friendsProv = context.watch<FriendsProvider>();

    final isGuest = authProv.isGuest || !authProv.isAuthenticated;
    final myId = authProv.currentUser?.id ?? '';

    final previews = dmProv.previews;
    final allFriends = friendsProv.friends;

    // Build list of conversation items
    final List<_ChatItemData> items = [];
    final Set<String> processedUserIds = {};

    for (final preview in previews) {
      final otherUserId =
          preview.senderId == myId ? preview.recipientId : preview.senderId;
      if (otherUserId.isEmpty || processedUserIds.contains(otherUserId)) {
        continue;
      }
      processedUserIds.add(otherUserId);

      // Match friend item or construct fallback
      FriendItemModel? friend;
      for (final f in allFriends) {
        if (f.userId == otherUserId) {
          friend = f;
          break;
        }
      }

      friend ??= FriendItemModel(
        friendshipId: '',
        userId: otherUserId,
        username: preview.senderId == otherUserId && preview.senderUsername.isNotEmpty
            ? preview.senderUsername
            : 'Player',
        rating: 1200,
        status: 'friend',
        direction: 'friend',
        isOnline: false,
        createdAt: preview.createdAt,
      );

      final isMe = preview.senderId == myId;
      final snippet = isMe
          ? '${'chats.you'.tr()}${preview.content}'
          : preview.content;

      items.add(_ChatItemData(
        friend: friend,
        conversationId: preview.conversationId,
        lastMessageSnippet: snippet,
        lastMessageTime: preview.createdAt,
        unreadCount: dmProv.unreadFor(preview.conversationId),
      ));
    }

    // Filter by search query
    final query = _searchQuery.trim().toLowerCase();
    final filteredItems = query.isEmpty
        ? items
        : items.where((item) {
            final nameMatch = item.friend.username.toLowerCase().contains(query);
            final msgMatch = item.lastMessageSnippet.toLowerCase().contains(query);
            return nameMatch || msgMatch;
          }).toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'chats.title'.tr(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        actions: [
          if (!isGuest)
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: const Icon(
                  Icons.edit_note_rounded,
                  color: AppColors.primaryGreen,
                  size: 20,
                ),
              ),
              tooltip: 'chats.startNewChat'.tr(),
              onPressed: () => _showNewChatSheet(context, allFriends),
            ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: (!isGuest && items.isNotEmpty)
          ? FloatingActionButton.extended(
              onPressed: () => _showNewChatSheet(context, allFriends),
              backgroundColor: AppColors.primaryGreen,
              elevation: 4,
              icon: const Icon(Icons.add_comment_rounded, color: AppColors.darkTextPrimary),
              label: Text(
                'chats.startNewChat'.tr(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkTextPrimary,
                ),
              ),
            )
          : null,
      body: ResponsiveLayout(
        child: isGuest
            ? _buildGuestView(isDark)
            : RefreshIndicator(
                color: AppColors.primaryGreen,
                onRefresh: () async {
                  await Future.wait([
                    dmProv.loadPreviews(),
                    friendsProv.loadAll(),
                  ]);
                },
                child: Column(
                  children: [
                    // Search bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          ),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val;
                            });
                          },
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: 'chats.search'.tr(),
                            hintStyle: TextStyle(
                              fontSize: 14,
                              color: AppColors.getTextMuted(isDark),
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: AppColors.getTextMuted(isDark),
                              size: 20,
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: Icon(
                                      Icons.clear_rounded,
                                      color: AppColors.getTextMuted(isDark),
                                      size: 18,
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                      });
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Conversations list or Empty state
                    Expanded(
                      child: filteredItems.isEmpty
                          ? _buildEmptyState(context, isDark, allFriends, hasChats: items.isNotEmpty)
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: filteredItems.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final item = filteredItems[index];
                                return _ChatTile(
                                  item: item,
                                  isDark: isDark,
                                  formattedTime: _formatTimestamp(item.lastMessageTime),
                                  onTap: () => _openChat(item.friend),
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

  Widget _buildGuestView(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 40,
                color: AppColors.primaryGreen,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'chats.title'.tr(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'chats.guestNotice'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.getTextSecondary(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    bool isDark,
    List<FriendItemModel> allFriends, {
    required bool hasChats,
  }) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.forum_outlined,
                size: 40,
                color: AppColors.primaryGreen,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              hasChats ? 'chats.noChatsFound'.tr() : 'chats.empty'.tr(),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'chats.emptyDesc'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.getTextSecondary(isDark),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _showNewChatSheet(context, allFriends),
              icon: const Icon(Icons.add_comment_rounded, size: 18),
              label: Text('chats.startNewChat'.tr()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: AppColors.darkTextPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatItemData {
  final FriendItemModel friend;
  final String conversationId;
  final String lastMessageSnippet;
  final DateTime lastMessageTime;
  final int unreadCount;

  const _ChatItemData({
    required this.friend,
    required this.conversationId,
    required this.lastMessageSnippet,
    required this.lastMessageTime,
    required this.unreadCount,
  });
}

class _ChatTile extends StatelessWidget {
  final _ChatItemData item;
  final bool isDark;
  final String formattedTime;
  final VoidCallback onTap;

  const _ChatTile({
    required this.item,
    required this.isDark,
    required this.formattedTime,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = AvatarPicker.avatars[
        item.friend.avatarIndex.clamp(0, AvatarPicker.avatars.length - 1)];
    final hasUnread = item.unreadCount > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasUnread
                  ? AppColors.primaryGreen.withValues(alpha: 0.6)
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              width: hasUnread ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              // Avatar + Online status indicator
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: avatar.accentColor.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: avatar.accentColor,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      avatar.icon,
                      color: avatar.accentColor,
                      size: 26,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: item.friend.isOnline ? AppColors.online : AppColors.drawGray,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                          width: 2,
                        ),
                        boxShadow: item.friend.isOnline
                            ? [
                                BoxShadow(
                                  color: AppColors.online.withValues(alpha: 0.5),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),

              // Username & last message snippet
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.friend.username,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w700,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: AppColors.ratingGold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${item.friend.rating}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.ratingGold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.lastMessageSnippet.isEmpty
                          ? 'chats.noMessages'.tr()
                          : item.lastMessageSnippet,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                        color: hasUnread
                            ? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)
                            : AppColors.getTextSecondary(isDark),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Timestamp & Unread badge
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formattedTime,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                      color: hasUnread
                          ? AppColors.primaryGreen
                          : AppColors.getTextMuted(isDark),
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (hasUnread)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      alignment: Alignment.center,
                      child: Text(
                        item.unreadCount > 99 ? '99+' : '${item.unreadCount}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkTextPrimary,
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewChatBottomSheet extends StatefulWidget {
  final List<FriendItemModel> friends;
  final bool isDark;
  final ValueChanged<FriendItemModel> onSelectFriend;

  const _NewChatBottomSheet({
    required this.friends,
    required this.isDark,
    required this.onSelectFriend,
  });

  @override
  State<_NewChatBottomSheet> createState() => _NewChatBottomSheetState();
}

class _NewChatBottomSheetState extends State<_NewChatBottomSheet> {
  final TextEditingController _filterController = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.friends.where((f) {
      if (_filter.isEmpty) return true;
      return f.username.toLowerCase().contains(_filter.toLowerCase());
    }).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: BoxDecoration(
        color: widget.isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(
          color: widget.isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      padding: const EdgeInsets.all(16),
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
                color: widget.isDark ? AppColors.darkBorder : AppColors.lightBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Title
          Text(
            'chats.selectFriend'.tr(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: widget.isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 12),

          // Search bar
          Container(
            decoration: BoxDecoration(
              color: widget.isDark ? AppColors.darkBg : AppColors.lightBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: TextField(
              controller: _filterController,
              onChanged: (val) => setState(() => _filter = val),
              style: TextStyle(
                fontSize: 14,
                color: widget.isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'chats.search'.tr(),
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: AppColors.getTextMuted(widget.isDark),
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: AppColors.getTextMuted(widget.isDark),
                  size: 18,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // List of friends
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'chats.noFriendsFound'.tr(),
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.getTextSecondary(widget.isDark),
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (ctx, index) {
                      final friend = filtered[index];
                      final avatar = AvatarPicker.avatars[friend.avatarIndex
                          .clamp(0, AvatarPicker.avatars.length - 1)];
                      return ListTile(
                        onTap: () => widget.onSelectFriend(friend),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        tileColor: widget.isDark
                            ? AppColors.darkBg.withValues(alpha: 0.5)
                            : AppColors.lightBg.withValues(alpha: 0.5),
                        leading: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: avatar.accentColor.withValues(alpha: 0.16),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: avatar.accentColor,
                                  width: 1.5,
                                ),
                              ),
                              child: Icon(
                                avatar.icon,
                                color: avatar.accentColor,
                                size: 22,
                              ),
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
                                      : AppColors.drawGray,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: widget.isDark
                                        ? AppColors.darkSurface
                                        : AppColors.lightSurface,
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
                            color: widget.isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                        subtitle: Text(
                          '${friend.rating} ELO',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.ratingGold,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: AppColors.primaryGreen,
                          size: 20,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
