import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';
import '../widgets/common/kita_button.dart';
import '../widgets/common/responsive_layout.dart';
import 'auth/welcome_screen.dart';
import 'home/dashboard_screen.dart';

class SplashGateScreen extends StatefulWidget {
  const SplashGateScreen({super.key});

  @override
  State<SplashGateScreen> createState() => _SplashGateScreenState();
}

class _SplashGateScreenState extends State<SplashGateScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().checkInitialState();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProv = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (authProv.state) {
      case AuthState.authenticated:
      case AuthState.guest:
      case AuthState.offline:
        return const DashboardScreen();

      case AuthState.unauthenticated:
        return const WelcomeScreen();

      case AuthState.initial:
      case AuthState.checking:
        return Scaffold(
          body: ResponsiveLayout(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.primaryGreenDark,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.grid_4x4_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'appTitle'.tr(),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'network.checking'.tr(),
                    style: TextStyle(
                      fontSize: 13.5,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                  const SizedBox(height: 28),
                  KitaButton(
                    text: 'network.continueOffline'.tr(),
                    icon: Icons.wifi_off_rounded,
                    variant: KitaButtonVariant.secondary,
                    width: 210,
                    height: 44,
                    fontSize: 14,
                    onPressed: () {
                      context.read<AuthProvider>().continueOffline();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
    }
  }
}
