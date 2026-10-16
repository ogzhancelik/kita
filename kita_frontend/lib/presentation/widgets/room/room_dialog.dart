import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/ws_message_models.dart';
import '../../providers/online_game_provider.dart';
import '../../screens/game/online_match_screen.dart';
import '../../screens/game/ready_phase_screen.dart';
import '../matchmaking/activity_conflict_dialog.dart';
import 'room_waiting_visualizer.dart';

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
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CreateRoomDialog(),
    );

    // If dialog was closed because ready phase or match started, navigate accordingly
    if (provider.matchState.value == OnlineMatchState.readyPhase &&
        context.mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const ReadyPhaseScreen(),
          settings: const RouteSettings(name: '/ready_phase'),
        ),
      );
    } else if (provider.matchState.value == OnlineMatchState.inMatch &&
        context.mounted &&
        !OnlineMatchScreen.isMatchScreenOpen) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const OnlineMatchScreen(),
          settings: const RouteSettings(name: '/online_match'),
        ),
      );
    }
  }

  @override
  State<CreateRoomDialog> createState() => _CreateRoomDialogState();
}

class _CreateRoomDialogState extends State<CreateRoomDialog> {
  int _selectedTimeControl = TimeControlPreset.threeMin;
  bool _isPrivate = false;
  bool _isSubmitting = false;
  OnlineGameProvider? _provider;

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final prov = context.read<OnlineGameProvider>();
    if (_provider != prov) {
      _provider?.matchState.removeListener(_onMatchStateChanged);
      _provider = prov;
      _provider?.matchState.addListener(_onMatchStateChanged);
    }
  }

  @override
  void dispose() {
    _provider?.matchState.removeListener(_onMatchStateChanged);
    super.dispose();
  }

  void _onMatchStateChanged() {
    if (!mounted) return;
    if (_provider?.matchState.value == OnlineMatchState.inMatch ||
        _provider?.matchState.value == OnlineMatchState.readyPhase) {
      final route = ModalRoute.of(context);
      if (route != null && route.isActive) {
        Navigator.of(context).removeRoute(route);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OnlineGameProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Safety fallback: ensure dialog route is removed when match or ready phase begins
    if (provider.matchState.value == OnlineMatchState.inMatch ||
        provider.matchState.value == OnlineMatchState.readyPhase) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final route = ModalRoute.of(context);
          if (route != null && route.isActive) {
            Navigator.of(context).removeRoute(route);
          }
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
                  matchState == OnlineMatchState.inRoom &&
                  code != null &&
                  code.isNotEmpty;

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

          // Time control 2x2 grid
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildTimeOption(
                      label: TimeControlPreset.format(
                        TimeControlPreset.defaultPresets[0],
                      ),
                      value: TimeControlPreset.defaultPresets[0],
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildTimeOption(
                      label: TimeControlPreset.format(
                        TimeControlPreset.defaultPresets[1],
                      ),
                      value: TimeControlPreset.defaultPresets[1],
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildTimeOption(
                      label: TimeControlPreset.format(
                        TimeControlPreset.defaultPresets[2],
                      ),
                      value: TimeControlPreset.defaultPresets[2],
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildTimeOption(
                      label: TimeControlPreset.format(
                        TimeControlPreset.defaultPresets[3],
                      ),
                      value: TimeControlPreset.defaultPresets[3],
                      isDark: isDark,
                    ),
                  ),
                ],
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
            activeThumbColor: AppColors.primaryAmber,
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
                  'common.cancel'.tr(),
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
                  backgroundColor: AppColors.primaryAmber,
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
    return RoomWaitingVisualizer(
      roomCode: code,
      timeControl: provider.roomTimeControl,
      isPrivate: provider.isRoomPrivate,
      onKeepInBackground: () => Navigator.of(context).pop(),
      onCancelRoom: () {
        provider.leaveRoom();
        Navigator.of(context).pop();
      },
    );
  }

  Widget _buildTimeOption({
    required String label,
    required int value,
    required bool isDark,
  }) {
    final isSelected = _selectedTimeControl == value;
    return InkWell(
      onTap: () => setState(() => _selectedTimeControl = value),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryAmber.withValues(alpha: 0.15)
              : AppColors.getSurface(isDark),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryAmber
                : AppColors.getBorder(isDark),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? AppColors.primaryAmber
                  : AppColors.getTextPrimary(isDark),
            ),
          ),
        ),
      ),
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
    await showDialog(context: context, builder: (_) => const JoinRoomDialog());

    // If dialog was closed because ready phase or match started, navigate accordingly
    if (provider.matchState.value == OnlineMatchState.readyPhase &&
        context.mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const ReadyPhaseScreen(),
          settings: const RouteSettings(name: '/ready_phase'),
        ),
      );
    } else if (provider.matchState.value == OnlineMatchState.inMatch &&
        context.mounted &&
        !OnlineMatchScreen.isMatchScreenOpen) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const OnlineMatchScreen(),
          settings: const RouteSettings(name: '/online_match'),
        ),
      );
    }
  }

  @override
  State<JoinRoomDialog> createState() => _JoinRoomDialogState();
}

class _JoinRoomDialogState extends State<JoinRoomDialog> {
  final TextEditingController _codeController = TextEditingController();
  bool _isSubmitting = false;
  OnlineGameProvider? _provider;

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final prov = context.read<OnlineGameProvider>();
    if (_provider != prov) {
      _provider?.matchState.removeListener(_onMatchStateChanged);
      _provider = prov;
      _provider?.matchState.addListener(_onMatchStateChanged);
    }
  }

  @override
  void dispose() {
    _provider?.matchState.removeListener(_onMatchStateChanged);
    _codeController.dispose();
    super.dispose();
  }

  void _onMatchStateChanged() {
    if (!mounted) return;
    if (_provider?.matchState.value == OnlineMatchState.inMatch ||
        _provider?.matchState.value == OnlineMatchState.readyPhase) {
      final route = ModalRoute.of(context);
      if (route != null && route.isActive) {
        Navigator.of(context).removeRoute(route);
      }
    }
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

    // Safety fallback: ensure dialog route is removed when match or ready phase begins
    if (provider.matchState.value == OnlineMatchState.inMatch ||
        provider.matchState.value == OnlineMatchState.readyPhase) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final route = ModalRoute.of(context);
          if (route != null && route.isActive) {
            Navigator.of(context).removeRoute(route);
          }
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
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'common.cancel'.tr(),
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
            backgroundColor: AppColors.primaryAmber,
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
