import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/notification_model.dart';
import '../../providers/notification_provider.dart';

class NotificationTile extends StatefulWidget {
  final KitaNotification notification;
  final VoidCallback? onDismissed;
  final bool compact;

  const NotificationTile({
    super.key,
    required this.notification,
    this.onDismissed,
    this.compact = false,
  });

  @override
  State<NotificationTile> createState() => _NotificationTileState();
}

class _NotificationTileState extends State<NotificationTile> {
  bool _isExpanded = false;

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) {
      return 'notifications.timeAgoJustNow'.tr();
    } else if (diff.inMinutes < 60) {
      return 'notifications.timeAgoMinutes'.tr(args: ['${diff.inMinutes}']);
    } else if (diff.inHours < 24) {
      return 'notifications.timeAgoHours'.tr(args: ['${diff.inHours}']);
    } else {
      return 'notifications.timeAgoDays'.tr(args: ['${diff.inDays}']);
    }
  }

  String _formatTimeControl(int? ms) {
    if (ms == null || ms <= 0) {
      return 'notifications.matchDurationUnlimited'.tr();
    }
    final mins = ms ~/ 60000;
    return 'notifications.matchDurationMinutes'.tr(args: ['$mins']);
  }

  @override
  Widget build(BuildContext context) {
    final notification = widget.notification;
    final compact = widget.compact;
    final onDismissed = widget.onDismissed;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notifProv = context.read<NotificationProvider>();
    final isPending = notification.isPending;
    final isIgnored = notification.isIgnored;

    // Category styling
    final Color accentColor;
    final IconData iconData;
    switch (notification.type) {
      case KitaNotificationType.rematch:
        accentColor = AppColors.winBlue;
        iconData = Icons.replay_rounded;
        break;
      case KitaNotificationType.challenge:
        accentColor = AppColors.ratingGold;
        iconData = Icons.sports_esports_rounded;
        break;
      case KitaNotificationType.friendRequest:
        accentColor = AppColors.accentSecondary;
        iconData = Icons.person_add_rounded;
        break;
      case KitaNotificationType.info:
        accentColor = AppColors.accent;
        iconData = Icons.info_outline_rounded;
        break;
    }

    // Title & subtitle text resolution
    final String titleText;
    if (notification.title.startsWith('notifications.')) {
      titleText = notification.title.tr();
    } else {
      titleText = notification.title;
    }

    final String subtitleText;
    final sender = (notification.senderName != null &&
            notification.senderName!.trim().isNotEmpty)
        ? notification.senderName!
        : 'online.opponent'.tr();
    final timeStr = _formatTimeControl(notification.timeControl);

    switch (notification.type) {
      case KitaNotificationType.rematch:
        subtitleText = 'notifications.rematchSubtitle'.tr(args: [sender, timeStr]);
        break;
      case KitaNotificationType.challenge:
        subtitleText = 'notifications.challengeSubtitle'.tr(args: [sender, timeStr]);
        break;
      case KitaNotificationType.friendRequest:
        subtitleText = 'notifications.friendRequestSubtitle'.tr(args: [sender]);
        break;
      case KitaNotificationType.info:
        subtitleText = notification.subtitle;
        break;
    }

    // Tile inner card
    Widget tileContent = Container(
      margin: EdgeInsets.symmetric(vertical: compact ? 3.0 : 5.0),
      decoration: BoxDecoration(
        color: AppColors.getCard(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPending
              ? accentColor.withValues(alpha: 0.35)
              : AppColors.getBorder(isDark),
          width: isPending ? 1.2 : 1.0,
        ),
        boxShadow: isPending
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 10.0 : 12.0,
                vertical: compact ? 8.0 : 10.0,
              ),
              child: Row(
                crossAxisAlignment: _isExpanded
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.center,
                children: [
                  // Category Icon Badge
                  Container(
                    width: compact ? 36 : 40,
                    height: compact ? 36 : 40,
                    margin: _isExpanded
                        ? const EdgeInsets.only(top: 2)
                        : EdgeInsets.zero,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      iconData,
                      color: accentColor,
                      size: compact ? 20 : 22,
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Content Column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Title + Rating + Timestamp Row
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                titleText,
                                style: TextStyle(
                                  fontSize: compact ? 13 : 14,
                                  fontWeight: FontWeight.bold,
                                  color: isPending
                                      ? AppColors.getTextPrimary(isDark)
                                      : AppColors.getTextMuted(isDark),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (notification.senderRating != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.getSurface(isDark),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '★ ${notification.senderRating}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.ratingGold,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(width: 6),
                            Text(
                              _formatTimeAgo(notification.timestamp),
                              style: TextStyle(
                                fontSize: 10.5,
                                color: AppColors.getTextMuted(isDark),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),

                        // Subtitle
                        Text(
                          subtitleText,
                          style: TextStyle(
                            fontSize: compact ? 11.5 : 12.5,
                            color: isPending
                                ? AppColors.getTextSecondary(isDark)
                                : AppColors.getTextMuted(isDark),
                          ),
                          maxLines: _isExpanded ? null : 1,
                          overflow: _isExpanded
                              ? TextOverflow.visible
                              : TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Right-aligned Action Buttons or Status Badge
                  if (isPending) ...[
                    Padding(
                      padding: _isExpanded
                          ? const EdgeInsets.only(top: 2)
                          : EdgeInsets.zero,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () {
                              notifProv.declineNotification(
                                  context, notification.id);
                            },
                            tooltip: 'notifications.decline'.tr(),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: AppColors.lossRed,
                              size: 18,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor:
                                  AppColors.lossRed.withValues(alpha: 0.12),
                              padding: const EdgeInsets.all(6),
                              minimumSize: const Size(32, 32),
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            onPressed: () {
                              notifProv.acceptNotification(
                                  context, notification.id);
                            },
                            tooltip: 'notifications.accept'.tr(),
                            icon: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.accentSecondary,
                              padding: const EdgeInsets.all(6),
                              minimumSize: const Size(32, 32),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Padding(
                      padding: _isExpanded
                          ? const EdgeInsets.only(top: 4)
                          : EdgeInsets.zero,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.getSurface(isDark),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isIgnored
                              ? 'notifications.ignored'.tr()
                              : (notification.isExpired ||
                                      notification.status ==
                                          NotificationStatus.expired)
                                  ? 'notifications.expired'.tr()
                                  : notification.status ==
                                          NotificationStatus.accepted
                                      ? 'notifications.accept'.tr()
                                      : notification.status ==
                                              NotificationStatus.declined
                                          ? 'notifications.decline'.tr()
                                          : 'notifications.read'.tr(),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.getTextMuted(isDark),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // Apply reduced opacity for ignored or read notifications
    if (!isPending) {
      tileContent = Opacity(
        opacity: 0.55,
        child: tileContent,
      );
    }

    // Dismissible wrapper for swipe-to-ignore
    return Dismissible(
      key: ValueKey('notif_${notification.id}_${notification.status.name}'),
      direction: isPending ? DismissDirection.horizontal : DismissDirection.none,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        margin: EdgeInsets.symmetric(vertical: compact ? 3.0 : 5.0),
        decoration: BoxDecoration(
          color: AppColors.lossRed.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.visibility_off_rounded, color: AppColors.lossRed, size: 20),
            const SizedBox(width: 8),
            Text(
              'notifications.ignore'.tr(),
              style: const TextStyle(
                color: AppColors.lossRed,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        margin: EdgeInsets.symmetric(vertical: compact ? 3.0 : 5.0),
        decoration: BoxDecoration(
          color: AppColors.lossRed.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'notifications.ignore'.tr(),
              style: const TextStyle(
                color: AppColors.lossRed,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.visibility_off_rounded, color: AppColors.lossRed, size: 20),
          ],
        ),
      ),
      onDismissed: (direction) {
        notifProv.ignoreNotification(notification.id);
        onDismissed?.call();
      },
      child: tileContent,
    );
  }
}
