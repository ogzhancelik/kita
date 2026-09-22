import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../widgets/common/kita_app_bar.dart';
import '../../widgets/common/kita_button.dart';
import '../../widgets/common/responsive_layout.dart';
import '../game/offline_ai_screen.dart';
import 'guest_setup_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const KitaAppBar(showAuthActions: false),
      body: ResponsiveLayout(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                // Hero Chess Board Icon / Illustration
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.primaryVibrant : AppColors.primary,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.primaryShadow,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.grid_4x4_rounded,
                    color: AppColors.accent,
                    size: 64,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'appTitle'.tr(),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'appTagline'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.5,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 40),

                // Option 1: Continue as Guest (Gartic Phone style onboarding)
                KitaButton(
                  text: 'auth.continueAsGuest'.tr(),
                  icon: Icons.person_outline_rounded,
                  variant: KitaButtonVariant.primary,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const GuestSetupScreen()),
                    );
                  },
                ),
                const SizedBox(height: 14),

                // Option 2: Log In
                KitaButton(
                  text: 'auth.login'.tr(),
                  icon: Icons.login_rounded,
                  variant: KitaButtonVariant.secondary,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                ),
                const SizedBox(height: 14),

                // Option 3: Sign Up
                KitaButton(
                  text: 'auth.register'.tr(),
                  icon: Icons.person_add_outlined,
                  variant: KitaButtonVariant.outline,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Offline AI Quick Access
                TextButton.icon(
                  icon: const Icon(Icons.smart_toy_outlined, size: 18, color: AppColors.primaryGreen),
                  label: Text(
                    'dashboard.playAI'.tr(),
                    style: const TextStyle(
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const OfflineAiScreen()),
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
