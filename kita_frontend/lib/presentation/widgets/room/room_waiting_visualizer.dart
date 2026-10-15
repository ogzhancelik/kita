import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/feedback/haptic_service.dart';
import '../../../core/theme/app_colors.dart';

/// Dynamic animated visualizer for room waiting state, featuring radar pulse rings,
/// live elapsed timer, room badges, and copy/share capabilities.
class RoomWaitingVisualizer extends StatefulWidget {
  final String roomCode;
  final int timeControl;
  final bool isPrivate;
  final VoidCallback onKeepInBackground;
  final VoidCallback onCancelRoom;

  const RoomWaitingVisualizer({
    super.key,
    required this.roomCode,
    required this.timeControl,
    required this.isPrivate,
    required this.onKeepInBackground,
    required this.onCancelRoom,
  });

  @override
  State<RoomWaitingVisualizer> createState() => _RoomWaitingVisualizerState();
}

class _RoomWaitingVisualizerState extends State<RoomWaitingVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  Timer? _elapsedTimer;
  int _secondsElapsed = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _secondsElapsed++);
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _elapsedTimer?.cancel();
    super.dispose();
  }

  String _formatElapsed(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(1, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatTimeControl(int ms) {
    if (ms <= 0) return 'online.roomBadgeNoClock'.tr();
    final minutes = ms ~/ 60000;
    return 'online.timeMinutes'.tr(args: ['$minutes']);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      key: const ValueKey('room_waiting_content'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      constraints: const BoxConstraints(maxWidth: 420),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Radar Pulse Animation Area
            SizedBox(
              height: 102,
              child: Center(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, _) {
                    final progress = _pulseController.value;
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Ring 3 (Outer most)
                        _buildPulseRing(
                          progress: (progress + 0.66) % 1.0,
                          maxRadius: 46,
                          color: AppColors.primaryAmber,
                        ),
                        // Ring 2 (Middle)
                        _buildPulseRing(
                          progress: (progress + 0.33) % 1.0,
                          maxRadius: 36,
                          color: AppColors.primaryAmber,
                        ),
                        // Ring 1 (Inner)
                        _buildPulseRing(
                          progress: progress,
                          maxRadius: 26,
                          color: AppColors.primaryAmber,
                        ),
                        // Central Beacon Badge
                        Transform.scale(
                          scale: 1.0 + (progress < 0.5 ? progress * 0.08 : (1.0 - progress) * 0.08),
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primaryAmber,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryAmber.withValues(alpha: 0.35),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.sensors_rounded,
                            size: 28,
                            color: AppColors.darkTextPrimary,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 8),

          // 2. Titles & Status
          Text(
            'online.roomWaitingTitle'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.getTextPrimary(isDark),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'online.roomWaitingSubtitle'.tr(),
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.getTextSecondary(isDark),
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          // 3. Room Setting Chips & Live Timer Row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildBadgeChip(
                icon: Icons.timer_outlined,
                label: _formatTimeControl(widget.timeControl),
                isDark: isDark,
              ),
              _buildBadgeChip(
                icon: widget.isPrivate ? Icons.lock_outline_rounded : Icons.public_rounded,
                label: widget.isPrivate
                    ? 'online.roomBadgePrivate'.tr()
                    : 'online.roomBadgePublic'.tr(),
                isDark: isDark,
              ),
              _buildBadgeChip(
                icon: Icons.hourglass_top_rounded,
                label: _formatElapsed(_secondsElapsed),
                isDark: isDark,
                highlightColor: AppColors.primaryAmber,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 4. Room Code Card with tap-to-copy
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: widget.roomCode));
              HapticService.instance.light();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('online.codeCopied'.tr()),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.getSurface(isDark),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primaryAmber, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryAmber.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.roomCode,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4,
                      color: AppColors.primaryAmber,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryAmber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.copy_rounded,
                      size: 18,
                      color: AppColors.primaryAmber,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // 5. Action Buttons
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: widget.onKeepInBackground,
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: Text('online.keepRoomInBackground'.tr()),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.getTextPrimary(isDark),
                side: BorderSide(color: AppColors.getBorder(isDark)),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: widget.onCancelRoom,
              icon: const Icon(
                Icons.close_rounded,
                size: 16,
                color: AppColors.lossRed,
              ),
              label: Text('online.cancelRoom'.tr()),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.lossRed,
                padding: const EdgeInsets.symmetric(vertical: 10),
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildPulseRing({
    required double progress,
    required double maxRadius,
    required Color color,
  }) {
    final radius = 28.0 + (progress * maxRadius);
    final opacity = (1.0 - progress).clamp(0.0, 1.0);

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withValues(alpha: opacity * 0.4),
          width: 1.5,
        ),
      ),
    );
  }

  Widget _buildBadgeChip({
    required IconData icon,
    required String label,
    required bool isDark,
    Color? highlightColor,
  }) {
    final color = highlightColor ?? AppColors.getTextSecondary(isDark);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.getSurface(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlightColor != null
              ? highlightColor.withValues(alpha: 0.3)
              : AppColors.getBorder(isDark),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
