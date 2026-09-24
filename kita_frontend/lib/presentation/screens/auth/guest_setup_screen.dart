import 'dart:math';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: KitaAppBar(
        showAuthActions: false,
        showBack: true,
        title: 'guest.title'.tr(),
      ),
      body: ResponsiveLayout(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 12),
                Text(
                  'guest.subtitle'.tr(),
                  style: TextStyle(
                    fontSize: 14.5,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 24),

                // Selected Avatar Preview
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: AvatarPicker.avatars[_selectedAvatarIndex].accentColor.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AvatarPicker.avatars[_selectedAvatarIndex].accentColor,
                          width: 3,
                        ),
                      ),
                      child: Icon(
                        AvatarPicker.avatars[_selectedAvatarIndex].icon,
                        size: 48,
                        color: AvatarPicker.avatars[_selectedAvatarIndex].accentColor,
                      ),
                    ),
                    IconButton.filled(
                      icon: const Icon(Icons.casino_rounded, size: 18),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                      ),
                      tooltip: 'guest.randomize'.tr(),
                      onPressed: _randomizeName,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Avatar Grid
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'guest.chooseAvatar'.tr(),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                AvatarPicker(
                  selectedIndex: _selectedAvatarIndex,
                  onSelected: (idx) => setState(() => _selectedAvatarIndex = idx),
                ),
                const SizedBox(height: 24),

                // Nickname Input
                KitaTextField(
                  controller: _nameController,
                  label: 'guest.nickname'.tr(),
                  hint: 'guest.nicknameHint'.tr(),
                  prefixIcon: Icons.badge_rounded,
                ),
                const SizedBox(height: 32),

                // Enter Game Button
                KitaButton(
                  text: 'guest.startPlaying'.tr(),
                  icon: Icons.play_arrow_rounded,
                  variant: KitaButtonVariant.primary,
                  onPressed: () async {
                    final name = _nameController.text.trim();
                    if (context.mounted) {
                      context.read<FriendsProvider>().clear();
                      context.read<NotificationProvider>().clear();
                    }
                    await context.read<AuthProvider>().continueAsGuest(
                          name.isEmpty ? 'Guest' : name,
                          _selectedAvatarIndex,
                        );
                    if (context.mounted) {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    }
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
