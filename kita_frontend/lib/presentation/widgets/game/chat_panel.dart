import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../providers/online_game_provider.dart';

/// Slide-over / floating chat panel for in-game communications.
class ChatPanel extends StatefulWidget {
  const ChatPanel({super.key});

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
    if (!provider.isChatOpen) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned(
      bottom: 56, // Sits above the control bar
      left: 12,
      right: 12,
      height: 280,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        color: AppColors.getCard(isDark),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.getBorder(isDark)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.getSurface(isDark),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 16,
                      color: AppColors.getTextSecondary(isDark),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'online.chat'.tr(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.getTextPrimary(isDark),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      color: AppColors.getTextMuted(isDark),
                      onPressed: provider.toggleChat,
                    ),
                  ],
                ),
              ),

              // Messages List
              Expanded(
                child: ValueListenableBuilder<List<ChatMessage>>(
                  valueListenable: provider.chatMessages,
                  builder: (ctx, messages, _) {
                    if (messages.isEmpty) {
                      return Center(
                        child: Text(
                          'online.noMessagesYet'.tr(),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.getTextMuted(isDark),
                          ),
                        ),
                      );
                    }

                    _scrollToBottom();

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      itemCount: messages.length,
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

              // Input Row
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: AppColors.getBorder(isDark),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.getTextPrimary(isDark),
                        ),
                        decoration: InputDecoration(
                          hintText: 'online.typeMessage'.tr(),
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: AppColors.getTextMuted(isDark),
                          ),
                          filled: true,
                          fillColor: AppColors.getSurface(isDark),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(provider),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send_rounded, size: 20),
                      color: AppColors.primaryGreen,
                      onPressed: () => _sendMessage(provider),
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
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.65,
        ),
        decoration: BoxDecoration(
          color: isMe
              ? AppColors.primaryGreen
              : AppColors.getSurface(isDark),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(isMe ? 12 : 2),
            bottomRight: Radius.circular(isMe ? 2 : 12),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Text(
                message.username,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ratingGold,
                ),
              ),
            Text(
              message.content,
              style: TextStyle(
                fontSize: 13,
                color: isMe
                    ? AppColors.darkTextPrimary
                    : AppColors.getTextPrimary(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
