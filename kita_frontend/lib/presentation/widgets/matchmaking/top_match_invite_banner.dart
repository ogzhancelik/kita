import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/ws_message_models.dart';

/// Top-of-screen slide-down notification dialog for incoming match challenges
/// and rematch offers. Bounded, overflow-free, works across all devices.
class TopMatchInviteDialog extends StatefulWidget {
  final IncomingMatchRequest request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onTimeout;

  const TopMatchInviteDialog({
    super.key,
    required this.request,
    required this.onAccept,
    required this.onDecline,
    required this.onTimeout,
  });

  /// Displays the invite as a top-anchored slide-down dialog.
  static Future<void> show({
    required BuildContext context,
    required IncomingMatchRequest request,
    required VoidCallback onAccept,
    required VoidCallback onDecline,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 280),
      transitionBuilder: (ctx, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1.1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: anim1,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          )),
          child: FadeTransition(
            opacity: anim1,
            child: child,
          ),
        );
      },
      pageBuilder: (dialogCtx, anim1, anim2) {
        return Align(
          alignment: Alignment.topCenter,
          child: SafeArea(
            bottom: false,
            child: Material(
              type: MaterialType.transparency,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: TopMatchInviteDialog(
                  request: request,
                  onAccept: () {
                    if (dialogCtx.mounted) {
                      Navigator.of(dialogCtx, rootNavigator: true).pop();
                    }
                    onAccept();
                  },
                  onDecline: () {
                    if (dialogCtx.mounted) {
                      Navigator.of(dialogCtx, rootNavigator: true).pop();
                    }
                    onDecline();
                  },
                  onTimeout: () {
                    if (dialogCtx.mounted) {
                      Navigator.of(dialogCtx, rootNavigator: true).pop();
                    }
                    onDecline();
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  State<TopMatchInviteDialog> createState() => _TopMatchInviteDialogState();
}

class _TopMatchInviteDialogState extends State<TopMatchInviteDialog> {
  Timer? _progressTimer;
  Timer? _timeoutTimer;
  double _remainingProgress = 1.0;
  static const int _timeoutSeconds = 20;

  @override
  void initState() {
    super.initState();
    const tickInterval = Duration(milliseconds: 100);
    final totalTicks = (_timeoutSeconds * 1000) ~/ tickInterval.inMilliseconds;
    int currentTick = 0;

    _progressTimer = Timer.periodic(tickInterval, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      currentTick++;
      setState(() {
        _remainingProgress = (totalTicks - currentTick) / totalTicks;
      });
      if (currentTick >= totalTicks) {
        timer.cancel();
      }
    });

    _timeoutTimer = Timer(const Duration(seconds: _timeoutSeconds), () {
      if (mounted) {
        widget.onTimeout();
      }
    });
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final req = widget.request;
    final isRematch = req.type == IncomingMatchRequestType.rematch;

    final mins = req.timeControl ~/ 60000;
    final timeStr = req.timeControl == 0
        ? 'online.timeUnlimited'.tr()
        : '$mins min';

    final title = isRematch
        ? 'online.rematchOfferTitle'.tr()
        : 'online.friendInviteTitle'.tr();

    final String sideInfo;
    if (req.colorPreference == 'white') {
      sideInfo = 'online.invitationSideBlack'.tr();
    } else if (req.colorPreference == 'black') {
      sideInfo = 'online.invitationSideWhite'.tr();
    } else {
      sideInfo = 'online.invitationSideRandom'.tr();
    }

    final subtitle = isRematch
        ? 'online.rematchOfferSubtitle'.tr(args: [req.senderName, timeStr])
        : '${'online.friendInviteSubtitle'.tr(args: [req.senderName, timeStr])} • $sideInfo';

    final accentColor = isRematch ? AppColors.winBlue : AppColors.ratingGold;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.getCard(isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.6),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  children: [
                    // Badge Icon
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isRematch
                            ? Icons.replay_rounded
                            : Icons.sports_esports_rounded,
                        color: accentColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Title & details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: accentColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.getSurface(isDark),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '★ ${req.senderRating}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.ratingGold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.getTextSecondary(isDark),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Decline button
                    IconButton(
                      onPressed: widget.onDecline,
                      tooltip: 'online.decline'.tr(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.lossRed,
                        size: 20,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor:
                            AppColors.lossRed.withValues(alpha: 0.12),
                        padding: const EdgeInsets.all(6),
                        minimumSize: const Size(36, 36),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Accept button
                    ElevatedButton.icon(
                      onPressed: widget.onAccept,
                      icon: const Icon(
                        Icons.check_rounded,
                        size: 16,
                      ),
                      label: Text('online.accept'.tr()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 20s progress bar
              LinearProgressIndicator(
                value: _remainingProgress.clamp(0.0, 1.0),
                minHeight: 3,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(
                  accentColor.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
