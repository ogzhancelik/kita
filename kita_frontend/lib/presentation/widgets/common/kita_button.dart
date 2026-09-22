import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

enum KitaButtonVariant { primary, secondary, brand, danger, outline }

class KitaButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final KitaButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final double height;
  final double? width;
  final double fontSize;

  const KitaButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.variant = KitaButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.height = 50.0,
    this.width,
    this.fontSize = 15.5,
  });

  @override
  State<KitaButton> createState() => _KitaButtonState();
}

class _KitaButtonState extends State<KitaButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEnabled = widget.onPressed != null && !widget.isLoading;

    Color topColor;
    Color bottomColor;
    Color textColor;
    Color? borderColor;

    switch (widget.variant) {
      case KitaButtonVariant.primary:
        topColor = isEnabled
            ? AppColors.primaryGreen
            : AppColors.primaryGreen.withValues(alpha: 0.5);
        bottomColor = isEnabled
            ? AppColors.primaryGreenDark
            : AppColors.primaryGreenDark.withValues(alpha: 0.5);
        textColor = Colors.white; // Crisp high-contrast white on reddish-purple
        break;
      case KitaButtonVariant.brand:
        topColor = isDark
            ? (isEnabled
                  ? AppColors.primaryVibrant
                  : AppColors.primaryVibrant.withValues(alpha: 0.5))
            : (isEnabled
                  ? AppColors.primary
                  : AppColors.primary.withValues(alpha: 0.5));
        bottomColor = isEnabled
            ? AppColors.primaryShadow
            : AppColors.primaryShadow.withValues(alpha: 0.5);
        textColor = Colors.white;
        break;
      case KitaButtonVariant.secondary:
        topColor = isDark
            ? AppColors.darkSurfaceElevated
            : AppColors.lightSurface;
        bottomColor = isDark ? AppColors.darkBorder : const Color(0xFFCCC9C2);
        textColor = isDark ? Colors.white : AppColors.lightTextPrimary;
        borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
        break;
      case KitaButtonVariant.danger:
        topColor = AppColors.error;
        bottomColor = AppColors.errorDark;
        textColor = Colors.white;
        break;
      case KitaButtonVariant.outline:
        topColor = Colors.transparent;
        bottomColor = Colors.transparent;
        textColor = isDark
            ? AppColors.darkTextPrimary
            : AppColors.lightTextPrimary;
        borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
        break;
    }

    final double bottomOffset =
        (widget.variant == KitaButtonVariant.outline || !isEnabled) ? 0 : 3.5;
    final double currentShift = _isPressed ? bottomOffset : 0;

    return SizedBox(
      width: widget.width ?? double.infinity,
      height: widget.height,
      child: GestureDetector(
        onTapDown: isEnabled ? (_) => setState(() => _isPressed = true) : null,
        onTapUp: isEnabled ? (_) => setState(() => _isPressed = false) : null,
        onTapCancel: isEnabled
            ? () => setState(() => _isPressed = false)
            : null,
        onTap: isEnabled ? widget.onPressed : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 60),
          margin: EdgeInsets.only(top: currentShift),
          decoration: BoxDecoration(
            color: topColor,
            borderRadius: BorderRadius.circular(10),
            border: borderColor != null
                ? Border.all(color: borderColor, width: 1.2)
                : null,
            boxShadow: bottomOffset > 0 && !_isPressed
                ? [
                    BoxShadow(
                      color: bottomColor,
                      offset: Offset(0, bottomOffset),
                      blurRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, color: textColor, size: 20),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        widget.text,
                        style: TextStyle(
                          color: textColor,
                          fontSize: widget.fontSize,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
