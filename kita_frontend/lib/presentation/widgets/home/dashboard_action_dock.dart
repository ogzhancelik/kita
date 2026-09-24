import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class DashboardActionDock extends StatefulWidget {
  final VoidCallback onPlay;
  final VoidCallback? onHome;

  const DashboardActionDock({
    super.key,
    required this.onPlay,
    this.onHome,
  });

  @override
  State<DashboardActionDock> createState() => _DashboardActionDockState();
}

class _DashboardActionDockState extends State<DashboardActionDock> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final buttonWidth = screenWidth < 500 ? screenWidth - 32 : 360.0;
    const double bottomOffset = 4.0;
    final double currentShift = _isPressed ? bottomOffset : 0.0;

    return SafeArea(
      child: Container(
        width: buttonWidth,
        height: 54,
        margin: const EdgeInsets.only(bottom: 6),
        alignment: Alignment.topCenter,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) => setState(() => _isPressed = false),
            onTapCancel: () => setState(() => _isPressed = false),
            onTap: widget.onPlay,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 60),
              height: 50,
              margin: EdgeInsets.only(top: currentShift),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  // 1. Prominent dark ambient drop shadow behind the button
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.75 : 0.35),
                    blurRadius: _isPressed ? 10 : 20,
                    spreadRadius: _isPressed ? 0 : 2,
                    offset: Offset(0, _isPressed ? 4 : 8),
                  ),
                  // 2. Rich brand colored glow aura behind the button
                  BoxShadow(
                    color: AppColors.primaryGreen.withValues(
                      alpha: isDark ? 0.65 : 0.40,
                    ),
                    blurRadius: _isPressed ? 8 : 16,
                    spreadRadius: 1,
                    offset: Offset(0, _isPressed ? 2 : 5),
                  ),
                  // 3. Darker 3D bevel underneath just like "Continue as Guest" (KitaButton)
                  if (!_isPressed)
                    const BoxShadow(
                      color: AppColors.primaryGreenDark,
                      offset: Offset(0, bottomOffset),
                      blurRadius: 0,
                    ),
                ],
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.sports_esports_rounded,
                      size: 26,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'dashboard.playAction'.tr(),
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

