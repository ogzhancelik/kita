import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum ToastType { info, success, warning, error }

class KitaToast {
  KitaToast._();

  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static void show({
    required String message,
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    ScaffoldMessengerState? state;
    try {
      state = messengerKey.currentState;
    } catch (_) {
      return;
    }
    if (state == null) return;

    state.removeCurrentSnackBar();

    Color bgColor;
    Color borderColor;
    IconData icon;

    switch (type) {
      case ToastType.success:
        bgColor = AppColors.accentDark.withValues(alpha: 0.35);
        borderColor = AppColors.accentSecondary;
        icon = Icons.check_circle_outline;
        break;
      case ToastType.error:
        bgColor = const Color(0xFF4A1F1F);
        borderColor = AppColors.error;
        icon = Icons.error_outline;
        break;
      case ToastType.warning:
        bgColor = const Color(0xFF4A3816);
        borderColor = AppColors.warning;
        icon = Icons.warning_amber_rounded;
        break;
      case ToastType.info:
        bgColor = AppColors.darkSurfaceElevated;
        borderColor = AppColors.darkBorder;
        icon = Icons.info_outline;
        break;
    }

    state.showSnackBar(
      SnackBar(
        duration: duration,
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        backgroundColor: bgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: borderColor, width: 1.2),
        ),
        content: Row(
          children: [
            Icon(icon, color: borderColor, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        action: (actionLabel != null && onAction != null)
            ? SnackBarAction(
                label: actionLabel,
                textColor: borderColor,
                onPressed: onAction,
              )
            : null,
      ),
    );
  }

  static void success(String message) =>
      show(message: message, type: ToastType.success);

  static void error(String message) =>
      show(message: message, type: ToastType.error);

  static void warning(String message) =>
      show(message: message, type: ToastType.warning);

  static void info(String message) =>
      show(message: message, type: ToastType.info);
}
