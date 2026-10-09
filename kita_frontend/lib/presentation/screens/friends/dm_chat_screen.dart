import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/dm_models.dart';
import '../../../data/models/friend_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dm_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/online_game_provider.dart';
import '../../widgets/common/avatar_picker.dart';
import '../../widgets/dm/match_chat_card_widget.dart';

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
  int _lastTimelineCount = 0;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _myId = auth.currentUser?.id ?? '';
    if (_myId.isEmpty) {
      _myId = context.read<OnlineGameProvider>().myUserId ?? '';
    }
    _myUsername = auth.currentUser?.username ?? '';
    _conversationId = dmConversationId(_myId, widget.friend.userId);

    final dmProv = context.read<DmProvider>();
    if (_myId.isNotEmpty) {
      dmProv.setMyUserId(_myId);
    }
    dmProv.setActiveConversation(_conversationId);
    dmProv.loadHistory(_conversationId);
    dmProv.loadSharedMatches(
      _conversationId,
      _myId,
      widget.friend.userId,
      refresh: true,
    );

    context.read<NotificationProvider>().deleteChatNotifications(
          _conversationId,
          actorId: widget.friend.userId,
        );

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _scrollToBottom();
        });
      }
    });
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
    super.deactivate();
  }

  @override
  void dispose() {
    _dmProv?.setActiveConversation(null);
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool immediate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (immediate) {
        _scrollController.jumpTo(target);
      } else {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    context.read<DmProvider>().sendDm(
          recipientId: widget.friend.userId,
          content: text,
          senderId: _myId,
          senderUsername: _myUsername,
        );
    _scrollToBottom();
  }

  /// Merges DM messages and match cards into a single chronological list.
  List<_TimelineItem> _buildTimeline(
      List<DmMessage> messages, List<MatchChatCard> matchCards) {
    final items = <_TimelineItem>[
      for (final m in messages) _TimelineItem.dm(m),
      for (final c in matchCards) _TimelineItem.match(c),
    ]..sort((a, b) => a.time.compareTo(b.time));
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: _buildAppBar(isDark),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            Expanded(child: _buildTimeline2(isDark)),
            _buildInputBar(isDark),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar(bool isDark) {
    final avatarItem = AvatarPicker
        .avatars[widget.friend.avatarIndex % AvatarPicker.avatars.length];
    return AppBar(
      backgroundColor: AppColors.getCard(isDark),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
        color: AppColors.getTextPrimary(isDark),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: avatarItem.accentColor.withAlpha(46),
                  shape: BoxShape.circle,
                  border: Border.all(color: avatarItem.accentColor, width: 1.5),
                ),
                child: Icon(avatarItem.icon,
                    color: avatarItem.accentColor, size: 20),
              ),
              if (widget.friend.isOnline)
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
                          color: AppColors.getCard(isDark), width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.friend.username,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.getTextPrimary(isDark))),
              Text(
                widget.friend.isOnline ? 'common.online'.tr() : 'common.offline'.tr(),
                style: TextStyle(
                    fontSize: 11,
                    color: widget.friend.isOnline
                        ? AppColors.online
                        : AppColors.getTextMuted(isDark)),
              ),
            ],
          ),
        ],
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
              child: CircularProgressIndicator(color: AppColors.primaryGreen));
        }

        if (timeline.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline_rounded,
                    size: 52, color: AppColors.getTextMuted(isDark)),
                const SizedBox(height: 12),
                Text('dm.startConversation'.tr(),
                    style: TextStyle(
                        color: AppColors.getTextMuted(isDark), fontSize: 14)),
              ],
            ),
          );
        }

        if (timeline.length != _lastTimelineCount) {
          final isInitial = _lastTimelineCount == 0;
          _lastTimelineCount = timeline.length;
          final isMyMsg =
              timeline.isNotEmpty && timeline.last.dm?.senderId == _myId;
          final isNearBottom = !_scrollController.hasClients ||
              (_scrollController.position.maxScrollExtent -
                      _scrollController.position.pixels <
                  250);

          if (isInitial) {
            _scrollToBottom(immediate: true);
          } else if (isMyMsg || isNearBottom) {
            _scrollToBottom(immediate: false);
          }
        }

        return ListView.builder(
          controller: _scrollController,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          itemCount: timeline.length,
          itemBuilder: (ctx, index) {
            final item = timeline[index];
            final prevItem = index > 0 ? timeline[index - 1] : null;
            final showDate = prevItem == null ||
                !_isSameDay(prevItem.time, item.time);

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
          Expanded(child: Divider(color: AppColors.getBorder(isDark), height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(_formatDate(date),
                style: TextStyle(
                    fontSize: 11,
                    color: AppColors.getTextMuted(isDark),
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Divider(color: AppColors.getBorder(isDark), height: 1)),
        ],
      ),
    );
  }

  Widget _buildInputBar(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getCard(isDark),
        border: Border(
            top: BorderSide(color: AppColors.getBorder(isDark), width: 0.5)),
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
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 500,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    style: TextStyle(
                        color: AppColors.getTextPrimary(isDark), fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'dm.messageHint'.tr(),
                      hintStyle: TextStyle(
                          color: AppColors.getTextMuted(isDark), fontSize: 14),
                      counterText: '',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
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
                      color: AppColors.primary, shape: BoxShape.circle),
                  child: const Icon(Icons.send_rounded,
                      color: AppColors.darkTextPrimary, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(DateTime(date.year, date.month, date.day)).inDays;
    if (diff == 0) return 'dm.today'.tr();
    if (diff == 1) return 'dm.yesterday'.tr();
    return DateFormat('d MMM y').format(date);
  }
}

// ─── Message Bubble ─────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final DmMessage message;
  final bool isMe;
  final bool isDark;
  final int friendAvatarIndex;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.isDark,
    required this.friendAvatarIndex,
  });

  @override
  Widget build(BuildContext context) {
    final avatarItem = AvatarPicker
        .avatars[friendAvatarIndex % AvatarPicker.avatars.length];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: avatarItem.accentColor.withAlpha(46),
                shape: BoxShape.circle,
                border: Border.all(color: avatarItem.accentColor, width: 1.5),
              ),
              child: Icon(avatarItem.icon,
                  color: avatarItem.accentColor, size: 16),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 9),
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.72),
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
                          offset: const Offset(0, 2))
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
                Text(_formatTime(message.createdAt),
                    style: TextStyle(
                        fontSize: 10, color: AppColors.getTextMuted(isDark))),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 6),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
