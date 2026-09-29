import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/dm_models.dart';
import '../../providers/dm_provider.dart';


/// An expandable game card shown inside a DM conversation when two friends
/// have played a match against each other.
///
/// Collapsed: shows the result badge, date, and a chevron to expand.
/// Expanded: shows the in-game chat messages from that match.
class MatchChatCardWidget extends StatefulWidget {
  final MatchChatCard match;
  final bool isDark;
  final String myUserId;
  final String friendUsername;
  final String myUsername;

  const MatchChatCardWidget({
    super.key,
    required this.match,
    required this.isDark,
    required this.myUserId,
    required this.friendUsername,
    required this.myUsername,
  });

  @override
  State<MatchChatCardWidget> createState() => _MatchChatCardWidgetState();
}

class _MatchChatCardWidgetState extends State<MatchChatCardWidget>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _toggle() {
    if (!_expanded) {
      // Lazy-load in-game messages
      context.read<DmProvider>().loadInGameMessages(widget.match.matchId);
      _animController.forward();
    } else {
      _animController.reverse();
    }
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final result = _resultLabel();
    final resultColor = _resultColor();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          decoration: BoxDecoration(
            color: AppColors.getCard(isDark),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: resultColor.withAlpha(80),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(15),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Header (always visible) ────────────────────────────
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _toggle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      // Result badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: resultColor.withAlpha(30),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: resultColor.withAlpha(80), width: 1),
                        ),
                        child: Text(
                          result,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: resultColor,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'dm.matchVs'.tr(args: [widget.friendUsername]),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.getTextPrimary(isDark),
                              ),
                            ),
                            Text(
                              _formatDate(widget.match.playedAt),
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.getTextMuted(isDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Expand/collapse icon
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.expand_more_rounded,
                          color: AppColors.getTextMuted(isDark),
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ─── Expanded chat messages ──────────────────────────────
              if (_expanded) ...[
                Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.getBorder(isDark)),
                Consumer<DmProvider>(
                  builder: (context, dmProv, _) {
                    if (dmProv.isInGameLoading(widget.match.matchId)) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        ),
                      );
                    }

                    final msgs = dmProv.inGameMessagesFor(
                            widget.match.matchId) ??
                        [];

                    if (msgs.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'dm.noInGameChat'.tr(),
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.getTextMuted(isDark),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    return FadeTransition(
                      opacity: _fadeAnim,
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        itemCount: msgs.length,
                        itemBuilder: (ctx, i) {
                          final msg = msgs[i];
                          final isMe = msg.senderId == widget.myUserId;
                          return _InGameBubble(
                            message: msg,
                            isMe: isMe,
                            isDark: isDark,
                            senderName: isMe
                                ? widget.myUsername
                                : widget.friendUsername,
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _resultLabel() {
    final m = widget.match;
    if (m.winnerId == null || m.result == 'draw') {
      return 'dm.matchDraw'.tr();
    }
    if (m.winnerId == widget.myUserId) return 'dm.matchWon'.tr();
    return 'dm.matchLost'.tr();
  }

  Color _resultColor() {
    final m = widget.match;
    if (m.winnerId == null || m.result == 'draw') return AppColors.ratingGold;
    if (m.winnerId == widget.myUserId) return AppColors.winGreen;
    return AppColors.lossRed;
  }

  String _formatDate(DateTime dt) {
    return DateFormat('d MMM y • HH:mm').format(dt);
  }
}

// ─── Compact in-game bubble ─────────────────────────────────────────────────

class _InGameBubble extends StatelessWidget {
  final InGameMessage message;
  final bool isMe;
  final bool isDark;
  final String senderName;

  const _InGameBubble({
    required this.message,
    required this.isMe,
    required this.isDark,
    required this.senderName,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(
                senderName,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.getTextMuted(isDark),
                ),
              ),
            ),
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.6,
              ),
              decoration: BoxDecoration(
                color: isMe
                    ? AppColors.primary.withAlpha(200)
                    : AppColors.getSurface(isDark),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: Radius.circular(isMe ? 12 : 3),
                  bottomRight: Radius.circular(isMe ? 3 : 12),
                ),
              ),
              child: Text(
                message.content,
                style: TextStyle(
                  color: isMe
                      ? AppColors.darkTextPrimary
                      : AppColors.getTextPrimary(isDark),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (isMe)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text(
                senderName,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.getTextMuted(isDark),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
