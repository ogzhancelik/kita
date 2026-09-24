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
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authProv = context.read<AuthProvider>();
    final success = await authProv.register(
      _usernameController.text.trim(),
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (success && mounted) {
      KitaToast.success('auth.registerSuccess'.tr(args: [authProv.displayName]));
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
        title: 'auth.register'.tr(),
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
                  const SizedBox(height: 12),
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
                        Icons.person_add_alt_1_rounded,
                        color: Colors.white,
                        size: 38,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'auth.register'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Username
                  KitaTextField(
                    controller: _usernameController,
                    label: 'auth.username'.tr(),
                    hint: 'auth.usernameHint'.tr(),
                    prefixIcon: Icons.badge_outlined,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'errMissingField'.tr();
                      }
                      if (val.trim().length < 3) {
                        return 'auth.usernameTooShort'.tr();
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Email
                  KitaTextField(
                    controller: _emailController,
                    label: 'auth.email'.tr(),
                    hint: 'auth.emailHint'.tr(),
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.email_outlined,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'errMissingField'.tr();
                      }
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(val.trim())) {
                        return 'auth.invalidEmail'.tr();
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Password
                  KitaTextField(
                    controller: _passwordController,
                    label: 'auth.password'.tr(),
                    hint: 'auth.passwordHint'.tr(),
                    prefixIcon: Icons.lock_outline_rounded,
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
                  ),
                  const SizedBox(height: 14),

                  // Confirm Password
                  KitaTextField(
                    controller: _confirmPasswordController,
                    label: 'auth.confirmPassword'.tr(),
                    hint: 'auth.passwordHint'.tr(),
                    prefixIcon: Icons.lock_reset_rounded,
                    isPassword: true,
                    validator: (val) {
                      if (val != _passwordController.text) {
                        return 'auth.passwordsDoNotMatch'.tr();
                      }
                      return null;
                    },
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 24),

                  // Submit Button
                  KitaButton(
                    text: 'auth.register'.tr(),
                    icon: Icons.person_add_rounded,
                    isLoading: authProv.isLoading,
                    variant: KitaButtonVariant.primary,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 18),

                  // Link to Login
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'auth.alreadyHaveAccount'.tr(),
                        style: TextStyle(
                          fontSize: 13.5,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                          );
                        },
                        child: Text(
                          'auth.login'.tr(),
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
