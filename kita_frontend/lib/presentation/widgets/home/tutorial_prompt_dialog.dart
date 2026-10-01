import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_colors.dart';
import '../../screens/tutorial/tutorial_screen.dart';
import '../common/kita_button.dart';

class TutorialPromptDialog extends StatelessWidget {
  const TutorialPromptDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const TutorialPromptDialog(),
    );
  }

  static Future<void> _markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_tutorial', true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1.5,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 26.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: AppColors.accentGold,
                  size: 38,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'tutorial.promptTitle'.tr(),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'tutorial.promptDesc'.tr(),
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              KitaButton(
                text: 'tutorial.promptPlay'.tr(),
                icon: Icons.play_arrow_rounded,
                variant: KitaButtonVariant.primary,
                height: 46,
                onPressed: () async {
                  await _markSeen();
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    TutorialScreen.launch(context, isFirstLaunch: true);
                  }
                },
              ),
              const SizedBox(height: 10),
              KitaButton(
                text: 'tutorial.promptSkip'.tr(),
                variant: KitaButtonVariant.outline,
                height: 42,
                onPressed: () async {
                  await _markSeen();
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
