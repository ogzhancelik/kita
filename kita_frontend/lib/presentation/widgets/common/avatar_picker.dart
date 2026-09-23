import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';

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
      builder: (ctx) {
        final authProv = ctx.watch<AuthProvider>();
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'guest.chooseAvatar'.tr(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 16),
              AvatarPicker(
                selectedIndex: authProv.avatarIndex,
                onSelected: (idx) {
                  authProv.setAvatarIndex(idx);
                  Navigator.of(ctx).pop();
                },
              ),
            ],
          ),
        );
      },
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
