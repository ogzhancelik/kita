import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/feedback/toast_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/online_game_provider.dart';

/// Helper and dialog to ensure mutual exclusivity across:
/// 1. Active Game (Hard Lock)
/// 2. Hosting an Open Room (Soft Lock)
/// 3. Pending Outgoing Challenge (Soft Lock)
/// 4. Matchmaking Queue (Soft Lock)
class ActivityConflictHelper {
  ActivityConflictHelper._();

  /// Checks if the user is currently engaged in any conflicting activity.
  /// If in an active match, blocks immediately with a toast.
  /// If in a soft activity (room, challenge, queue), presents a clear confirmation prompt.
  /// If confirmed, automatically cleans up the conflicting state and returns true.
  /// If cancelled, leaves state untouched and returns false.
  static Future<bool> checkAndConfirm({
    required BuildContext context,
    required OnlineGameProvider provider,
    String? customMessage,
  }) async {
    // 1. Active Match in progress
    if (provider.matchState.value == OnlineMatchState.inMatch) {
      if (!provider.isOffline) {
        // Hard Lock: Real online opponent match
        KitaToast.warning('online.conflictInMatchDesc'.tr());
        return false;
      }
      // Soft Lock: Offline match vs AI or local coop -> confirmation prompt to resign & proceed
      final confirmed = await _showConfirmDialog(
        context: context,
        title: 'online.conflictDialogTitle'.tr(),
        message: customMessage ?? 'online.conflictAbandonOfflineDesc'.tr(),
        confirmLabel: 'online.abandonAndProceed'.tr(),
      );
      if (confirmed) {
        provider.resignAndClear();
        return true;
      }
      return false;
    }

    // 2. Soft Lock: Hosting an Open Waiting Room
    final roomCode = provider.currentRoomCode;
    if (roomCode != null && roomCode.isNotEmpty) {
      final confirmed = await _showConfirmDialog(
        context: context,
        title: 'online.conflictDialogTitle'.tr(),
        message: customMessage ?? 'online.conflictCloseRoomDesc'.tr(args: [roomCode]),
        confirmLabel: 'online.closeAndProceed'.tr(),
      );
      if (confirmed) {
        provider.leaveRoom();
        return true;
      }
      return false;
    }

    // 3. Soft Lock: Pending Outgoing Challenge
    final outgoing = provider.pendingOutgoingChallenge.value;
    if (outgoing != null) {
      final friendName = outgoing.friendName.isNotEmpty ? outgoing.friendName : 'Friend';
      final confirmed = await _showConfirmDialog(
        context: context,
        title: 'online.conflictDialogTitle'.tr(),
        message: customMessage ?? 'online.conflictCancelChallengeDesc'.tr(args: [friendName]),
        confirmLabel: 'online.cancelAndProceed'.tr(),
      );
      if (confirmed) {
        provider.cancelOutgoingChallenge();
        return true;
      }
      return false;
    }

    // 4. Soft Lock: In Matchmaking Queue
    if (provider.matchState.value == OnlineMatchState.inQueue) {
      final confirmed = await _showConfirmDialog(
        context: context,
        title: 'online.conflictDialogTitle'.tr(),
        message: customMessage ?? 'online.conflictLeaveQueueDesc'.tr(),
        confirmLabel: 'online.leaveAndProceed'.tr(),
      );
      if (confirmed) {
        provider.leaveQueue();
        return true;
      }
      return false;
    }

    // No conflicting activity -> safe to proceed
    return true;
  }

  static Future<bool> _showConfirmDialog({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: AppColors.getCard(isDark),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.guestOrange.withValues(alpha: 0.15),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.guestOrange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getTextPrimary(isDark),
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: AppColors.getTextSecondary(isDark),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: Text(
                'online.cancel'.tr(),
                style: TextStyle(
                  color: AppColors.getTextSecondary(isDark),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: AppColors.darkTextPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: Text(
                confirmLabel,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }
}
