import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Reusable Kita Emoji Picker designed for avatar customization,
/// direct messaging, and in-match chats without cluttered search bars.
class KitaEmojiPicker extends StatelessWidget {
  final ValueChanged<String> onEmojiSelected;
  final double height;

  const KitaEmojiPicker({
    super.key,
    required this.onEmojiSelected,
    this.height = 250,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: height,
      child: EmojiPicker(
        onEmojiSelected: (category, emoji) {
          onEmojiSelected(emoji.emoji);
        },
        config: Config(
          height: height,
          checkPlatformCompatibility: true,
          emojiViewConfig: EmojiViewConfig(
            columns: 8,
            emojiSizeMax: 28,
            backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          ),
          categoryViewConfig: CategoryViewConfig(
            backgroundColor: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
            iconColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            iconColorSelected: AppColors.primaryGreen,
            indicatorColor: AppColors.primaryGreen,
          ),
          bottomActionBarConfig: const BottomActionBarConfig(
            enabled: false,
          ),
        ),
      ),
    );
  }

  static Future<String?> showModal(
    BuildContext context, {
    ValueChanged<String>? onEmojiSelected,
    TextEditingController? controller,
    VoidCallback? onSend,
    bool? closeOnSelect,
  }) {
    final shouldCloseOnSelect =
        closeOnSelect ?? (onEmojiSelected == null && controller == null);

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final hasPreview = controller != null;
        final totalHeight = hasPreview ? 370.0 : 320.0;

        return Container(
          height: totalHeight,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header with Drag Handle & Close button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 12, 4),
                child: Row(
                  children: [
                    const SizedBox(width: 28),
                    Expanded(
                      child: Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.of(ctx).pop(),
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Optional live preview & Send row (when used in chats)
              if (hasPreview) ...[
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkSurfaceElevated
                                : AppColors.lightSurfaceElevated,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder,
                              width: 0.8,
                            ),
                          ),
                          child: AnimatedBuilder(
                            animation: controller,
                            builder: (context, _) {
                              final text = controller.text;
                              return Text(
                                text.isEmpty ? '...' : text,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: text.isEmpty
                                      ? (isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary)
                                      : (isDark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.lightTextPrimary),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              );
                            },
                          ),
                        ),
                      ),
                      if (onSend != null) ...[
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () {
                            onSend();
                            Navigator.of(ctx).pop();
                          },
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: AppColors.primaryGreen,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.send_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 4),
              ],

              // Emoji picker
              Expanded(
                child: KitaEmojiPicker(
                  height: hasPreview ? 290 : 280,
                  onEmojiSelected: (emoji) {
                    if (controller != null) {
                      final text = controller.text;
                      final selection = controller.selection;
                      if (selection.isValid &&
                          selection.start >= 0 &&
                          selection.end >= 0) {
                        final start = selection.start;
                        final end = selection.end;
                        final newText = text.replaceRange(start, end, emoji);
                        controller.value = TextEditingValue(
                          text: newText,
                          selection: TextSelection.collapsed(
                              offset: start + emoji.length),
                        );
                      } else {
                        final newText = text + emoji;
                        controller.value = TextEditingValue(
                          text: newText,
                          selection: TextSelection.collapsed(
                              offset: newText.length),
                        );
                      }
                    }
                    onEmojiSelected?.call(emoji);
                    if (shouldCloseOnSelect) {
                      Navigator.of(ctx).pop(emoji);
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
