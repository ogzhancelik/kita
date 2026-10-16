import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/dm_models.dart';
import '../../../data/models/friend_models.dart';
import '../../../data/services/user_api_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dm_provider.dart';
import '../../providers/friends_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/online_game_provider.dart';
import '../../widgets/common/kita_avatar.dart';
import '../../widgets/common/kita_emoji_picker.dart';
import '../../widgets/dm/dm_replay_card_widget.dart';
import '../../widgets/dm/match_chat_card_widget.dart';
import '../../widgets/home/user_profile_dialog.dart';
import '../../widgets/matchmaking/friend_challenge_dialog.dart';

/// Merged timeline item — either a DM message or a MatchChatCard.
class _TimelineItem {
  final DmMessage? dm;
  final MatchChatCard? match;
  DateTime get time => dm?.createdAt ?? match!.playedAt;
  bool get isMatch => match != null;

  const _TimelineItem.dm(this.dm) : match = null;
  const _TimelineItem.match(this.match) : dm = null;
}

/// Direct-message conversation screen with integrated in-game match cards.
class DmChatScreen extends StatefulWidget {
  final FriendItemModel friend;
  const DmChatScreen({super.key, required this.friend});

  @override
  State<DmChatScreen> createState() => _DmChatScreenState();
}

class _DmChatScreenState extends State<DmChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  late String _conversationId;
  late String _myId;
  late String _myUsername;
  late FriendItemModel _friend;
  int _lastTimelineCount = 0;
  bool _showEmojiPicker = false;
  Timer? _focusScrollTimer;

  @override
  void initState() {
    super.initState();
    _friend = widget.friend;
    if (_friend.username == 'Player' || _friend.username.isEmpty || _friend.avatarCustom == null || _friend.avatarCustom!.isEmpty) {
      UserApiService()
          .getUserProfile(_friend.userId)
          .then((profile) {
            if (mounted) {
              setState(() {
                _friend = _friend.copyWith(
                  username: profile.username,
                  avatarIndex: profile.avatarIndex,
                  avatarCustom: profile.avatarCustom,
                  rating: profile.rating,
                );
              });
            }
          })
          .catchError((_) {});
    }

    final auth = context.read<AuthProvider>();
    _myId = auth.currentUser?.id ?? '';
    if (_myId.isEmpty) {
      _myId = context.read<OnlineGameProvider>().myUserId ?? '';
    }
    _myUsername = auth.currentUser?.username ?? '';
    _conversationId = _myId.isNotEmpty
        ? dmConversationId(_myId, widget.friend.userId)
        : widget.friend.userId;

    final dmProv = context.read<DmProvider>();
    if (_myId.isNotEmpty) {
      dmProv.setMyUserId(_myId);
    }
    dmProv.setActiveConversation(_conversationId);
    dmProv.clearUnread(_conversationId, userId: widget.friend.userId);
    context.read<NotificationProvider>().deleteChatNotifications(
      _conversationId,
      actorId: widget.friend.userId,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      dmProv.loadHistory(_conversationId, refresh: true);
      dmProv.loadSharedMatches(
        _conversationId,
        _myId,
        widget.friend.userId,
        refresh: true,
      );
    });

    _scrollController.addListener(_onScroll);

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        if (_showEmojiPicker) {
          setState(() {
            _showEmojiPicker = false;
          });
        }
        _focusScrollTimer?.cancel();
        _focusScrollTimer = Timer(const Duration(milliseconds: 300), () {
          if (mounted) _scrollToBottom();
        });
      }
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    // In reverse: true list, older messages are towards maxScrollExtent
    if (pos.maxScrollExtent > 0 && pos.pixels >= pos.maxScrollExtent - 200) {
      final dmProv = context.read<DmProvider>();
      if (dmProv.hasMoreHistoryFor(_conversationId) &&
          !dmProv.isLoadingMoreFor(_conversationId) &&
          !dmProv.isHistoryLoadingFor(_conversationId)) {
        dmProv.loadMoreHistory(_conversationId);
      }
    }
  }

  DmProvider? _dmProv;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _dmProv = context.read<DmProvider>();
  }

  @override
  void deactivate() {
    _dmProv?.setActiveConversation(null);
    _dmProv?.clearUnread(_conversationId, userId: widget.friend.userId);
    try {
      context.read<NotificationProvider>().deleteChatNotifications(
        _conversationId,
        actorId: widget.friend.userId,
      );
    } catch (_) {}
    super.deactivate();
  }

  @override
  void dispose() {
    _focusScrollTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _dmProv?.setActiveConversation(null);
    _dmProv?.clearUnread(_conversationId, userId: widget.friend.userId);
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool immediate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      if (immediate) {
        _scrollController.jumpTo(0);
      } else {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _insertEmoji(String emoji) {
    final text = _controller.text;
    final selection = _controller.selection;
    if (selection.isValid && selection.start >= 0 && selection.end >= 0) {
      final start = selection.start;
      final end = selection.end;
      final newText = text.replaceRange(start, end, emoji);
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start + emoji.length),
      );
    } else {
      final newText = text + emoji;
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    }
  }

  void _toggleEmojiPicker() async {
    if (_showEmojiPicker) {
      setState(() {
        _showEmojiPicker = false;
      });
      _focusNode.requestFocus();
    } else {
      final isKeyboardOpen = FocusScope.of(context).hasFocus;
      if (isKeyboardOpen) {
        FocusScope.of(context).unfocus();
        await Future.delayed(const Duration(milliseconds: 150));
      }
      if (mounted) {
        setState(() {
          _showEmojiPicker = true;
        });
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _scrollToBottom();
        });
      }
    }
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    final auth = context.read<AuthProvider>();
    context.read<DmProvider>().sendDm(
      recipientId: _friend.userId,
      content: text,
      senderId: _myId,
      senderUsername: _myUsername,
      senderAvatarIndex: auth.avatarIndex,
      recipientUsername: _friend.username,
      recipientAvatarIndex: _friend.avatarIndex,
    );
    _scrollToBottom();
  }

  /// Merges DM messages and match cards into a single list (newest first for reverse list).
  List<_TimelineItem> _buildTimeline(
    List<DmMessage> messages,
    List<MatchChatCard> matchCards,
  ) {
    final items = <_TimelineItem>[
      for (final m in messages) _TimelineItem.dm(m),
      for (final c in matchCards) _TimelineItem.match(c),
    ]..sort((a, b) => b.time.compareTo(a.time));
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopScope(
      canPop: !_showEmojiPicker,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _showEmojiPicker) {
          setState(() {
            _showEmojiPicker = false;
          });
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.getBackground(isDark),
        appBar: _buildAppBar(isDark),
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            FocusScope.of(context).unfocus();
            if (_showEmojiPicker) {
              setState(() {
                _showEmojiPicker = false;
              });
            }
          },
          child: Column(
            children: [
              Expanded(child: _buildTimeline2(isDark)),
              _buildInputBar(isDark),
              if (_showEmojiPicker)
                SizedBox(
                  height: 250,
                  child: KitaEmojiPicker(
                    height: 250,
                    onEmojiSelected: _insertEmoji,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openProfileCard(FriendItemModel friend) {
    FocusScope.of(context).unfocus();
    UserProfileDialog.show(
      context,
      userId: friend.userId,
      fallbackName: friend.username,
      fallbackAvatarIndex: friend.avatarIndex,
      fallbackRating: friend.rating,
      onInvite: () {
        final onlineProv = context.read<OnlineGameProvider>();
        FriendChallengeDialog.show(
          context: context,
          friend: friend,
          onlineProv: onlineProv,
        );
      },
      onChatPressed: () {
        _focusNode.requestFocus();
      },
    );
  }

  AppBar _buildAppBar(bool isDark) {
    final friendsProv = context.watch<FriendsProvider>();
    final friend = friendsProv.friends.firstWhere(
      (f) => f.userId == _friend.userId,
      orElse: () => _friend,
    );
    final dmProv = context.watch<DmProvider>();
    final messages = dmProv.messagesFor(_conversationId);
    String? effectiveAvatarCustom = friend.avatarCustom ?? _friend.avatarCustom;
    if (effectiveAvatarCustom == null || effectiveAvatarCustom.isEmpty) {
      for (final m in messages) {
        if (m.senderId == _friend.userId &&
            m.senderAvatarCustom != null &&
            m.senderAvatarCustom!.isNotEmpty) {
          effectiveAvatarCustom = m.senderAvatarCustom;
          break;
        }
      }
    }
    return AppBar(
      backgroundColor: AppColors.getCard(isDark),
      elevation: 0,
      centerTitle: false,
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
        color: AppColors.getTextPrimary(isDark),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: InkWell(
        onTap: () => _openProfileCard(friend),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Row(
            children: [
              Stack(
                children: [
                  KitaAvatar(
                    size: 36,
                    avatarIndex: friend.avatarIndex,
                    avatarCustom: effectiveAvatarCustom,
                    borderWidth: 1.5,
                  ),
                  if (friend.isOnline)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppColors.online,
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
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      friend.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.getTextPrimary(isDark),
                      ),
                    ),
                    Text(
                      friend.isOnline
                          ? 'common.online'.tr()
                          : 'common.offline'.tr(),
                      style: TextStyle(
                        fontSize: 11,
                        color: friend.isOnline
                            ? AppColors.online
                            : AppColors.getTextMuted(isDark),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeline2(bool isDark) {
    return Consumer<DmProvider>(
      builder: (context, dmProv, _) {
        final messages = dmProv.messagesFor(_conversationId);
        final matchCards = dmProv.matchCardsFor(_conversationId);
        final timeline = _buildTimeline(messages, matchCards);

        if (dmProv.isHistoryLoading && messages.isEmpty && matchCards.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primaryAmber),
          );
        }

        if (timeline.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 52,
                  color: AppColors.getTextMuted(isDark),
                ),
                const SizedBox(height: 12),
                Text(
                  'dm.startConversation'.tr(),
                  style: TextStyle(
                    color: AppColors.getTextMuted(isDark),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        final isLoadingMore = dmProv.isLoadingMoreFor(_conversationId);

        if (timeline.length != _lastTimelineCount) {
          final isInitial = _lastTimelineCount == 0;
          final wasLoadingMore = isLoadingMore;
          _lastTimelineCount = timeline.length;
          final isMyMsg =
              timeline.isNotEmpty && timeline.first.dm?.senderId == _myId;
          final isNearBottom =
              !_scrollController.hasClients ||
              _scrollController.position.pixels < 250;

          if (!isInitial && !wasLoadingMore && (isMyMsg || isNearBottom)) {
            _scrollToBottom(immediate: false);
          }
        }

        return ListView.builder(
          controller: _scrollController,
          reverse: true,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          itemCount: timeline.length + (isLoadingMore ? 1 : 0),
          itemBuilder: (ctx, index) {
            if (isLoadingMore && index == timeline.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primaryAmber,
                    ),
                  ),
                ),
              );
            }
            final item = timeline[index];
            final olderItem =
                index + 1 < timeline.length ? timeline[index + 1] : null;
            final showDate =
                olderItem == null || !_isSameDay(item.time, olderItem.time);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showDate) _buildDateDivider(item.time, isDark),
                if (item.isMatch)
                  MatchChatCardWidget(
                    match: item.match!,
                    isDark: isDark,
                    myUserId: _myId,
                    myUsername: _myUsername,
                    friendUsername: widget.friend.username,
                  )
                else
                  _MessageBubble(
                    message: item.dm!,
                    isMe: item.dm!.senderId == _myId,
                    isDark: isDark,
                    friendAvatarIndex: widget.friend.avatarIndex,
                    friendAvatarCustom: widget.friend.avatarCustom,
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDateDivider(DateTime date, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Divider(color: AppColors.getBorder(isDark), height: 1),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _formatDate(date),
              style: TextStyle(
                fontSize: 11,
                color: AppColors.getTextMuted(isDark),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Divider(color: AppColors.getBorder(isDark), height: 1),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(bool isDark) {
    final friendsProv = context.watch<FriendsProvider>();
    final friend = friendsProv.friends.firstWhere(
      (f) => f.userId == _friend.userId,
      orElse: () => _friend,
    );
    final isDeleted = friend.username == '[Deleted]';

    if (isDeleted) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.getCard(isDark),
          border: Border(
            top: BorderSide(color: AppColors.getBorder(isDark), width: 0.5),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: AppColors.lossRed,
              ),
              const SizedBox(width: 8),
              Text(
                'chats.accountDeletedNotice'.tr(),
                style: TextStyle(
                  color: AppColors.getTextMuted(isDark),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.getCard(isDark),
        border: Border(
          top: BorderSide(color: AppColors.getBorder(isDark), width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.getSurface(isDark),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          _showEmojiPicker
                              ? Icons.keyboard_rounded
                              : Icons.emoji_emotions_outlined,
                          color: _showEmojiPicker
                              ? AppColors.primaryAmber
                              : AppColors.getTextMuted(isDark),
                          size: 20,
                        ),
                        onPressed: _toggleEmojiPicker,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        constraints: const BoxConstraints(),
                        tooltip: 'dm.emojiTooltip'.tr(),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          minLines: 1,
                          maxLines: 4,
                          maxLength: 500,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          style: TextStyle(
                            color: AppColors.getTextPrimary(isDark),
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'dm.messageHint'.tr(),
                            hintStyle: TextStyle(
                              color: AppColors.getTextMuted(isDark),
                              fontSize: 14,
                            ),
                            counterText: '',
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _send,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.send_rounded,
                    color: AppColors.darkTextPrimary,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    final la = a.toLocal();
    final lb = b.toLocal();
    return la.year == lb.year && la.month == lb.month && la.day == lb.day;
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(local.year, local.month, local.day);
    if (_isSameDay(today, target)) {
      return 'dm.today'.tr();
    }
    final yesterday = today.subtract(const Duration(days: 1));
    if (_isSameDay(yesterday, target)) {
      return 'dm.yesterday'.tr();
    }
    return DateFormat('d MMM y', context.locale.toString()).format(local);
  }
}

// ─── Message Bubble ─────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final DmMessage message;
  final bool isMe;
  final bool isDark;
  final int friendAvatarIndex;
  final String? friendAvatarCustom;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.isDark,
    required this.friendAvatarIndex,
    this.friendAvatarCustom,
  });

  @override
  Widget build(BuildContext context) {
    final replayPayload = DmReplayPayload.tryParse(message.content);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            KitaAvatar(
              size: 28,
              avatarIndex: friendAvatarIndex,
              avatarCustom: message.senderAvatarCustom ?? friendAvatarCustom,
              borderWidth: 1.5,
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (replayPayload != null)
                  DmReplayCardWidget(
                    payload: replayPayload,
                    isMe: isMe,
                    isDark: isDark,
                    timestamp: message.createdAt,
                  )
                else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.72,
                    ),
                    decoration: BoxDecoration(
                      color: isMe
                          ? AppColors.primary
                          : AppColors.getSurface(isDark),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isMe ? 18 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(12),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      message.content,
                      style: TextStyle(
                        color: isMe
                            ? AppColors.darkTextPrimary
                            : AppColors.getTextPrimary(isDark),
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatTime(message.createdAt),
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.getTextMuted(isDark),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 6),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
