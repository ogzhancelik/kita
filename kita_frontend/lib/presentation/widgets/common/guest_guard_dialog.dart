import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../common/kita_button.dart';

class GuestGuardDialog extends StatelessWidget {
  const GuestGuardDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.guestOrange.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.guestOrange.withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                color: AppColors.guestOrange,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'guest.restrictionTitle'.tr(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'guest.restrictionDesc'.tr(),
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            KitaButton(
              text: 'guest.unlockAccount'.tr(),
              icon: Icons.person_add_alt_1_rounded,
              variant: KitaButtonVariant.primary,
              onPressed: () {
                Navigator.of(context).pop();
                context.read<AuthProvider>().logout();
              },
            ),
            const SizedBox(height: 10),
            KitaButton(
              text: 'guest.stayGuest'.tr(),
              variant: KitaButtonVariant.outline,
              height: 42,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
