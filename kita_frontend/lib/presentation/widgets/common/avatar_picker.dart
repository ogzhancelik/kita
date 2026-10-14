import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/online_game_provider.dart';
import 'kita_avatar.dart';
import 'kita_emoji_picker.dart';

/// Enforces exactly one valid Unicode emoji character (including compound/ZWJ sequences),
/// rejecting letters, numbers, whitespace, and punctuation.
class SingleEmojiInputFormatter extends TextInputFormatter {
  const SingleEmojiInputFormatter();

  static final RegExp singleEmojiRegex = RegExp(
    [
      r'^(?:',
      r'[\u{1F1E6}-\u{1F1FF}]{2}',
      r'|',
      r'\p{Extended_Pictographic}',
      r'(?:\p{Emoji_Modifier}|\uFE0F|\uFE0E)?',
      r'(?:\u200D(?:\p{Extended_Pictographic}|[\u{1F1E6}-\u{1F1FF}]{2})(?:\p{Emoji_Modifier}|\uFE0F|\uFE0E)?)*',
      r')$',
    ].join(),
    unicode: true,
  );

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }
    final text = newValue.text.trim();
    if (singleEmojiRegex.hasMatch(text)) {
      return TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }

    final offset = newValue.selection.baseOffset;
    if (offset > 0 && offset <= newValue.text.length) {
      final prefixGraphemes = newValue.text.substring(0, offset).characters;
      if (prefixGraphemes.isNotEmpty) {
        final candidate = prefixGraphemes.last;
        if (singleEmojiRegex.hasMatch(candidate)) {
          return TextEditingValue(
            text: candidate,
            selection: TextSelection.collapsed(offset: candidate.length),
          );
        }
      }
    }

    final newGraphemes = newValue.text.characters;
    for (final char in newGraphemes.toList().reversed) {
      if (singleEmojiRegex.hasMatch(char)) {
        return TextEditingValue(
          text: char,
          selection: TextSelection.collapsed(offset: char.length),
        );
      }
    }

    return oldValue;
  }
}

class AvatarItem {
  final int id;
  final IconData icon;
  final String label;
  final Color accentColor;

  const AvatarItem({
    required this.id,
    required this.icon,
    required this.label,
    required this.accentColor,
  });
}

class AvatarPicker extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const List<IconData> symbolIcons = [
    Icons.pets_rounded,                 // 0: Wolf
    Icons.sports_martial_arts_rounded, // 1: Knight
    Icons.shield_rounded,              // 2: Guardian
    Icons.auto_fix_high_rounded,       // 3: Mage
    Icons.bolt_rounded,                // 4: Striker
    Icons.military_tech_rounded,       // 5: Captain
    Icons.local_fire_department_rounded,// 6: Dragon
    Icons.visibility_rounded,          // 7: Oracle
  ];

  static const List<Color> themeColors = [
    AppColors.primaryGreen,      // 0: Brand Primary
    Color(0xFF3498DB),          // 1: Blue
    Color(0xFFE67E22),          // 2: Orange
    Color(0xFF9B59B6),          // 3: Purple
    Color(0xFFF1C40F),          // 4: Yellow / Gold
    Color(0xFFE74C3C),          // 5: Red
    Color(0xFF1ABC9C),          // 6: Teal
    Color(0xFF34495E),          // 7: Navy / Slate
  ];

  static const List<AvatarItem> avatars = [
    AvatarItem(id: 0, icon: Icons.pets_rounded, label: 'Wolf', accentColor: AppColors.primaryGreen),
    AvatarItem(id: 1, icon: Icons.sports_martial_arts_rounded, label: 'Knight', accentColor: Color(0xFF3498DB)),
    AvatarItem(id: 2, icon: Icons.shield_rounded, label: 'Guardian', accentColor: Color(0xFFE67E22)),
    AvatarItem(id: 3, icon: Icons.auto_fix_high_rounded, label: 'Mage', accentColor: Color(0xFF9B59B6)),
    AvatarItem(id: 4, icon: Icons.bolt_rounded, label: 'Striker', accentColor: Color(0xFFF1C40F)),
    AvatarItem(id: 5, icon: Icons.military_tech_rounded, label: 'Captain', accentColor: Color(0xFFE74C3C)),
    AvatarItem(id: 6, icon: Icons.local_fire_department_rounded, label: 'Dragon', accentColor: Color(0xFF1ABC9C)),
    AvatarItem(id: 7, icon: Icons.visibility_rounded, label: 'Oracle', accentColor: Color(0xFF34495E)),
  ];

  static Color getColor(int avatarIndex) {
    return themeColors[getColorIndex(avatarIndex)];
  }

  static IconData getIcon(int avatarIndex) {
    return symbolIcons[getSymbolIndex(avatarIndex)];
  }

  static int getSymbolIndex(int avatarIndex) {
    final safe = avatarIndex.abs();
    if (safe >= 64) {
      return ((safe - 64) ~/ 8) % 8;
    }
    return safe % 8;
  }

  static int getColorIndex(int avatarIndex) {
    final safe = avatarIndex.abs();
    if (safe >= 64) {
      return (safe - 64) % 8;
    }
    return safe % 8;
  }

  static int encodeIndex({required int symbolIndex, required int colorIndex}) {
    final s = symbolIndex.clamp(0, 7);
    final c = colorIndex.clamp(0, 7);
    if (s == c) {
      return s;
    }
    return 64 + (s * 8) + c;
  }

  const AvatarPicker({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _AvatarPickerBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.0,
      ),
      itemCount: avatars.length,
      itemBuilder: (context, index) {
        final avatar = avatars[index];
        final isSelected = selectedIndex == index;

        return InkWell(
          onTap: () => onSelected(index),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: isSelected
                  ? avatar.accentColor.withValues(alpha: 0.2)
                  : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? avatar.accentColor : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                width: isSelected ? 2.5 : 1.0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: avatar.accentColor.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  avatar.icon,
                  size: 28,
                  color: isSelected ? avatar.accentColor : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                ),
                if (isSelected)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: avatar.accentColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, size: 10, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AvatarPickerBottomSheet extends StatefulWidget {
  const _AvatarPickerBottomSheet();

  @override
  State<_AvatarPickerBottomSheet> createState() => _AvatarPickerBottomSheetState();
}

class _AvatarPickerBottomSheetState extends State<_AvatarPickerBottomSheet> {
  late int _selectedSymbolIndex;
  late int _selectedColorIndex;
  String? _customEmoji;

  @override
  void initState() {
    super.initState();
    final authProv = context.read<AuthProvider>();
    final rawIndex = authProv.avatarIndex;
    _selectedSymbolIndex = AvatarPicker.getSymbolIndex(rawIndex);
    _selectedColorIndex = AvatarPicker.getColorIndex(rawIndex);
    _customEmoji = authProv.avatarCustom?.trim().isNotEmpty == true
        ? authProv.avatarCustom!.trim()
        : null;
  }

  void _applyChange({
    int? newSymbolIndex,
    int? newColorIndex,
    String? newCustomEmoji,
    bool clearEmoji = false,
  }) {
    setState(() {
      if (newSymbolIndex != null) _selectedSymbolIndex = newSymbolIndex;
      if (newColorIndex != null) _selectedColorIndex = newColorIndex;
      if (clearEmoji) {
        _customEmoji = null;
      } else if (newCustomEmoji != null) {
        _customEmoji = newCustomEmoji;
      }
    });

    final authProv = context.read<AuthProvider>();
    final effectiveCustom = _customEmoji?.trim().isNotEmpty == true
        ? _customEmoji!.trim()
        : null;

    final encodedIndex = AvatarPicker.encodeIndex(
      symbolIndex: _selectedSymbolIndex,
      colorIndex: _selectedColorIndex,
    );

    authProv.setAvatarIndex(
      encodedIndex,
      custom: effectiveCustom,
      clearCustom: effectiveCustom == null,
    );

    try {
      context.read<OnlineGameProvider>().updateAvatar(
            encodedIndex,
            avatarCustom: effectiveCustom,
          );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final safeSymbolIndex = _selectedSymbolIndex.clamp(0, 7);
    final safeColorIndex = _selectedColorIndex.clamp(0, 7);
    final currentColor = AvatarPicker.themeColors[safeColorIndex];
    final previewIndex = AvatarPicker.encodeIndex(
      symbolIndex: safeSymbolIndex,
      colorIndex: safeColorIndex,
    );

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal Top Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'avatar.title'.tr(),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close_rounded,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                  tooltip: 'dialog.close'.tr(),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Live Preview Card
            Center(
              child: KitaAvatar(
                size: 88,
                avatarIndex: previewIndex,
                avatarCustom: _customEmoji,
                borderWidth: 3.5,
              ),
            ),
            const SizedBox(height: 16),

            // Section: Color Theme (Border & Glow Accent)
            Text(
              'avatar.colorTheme'.tr(),
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(AvatarPicker.themeColors.length, (index) {
                final color = AvatarPicker.themeColors[index];
                final isColorSelected = safeColorIndex == index;
                return GestureDetector(
                  onTap: () => _applyChange(newColorIndex: index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isColorSelected
                            ? Colors.white
                            : Colors.transparent,
                        width: isColorSelected ? 2.5 : 0,
                      ),
                      boxShadow: isColorSelected
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.6),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: isColorSelected
                        ? const Icon(Icons.check, size: 18, color: Colors.white)
                        : null,
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),

            // Section: Symbols & Emoji (3 rows x 3 columns)
            Text(
              'avatar.classicIcons'.tr(),
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.15,
              ),
              itemCount: 9,
              itemBuilder: (context, index) {
                if (index < 8) {
                  // Classic icon tile
                  final avatar = AvatarPicker.avatars[index];
                  final isIconActive = _customEmoji == null && safeSymbolIndex == index;

                  return InkWell(
                    onTap: () => _applyChange(newSymbolIndex: index, clearEmoji: true),
                    borderRadius: BorderRadius.circular(14),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: isIconActive
                            ? currentColor.withValues(alpha: 0.2)
                            : (isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isIconActive
                              ? currentColor
                              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                          width: isIconActive ? 2.0 : 1.0,
                        ),
                        boxShadow: isIconActive
                            ? [
                                BoxShadow(
                                  color: currentColor.withValues(alpha: 0.25),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            avatar.icon,
                            size: 32,
                            color: isIconActive
                                ? currentColor
                                : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                          ),
                          if (isIconActive)
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: currentColor,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check, size: 10, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                } else {
                  // 9th Tile: Emoji Picker Button / Active Custom Emoji
                  final isEmojiActive = _customEmoji != null && _customEmoji!.isNotEmpty;

                  return InkWell(
                    onTap: () async {
                      final emoji = await KitaEmojiPicker.showModal(context);
                      if (emoji != null && emoji.trim().isNotEmpty) {
                        _applyChange(newCustomEmoji: emoji.trim());
                      }
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: isEmojiActive
                            ? currentColor.withValues(alpha: 0.2)
                            : (isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isEmojiActive
                              ? currentColor
                              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                          width: isEmojiActive ? 2.0 : 1.0,
                        ),
                        boxShadow: isEmojiActive
                            ? [
                                BoxShadow(
                                  color: currentColor.withValues(alpha: 0.25),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (isEmojiActive)
                            Text(
                              _customEmoji!,
                              style: const TextStyle(fontSize: 32),
                            )
                          else
                            Icon(
                              Icons.add_reaction_outlined,
                              size: 32,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          if (isEmojiActive)
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: currentColor,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check, size: 10, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
