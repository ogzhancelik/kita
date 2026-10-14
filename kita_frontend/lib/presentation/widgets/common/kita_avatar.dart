import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'avatar_picker.dart';

/// Reusable player avatar that supports custom emojis, classic icon avatars,
/// guest indicators, deleted users, and bots with rich borders and glowing background.
class KitaAvatar extends StatelessWidget {
  final int avatarIndex;
  final String? avatarCustom;
  final double size;
  final double? fontSize;
  final double? iconSize;
  final double borderWidth;
  final Color? borderColor;
  final Color? backgroundColor;
  final bool isBot;
  final bool isGuest;
  final bool isDeleted;
  final VoidCallback? onTap;

  const KitaAvatar({
    super.key,
    required this.avatarIndex,
    this.avatarCustom,
    this.size = 40,
    this.fontSize,
    this.iconSize,
    this.borderWidth = 2.0,
    this.borderColor,
    this.backgroundColor,
    this.isBot = false,
    this.isGuest = false,
    this.isDeleted = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color symbolColor = AvatarPicker.getColor(avatarIndex);
    final IconData symbolIcon = AvatarPicker.getIcon(avatarIndex);

    final bool hasCustomEmoji =
        avatarCustom != null && avatarCustom!.trim().isNotEmpty;

    final Color effectiveColor = isBot
        ? AppColors.primaryGreen
        : isDeleted
            ? AppColors.getDeletedUser(isDark)
            : (isGuest && avatarIndex == 0 && !hasCustomEmoji)
                ? AppColors.guestOrange
                : symbolColor;

    final Widget content;
    if (isBot) {
      content = Icon(
        Icons.smart_toy_rounded,
        color: effectiveColor,
        size: iconSize ?? (size * 0.52),
      );
    } else if (isDeleted) {
      content = Icon(
        Icons.face_rounded,
        color: effectiveColor,
        size: iconSize ?? (size * 0.52),
      );
    } else if (hasCustomEmoji) {
      content = Center(
        child: Text(
          avatarCustom!.trim(),
          style: TextStyle(
            fontSize: fontSize ?? (size * 0.52),
            height: 1.0,
          ),
          textAlign: TextAlign.center,
        ),
      );
    } else if (isGuest && avatarIndex == 0) {
      content = Icon(
        Icons.face_rounded,
        color: effectiveColor,
        size: iconSize ?? (size * 0.52),
      );
    } else {
      content = Icon(
        symbolIcon,
        color: effectiveColor,
        size: iconSize ?? (size * 0.52),
      );
    }

    final avatarBox = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? effectiveColor.withValues(alpha: 0.18),
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor ?? effectiveColor,
          width: borderWidth,
        ),
      ),
      child: content,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size),
        child: avatarBox,
      );
    }

    return avatarBox;
  }
}
