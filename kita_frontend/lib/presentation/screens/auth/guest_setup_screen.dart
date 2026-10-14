import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/feedback/toast_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/friends_provider.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/common/avatar_picker.dart';
import '../../widgets/common/kita_app_bar.dart';
import '../../widgets/common/kita_button.dart';
import '../../widgets/common/kita_text_field.dart';
import '../../widgets/common/responsive_layout.dart';

class GuestSetupScreen extends StatefulWidget {
  const GuestSetupScreen({super.key});

  @override
  State<GuestSetupScreen> createState() => _GuestSetupScreenState();
}

class _GuestSetupScreenState extends State<GuestSetupScreen> {
  final TextEditingController _nameController = TextEditingController();
  int _selectedAvatarIndex = 0;

  static const List<String> _suggestedNames = [
    'KitaWarrior',
    'TacticalPawn',
    'GrandKnight',
    'ShadowMaster',
    'StormBringer',
    'DragonRider',
    'SwiftBlade',
    'IronGolem',
  ];

  @override
  void initState() {
    super.initState();
    _randomizeName();
  }

  void _randomizeName() {
    final random = Random();
    final name = _suggestedNames[random.nextInt(_suggestedNames.length)];
    final suffix = random.nextInt(900) + 100;
    _nameController.text = '$name$suffix';
    _selectedAvatarIndex = random.nextInt(AvatarPicker.avatars.length);
    setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _continueAsGuest() async {
    final raw = _nameController.text.trim();
    String name = raw;
    if (raw.isNotEmpty) {
      const reserved = {
        'admin',
        'guest',
        'system',
        'kita',
        'bot',
        'moderator',
        'support',
      };
      if (raw.length < 2) {
        KitaToast.error('auth.usernameTooShort'.tr());
        return;
      }
      if (raw.length > 15) {
        KitaToast.error('auth.usernameTooLong'.tr());
        return;
      }
      if (!RegExp(r'^[a-zA-Z0-9_-]{2,15}$').hasMatch(raw)) {
        KitaToast.error('auth.usernameInvalid'.tr());
        return;
      }
      if (reserved.contains(raw.toLowerCase())) {
        KitaToast.error('auth.usernameReserved'.tr());
        return;
      }
    } else {
      name = 'Guest';
    }

    if (mounted) {
      context.read<FriendsProvider>().clear();
      context.read<NotificationProvider>().clear();
    }
    if (!mounted) return;
    await context.read<AuthProvider>().continueAsGuest(
      name,
      _selectedAvatarIndex,
    );
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: KitaAppBar(
        showAuthActions: false,
        showBack: true,
        title: 'guest.title'.tr(),
      ),
      body: ResponsiveLayout(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10.0,
                      vertical: 12.0,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: AppColors.primaryAmber,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: const [
                                BoxShadow(
                                  color: AppColors.primaryAmberDark,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              color: Colors.white,
                              size: 38,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'guest.title'.tr(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'guest.subtitle'.tr(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Nickname Input with randomize suffix button
                        KitaTextField(
                          controller: _nameController,
                          label: 'guest.nickname'.tr(),
                          hint: 'guest.nicknameHint'.tr(),
                          prefixIcon: Icons.badge_rounded,
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.casino_rounded, size: 20),
                            color: AppColors.primaryAmber,
                            tooltip: 'guest.randomize'.tr(),
                            onPressed: _randomizeName,
                          ),
                          maxLength: 15,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _continueAsGuest(),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_-]')),
                            LengthLimitingTextInputFormatter(15),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Enter Game Button
                        KitaButton(
                          text: 'guest.startPlaying'.tr(),
                          icon: Icons.play_arrow_rounded,
                          variant: KitaButtonVariant.primary,
                          onPressed: _continueAsGuest,
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
