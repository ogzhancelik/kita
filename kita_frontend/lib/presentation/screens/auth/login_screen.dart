import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/feedback/toast_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/friends_provider.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/common/kita_app_bar.dart';
import '../../widgets/common/kita_button.dart';
import '../../widgets/common/kita_text_field.dart';
import '../../widgets/common/responsive_layout.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameOrEmailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameOrEmailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authProv = context.read<AuthProvider>();
    final success = await authProv.login(
      _usernameOrEmailController.text.trim(),
      _passwordController.text,
    );

    if (success && mounted) {
      KitaToast.success('auth.loginSuccess'.tr(args: [authProv.displayName]));
      context.read<FriendsProvider>().loadAll();
      context.read<NotificationProvider>().loadNotifications();
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProv = context.watch<AuthProvider>();

    return Scaffold(
      appBar: KitaAppBar(
        showAuthActions: false,
        showBack: true,
        title: 'auth.login'.tr(),
      ),
      body: ResponsiveLayout(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
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
                        Icons.lock_person_rounded,
                        color: Colors.white,
                        size: 38,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'auth.login'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Username / Email
                  KitaTextField(
                    controller: _usernameOrEmailController,
                    label: 'auth.usernameOrEmail'.tr(),
                    hint: 'auth.usernameOrEmailHint'.tr(),
                    prefixIcon: Icons.account_circle_outlined,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'errMissingField'.tr();
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password
                  KitaTextField(
                    controller: _passwordController,
                    label: 'auth.password'.tr(),
                    hint: 'auth.passwordHint'.tr(),
                    prefixIcon: Icons.key_outlined,
                    isPassword: true,
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return 'errMissingField'.tr();
                      }
                      if (val.length < 6) {
                        return 'auth.passwordTooShort'.tr();
                      }
                      return null;
                    },
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 20),

                  // Submit Button
                  KitaButton(
                    text: 'auth.login'.tr(),
                    icon: Icons.login_rounded,
                    isLoading: authProv.isLoading,
                    variant: KitaButtonVariant.primary,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 20),

                  // Link to Register
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'auth.dontHaveAccount'.tr(),
                        style: TextStyle(
                          fontSize: 13.5,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => const RegisterScreen()),
                          );
                        },
                        child: Text(
                          'auth.register'.tr(),
                          style: const TextStyle(
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
