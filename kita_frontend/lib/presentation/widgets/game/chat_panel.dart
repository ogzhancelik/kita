import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../providers/online_game_provider.dart';
import 'match_elapsed_timer.dart';

/// Inline chat panel for in-game communications.
///
/// Features:
/// - When keyboard is closed: header is hidden completely, input row has no timer (timer is in bottom bar).
/// - When keyboard is open: thin compact header strip is shown, timer is shown next to message input,
///   input bar is strictly pinned to the bottom, and message list is capped to prevent ballooning.
class ChatPanel extends StatefulWidget {
  final bool isKeyboardOpen;

  const ChatPanel({
    super.key,
    this.isKeyboardOpen = false,
  });

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage(OnlineGameProvider provider) {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    provider.sendChat(text);
    _controller.clear();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OnlineGameProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.getCard(isDark),
        border: Border(
          top: BorderSide(
            color: AppColors.getBorder(isDark),
            width: 0.8,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // 1. Thin header: ONLY shown when keyboard is open
          if (widget.isKeyboardOpen)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              decoration: BoxDecoration(
                color: AppColors.getSurface(isDark),
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.getBorder(isDark),
                    width: 0.5,
                  ),
                ),
              ),
              child: SizedBox(
                height: 22,
                child: Row(
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 11,
                      color: AppColors.getTextSecondary(isDark),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'online.chat'.tr(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        color: AppColors.getTextPrimary(isDark),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: provider.toggleChat,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: AppColors.getTextMuted(isDark),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 2. Messages list (compact when typing so board stays prominent)
          Flexible(
            fit: widget.isKeyboardOpen ? FlexFit.loose : FlexFit.tight,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: widget.isKeyboardOpen ? 95 : double.infinity,
              ),
              child: ValueListenableBuilder<List<ChatMessage>>(
                valueListenable: provider.chatMessages,
                builder: (ctx, messages, _) {
                  if (messages.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          'online.noMessagesYet'.tr(),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.getTextMuted(isDark),
                          ),
                        ),
                      ),
                    );
                  }

                  _scrollToBottom();

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    itemCount: messages.length,
                    shrinkWrap: widget.isKeyboardOpen,
                    itemBuilder: (ctx, index) {
                      final msg = messages[index];
                      final isMe = msg.senderId == provider.myUserId;
                      return _ChatMessageBubble(
                        message: msg,
                        isMe: isMe,
                        isDark: isDark,
                      );
                    },
                  );
                },
              ),
            ),
          ),

          // 3. Input Row: pinned to the very bottom
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.getSurface(isDark),
              border: Border(
                top: BorderSide(
                  color: AppColors.getBorder(isDark),
                  width: 0.8,
                ),
              ),
            ),
            child: Row(
              children: [
                // Timer is ONLY shown next to text container when keyboard is open
                if (widget.isKeyboardOpen) ...[
                  const MatchElapsedTimer(),
                  const SizedBox(width: 8),
                ],

                // Type a message container
                Expanded(
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.getCard(isDark),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppColors.getBorder(isDark),
                        width: 0.8,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Center(
                      child: TextField(
                        controller: _controller,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.getTextPrimary(isDark),
                        ),
                        decoration: InputDecoration(
                          hintText: 'online.typeMessage'.tr(),
                          hintStyle: TextStyle(
                            fontSize: 12,
                            color: AppColors.getTextMuted(isDark),
                          ),
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _sendMessage(provider),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Send button
                InkWell(
                  onTap: () => _sendMessage(provider),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final bool isDark;

  const _ChatMessageBubble({
    required this.message,
    required this.isMe,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2.0),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.70,
        ),
        decoration: BoxDecoration(
          color: isMe
              ? AppColors.primaryGreen
              : AppColors.getSurface(isDark),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(10),
            topRight: const Radius.circular(10),
            bottomLeft: Radius.circular(isMe ? 10 : 2),
            bottomRight: Radius.circular(isMe ? 2 : 10),
          ),
          border: isMe
              ? null
              : Border.all(
                  color: AppColors.getBorder(isDark),
                  width: 0.5,
                ),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  message.username,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ratingGold,
                  ),
                ),
              ),
            Text(
              message.content,
              style: TextStyle(
                fontSize: 12,
                color: isMe
                    ? Colors.white
                    : AppColors.getTextPrimary(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
