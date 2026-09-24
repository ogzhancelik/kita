import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/ws_message_models.dart';
import '../../providers/online_game_provider.dart';
import '../../screens/game/online_match_screen.dart';
import '../common/avatar_picker.dart';

/// Modal dialog presented when a friend challenges the user to a match.
class MatchInvitationDialog extends StatelessWidget {
  final MatchInvitationPayload invitation;

  const MatchInvitationDialog({super.key, required this.invitation});

  static void showIfInvited(BuildContext context, MatchInvitationPayload? invite) {
    if (invite == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => MatchInvitationDialog(invitation: invite),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OnlineGameProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inviterAvatar = AvatarPicker.avatars[
        invitation.inviterAvatarIndex % AvatarPicker.avatars.length];

    // Auto-navigate to match screen when match starts
    if (provider.matchState.value == OnlineMatchState.inMatch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        final route = ModalRoute.of(context);
        if (route != null && route.isActive) {
          Navigator.of(context).removeRoute(route);
        }
        if (!OnlineMatchScreen.isMatchScreenOpen) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const OnlineMatchScreen(),
              settings: const RouteSettings(name: '/online_match'),
            ),
          );
        }
      });
    }

    final mins = invitation.timeControl ~/ 60000;
    final timeStr = invitation.timeControl == 0
        ? 'online.timeUnlimited'.tr()
        : 'online.minuteShort'.tr(args: ['$mins']);

    final String sideLabel;
    final IconData sideIcon;
    if (invitation.colorPreference == 'white') {
      sideLabel = 'online.invitationSideBlack'.tr();
      sideIcon = Icons.circle_outlined;
    } else if (invitation.colorPreference == 'black') {
      sideLabel = 'online.invitationSideWhite'.tr();
      sideIcon = Icons.circle;
    } else {
      sideLabel = 'online.invitationSideRandom'.tr();
      sideIcon = Icons.shuffle_rounded;
    }

    return AlertDialog(
      backgroundColor: AppColors.getCard(isDark),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      title: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: inviterAvatar.accentColor.withValues(alpha: 0.18),
              border: Border.all(
                color: inviterAvatar.accentColor,
                width: 2.0,
              ),
            ),
            child: Icon(
              inviterAvatar.icon,
              size: 40,
              color: inviterAvatar.accentColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'online.inviteReceived'.tr(args: [invitation.inviterName]),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.getTextPrimary(isDark),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.getSurface(isDark),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.getBorder(isDark)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      '${invitation.inviterRating}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.ratingGold,
                      ),
                    ),
                    Text(
                      'Rating',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.getTextMuted(isDark),
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 1,
                  height: 28,
                  color: AppColors.getBorder(isDark),
                ),
                Column(
                  children: [
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.getTextPrimary(isDark),
                      ),
                    ),
                    Text(
                      'TimeControl',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.getTextMuted(isDark),
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 1,
                  height: 28,
                  color: AppColors.getBorder(isDark),
                ),
                Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(sideIcon, size: 14, color: AppColors.primaryGreen),
                        const SizedBox(width: 4),
                        Text(
                          sideLabel,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppColors.getTextPrimary(isDark),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'side'.tr(),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.getTextMuted(isDark),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            provider.declineInvitation(invitation.inviteId);
            Navigator.of(context).pop();
          },
          child: Text(
            'online.decline'.tr(),
            style: const TextStyle(color: AppColors.lossRed),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            provider.acceptInvitation(invitation.inviteId);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentSecondary,
            foregroundColor: AppColors.darkTextPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text('online.accept'.tr()),
        ),
      ],
    );
  }
}
