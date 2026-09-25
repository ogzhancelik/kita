import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/api_constants.dart';
import '../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/online_game_provider.dart';
import '../widgets/common/api_url_config_bar.dart';
import '../widgets/common/kita_app_bar.dart';
import '../widgets/common/kita_button.dart';
import '../widgets/common/responsive_layout.dart';
import 'auth/welcome_screen.dart';
import 'game/online_match_screen.dart';
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
        return const DashboardScreen();

      case AuthState.unauthenticated:
        return const WelcomeScreen();

      case AuthState.offline:
        return Scaffold(
          appBar: const KitaAppBar(showAuthActions: false),
          bottomNavigationBar: ApiConstants.showApiConfig
              ? const ApiUrlConfigBar()
              : null,
          body: ResponsiveLayout(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.error, width: 2),
                      ),
                      child: const Icon(
                        Icons.wifi_off_rounded,
                        color: AppColors.error,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'network.offlineTitle'.tr(),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'network.offlineDesc'.tr(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Offline AI Play Action
                    KitaButton(
                      text: 'network.playOfflineAI'.tr(),
                      icon: Icons.smart_toy_rounded,
                      variant: KitaButtonVariant.primary,
                      onPressed: () {
                        final currentAuth = context.read<AuthProvider>();
                        context.read<OnlineGameProvider>().startOfflineMatch(
                          mode: PlayMode.vsAi,
                          playerId: currentAuth.currentUser?.id,
                          playerName: currentAuth.currentUser?.username ??
                              currentAuth.guestProfile?.nickname ??
                              'Guest',
                          playerRating: currentAuth.currentUser?.rating ?? 1200,
                          isGuest: currentAuth.isGuest || currentAuth.currentUser == null,
                        );
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const OnlineMatchScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    // Retry Connection
                    KitaButton(
                      text: 'network.retryConnection'.tr(),
                      icon: Icons.refresh_rounded,
                      variant: KitaButtonVariant.secondary,
                      onPressed: () => authProv.checkInitialState(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

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
                ],
              ),
            ),
          ),
        );
    }
  }
}
