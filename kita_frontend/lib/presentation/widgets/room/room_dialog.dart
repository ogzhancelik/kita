import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/ws_message_models.dart';
import '../../providers/online_game_provider.dart';
import '../../screens/game/online_match_screen.dart';
import '../matchmaking/activity_conflict_dialog.dart';

/// Dialog to create a custom game room with time control and private options.
class CreateRoomDialog extends StatefulWidget {
  const CreateRoomDialog({super.key});

  static Future<void> show(BuildContext context) async {
    final provider = context.read<OnlineGameProvider>();
    final canProceed = await ActivityConflictHelper.checkAndConfirm(
      context: context,
      provider: provider,
    );
    if (!canProceed) return;

    if (!context.mounted) return;
    // If not already in an active waiting room, clean slate
    if (provider.matchState.value != OnlineMatchState.inRoom) {
      provider.resetToIdle();
    }
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CreateRoomDialog(),
    );
  }

  @override
  State<CreateRoomDialog> createState() => _CreateRoomDialogState();
}

class _CreateRoomDialogState extends State<CreateRoomDialog> {
  int _selectedTimeControl = TimeControlPreset.threeMin;
  bool _isPrivate = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<OnlineGameProvider>().clearError();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OnlineGameProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Auto-navigate to match screen when match begins
    if (provider.matchState.value == OnlineMatchState.inMatch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const OnlineMatchScreen(),
            ),
          );
        }
      });
    }

    return PopScope(
      canPop: true,
      child: ValueListenableBuilder<OnlineMatchState>(
        valueListenable: provider.matchState,
        builder: (context, matchState, _) {
          return ValueListenableBuilder<String?>(
            valueListenable: provider.roomCode,
            builder: (context, code, _) {
              final isWaiting =
                  matchState == OnlineMatchState.inRoom && code != null && code.isNotEmpty;

              if (isWaiting && _isSubmitting) {
                _isSubmitting = false;
              }

              return Dialog(
                backgroundColor: AppColors.getCard(isDark),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    child: isWaiting
                        ? _buildWaitingContent(context, provider, isDark, code)
                        : _buildCreateContent(context, provider, isDark),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCreateContent(
    BuildContext context,
    OnlineGameProvider provider,
    bool isDark,
  ) {
    final errorMessage = provider.lastError.value?.message;

    return Container(
      key: const ValueKey('create_room_content'),
      padding: const EdgeInsets.all(24),
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dialog Title
          Text(
            'online.createRoom'.tr(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.getTextPrimary(isDark),
            ),
          ),
          const SizedBox(height: 18),

          // Time control label
          Text(
            'online.selectTimeControl'.tr(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.getTextSecondary(isDark),
            ),
          ),
          const SizedBox(height: 10),

          // Time control chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTimeChip(
                label: 'online.timeBullet'.tr(),
                value: TimeControlPreset.oneMin,
                isDark: isDark,
              ),
              _buildTimeChip(
                label: 'online.timeBlitz'.tr(),
                value: TimeControlPreset.threeMin,
                isDark: isDark,
              ),
              _buildTimeChip(
                label: 'online.timeRapid'.tr(),
                value: TimeControlPreset.fiveMin,
                isDark: isDark,
              ),
              _buildTimeChip(
                label: 'online.timeUnlimited'.tr(),
                value: TimeControlPreset.unlimited,
                isDark: isDark,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Private room switch
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'online.privateRoom'.tr(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.getTextPrimary(isDark),
              ),
            ),
            subtitle: Text(
              'online.privateRoomDesc'.tr(),
              style: TextStyle(
                fontSize: 12,
                color: AppColors.getTextMuted(isDark),
              ),
            ),
            value: _isPrivate,
            activeThumbColor: AppColors.primaryGreen,
            onChanged: (val) => setState(() => _isPrivate = val),
          ),

          if (errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.lossRed.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.lossRed.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                errorMessage,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.lossRed,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  provider.leaveRoom();
                  Navigator.of(context).pop();
                },
                child: Text(
                  'online.cancel'.tr(),
                  style: TextStyle(color: AppColors.getTextSecondary(isDark)),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _isSubmitting
                    ? null
                    : () {
                        setState(() => _isSubmitting = true);
                        provider.createRoom(
                          isPrivate: _isPrivate,
                          timeControl: _selectedTimeControl,
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: AppColors.darkTextPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.darkTextPrimary,
                        ),
                      )
                    : Text('online.create'.tr()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingContent(
    BuildContext context,
    OnlineGameProvider provider,
    bool isDark,
    String code,
  ) {
    return Container(
      key: const ValueKey('room_waiting_content'),
      padding: const EdgeInsets.all(24),
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'online.roomCreatedTitle'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.getTextPrimary(isDark),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'online.shareRoomCode'.tr(),
            style: TextStyle(
              fontSize: 13,
              color: AppColors.getTextSecondary(isDark),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Room Code Card with copy
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('online.codeCopied'.tr()),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.getSurface(isDark),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primaryGreen,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    code,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Icon(
                    Icons.copy_rounded,
                    size: 22,
                    color: AppColors.primaryGreen,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          const CircularProgressIndicator(color: AppColors.primaryGreen),
          const SizedBox(height: 16),

          Text(
            'online.waitingForOpponent'.tr(),
            style: TextStyle(
              fontSize: 13,
              color: AppColors.getTextMuted(isDark),
            ),
          ),
          const SizedBox(height: 20),

          // Action Buttons: Close (keep in background) & Cancel Room
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                label: Text('online.keepRoomInBackground'.tr()),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.getTextSecondary(isDark),
                ),
              ),
              TextButton(
                onPressed: () {
                  provider.leaveRoom();
                  Navigator.of(context).pop();
                },
                child: Text(
                  'online.cancelRoom'.tr(),
                  style: const TextStyle(
                    color: AppColors.lossRed,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeChip({
    required String label,
    required int value,
    required bool isDark,
  }) {
    final isSelected = _selectedTimeControl == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected
              ? AppColors.darkTextPrimary
              : AppColors.getTextPrimary(isDark),
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.primaryGreen,
      backgroundColor: AppColors.getSurface(isDark),
      onSelected: (_) => setState(() => _selectedTimeControl = value),
    );
  }
}

/// Dialog for entering a room code to join an existing game.
class JoinRoomDialog extends StatefulWidget {
  const JoinRoomDialog({super.key});

  static Future<void> show(BuildContext context) async {
    final provider = context.read<OnlineGameProvider>();
    final canProceed = await ActivityConflictHelper.checkAndConfirm(
      context: context,
      provider: provider,
    );
    if (!canProceed) return;

    if (!context.mounted) return;
    return showDialog(
      context: context,
      builder: (_) => const JoinRoomDialog(),
    );
  }

  @override
  State<JoinRoomDialog> createState() => _JoinRoomDialogState();
}

class _JoinRoomDialogState extends State<JoinRoomDialog> {
  final TextEditingController _codeController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<OnlineGameProvider>().clearError();
      }
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OnlineGameProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Reset submit state if error occurs or match begins
    if (_isSubmitting &&
        (provider.lastError.value != null ||
            provider.matchState.value == OnlineMatchState.inMatch)) {
      _isSubmitting = false;
    }

    // Auto-navigate to match screen when match starts
    if (provider.matchState.value == OnlineMatchState.inMatch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const OnlineMatchScreen(),
            ),
          );
        }
      });
    }

    final errorMessage = provider.lastError.value?.message;

    return AlertDialog(
      backgroundColor: AppColors.getCard(isDark),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'online.joinRoom'.tr(),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.getTextPrimary(isDark),
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
            ),
            decoration: InputDecoration(
              hintText: 'ABCD12',
              hintStyle: TextStyle(
                color: AppColors.getTextMuted(isDark),
                letterSpacing: 4,
              ),
              counterText: '',
              filled: true,
              fillColor: AppColors.getSurface(isDark),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.lossRed.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.lossRed.withValues(alpha: 0.4)),
              ),
              child: Text(
                errorMessage,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.lossRed,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'online.cancel'.tr(),
            style: TextStyle(color: AppColors.getTextSecondary(isDark)),
          ),
        ),
        ElevatedButton(
          onPressed: _isSubmitting
              ? null
              : () {
                  final code = _codeController.text.trim();
                  if (code.length >= 4) {
                    setState(() => _isSubmitting = true);
                    provider.joinRoom(code);
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
            foregroundColor: AppColors.darkTextPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.darkTextPrimary,
                  ),
                )
              : Text('online.join'.tr()),
        ),
      ],
    );
  }
}
