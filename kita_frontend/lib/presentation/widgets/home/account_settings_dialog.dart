import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/feedback/toast_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../common/avatar_picker.dart';
import '../common/kita_avatar.dart';
import '../common/kita_card.dart';
import '../../screens/auth/register_screen.dart';

class AccountSettingsDialog extends StatelessWidget {
  const AccountSettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AccountSettingsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProv = context.watch<AuthProvider>();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
        maxWidth: 520,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'account.title'.tr(),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- User Profile Hero Card ---
                    KitaCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // Avatar with edit badge
                          GestureDetector(
                            onTap: () => AvatarPicker.show(context),
                            child: Stack(
                              children: [
                                KitaAvatar(
                                  size: 58,
                                  avatarIndex: authProv.avatarIndex,
                                  avatarCustom: authProv.avatarCustom,
                                  borderWidth: 2,
                                  isGuest: authProv.isGuest,
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryAmber,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isDark
                                            ? AppColors.darkSurface
                                            : AppColors.lightSurface,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_rounded,
                                      size: 11,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          // Name and status info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  authProv.displayName,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.lightTextPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    if (!authProv.isAuthenticated)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.guestOrange.withValues(
                                            alpha: 0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: AppColors.guestOrange
                                                .withValues(alpha: 0.4),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          'profile.guestPlayer'.tr(),
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.guestOrange,
                                          ),
                                        ),
                                      ),
                                    if (authProv.isAuthenticated &&
                                        authProv.currentUser != null) ...[
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.star_rounded,
                                        size: 14,
                                        color: AppColors.ratingGold,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        authProv.currentUser!.displayRating,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.ratingGold,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // --- Profile & Identity Group ---
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 6),
                      child: Text(
                        'account.profileIdentity'.tr(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),

                    // Change Avatar Tile
                    _buildTile(
                      isDark: isDark,
                      icon: Icons.face_rounded,
                      iconColor: AvatarPicker.getColor(authProv.avatarIndex),
                      title: 'profile.changeAvatar'.tr(),
                      onTap: () => AvatarPicker.show(context),
                      trailing: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Change Username / Nickname Tile
                    _buildTile(
                      isDark: isDark,
                      icon: Icons.badge_rounded,
                      iconColor: AppColors.primaryAmber,
                      title: authProv.isGuest
                          ? 'account.changeNickname'.tr()
                          : 'account.changeUsername'.tr(),
                      onTap: () =>
                          _showChangeUsernameDialog(context, authProv, isDark),
                      trailing: Icon(
                        Icons.edit_rounded,
                        size: 16,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // --- Security & Credentials Group ---
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 6),
                      child: Text(
                        'account.accountSecurity'.tr(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),

                    if (authProv.isAuthenticated) ...[
                      // Change Password Tile for registered users
                      _buildTile(
                        isDark: isDark,
                        icon: Icons.lock_reset_rounded,
                        iconColor: AppColors.accentGold,
                        title: 'account.changePassword'.tr(),
                        subtitle: '••••••••',
                        onTap: () => _showChangePasswordDialog(
                          context,
                          authProv,
                          isDark,
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted,
                        ),
                      ),
                    ] else ...[
                      // Guest Upgrade Alert Card
                      KitaCard(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.shield_outlined,
                                  color: AppColors.guestOrange,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'guest.restrictionTitle'.tr(),
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.lightTextPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'account.guestRegisterNotice'.tr(),
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.darkTextMuted
                                    : AppColors.lightTextMuted,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryAmber,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const RegisterScreen(),
                                    ),
                                  );
                                },
                                child: Text(
                                  'account.registerNow'.tr(),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // --- Account Actions (Logout & Delete Account) ---
                    if (authProv.isAuthenticated || authProv.isGuest) ...[
                      const SizedBox(height: 20),
                      KitaCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: InkWell(
                          onTap: () => _showLogoutConfirmation(
                            context,
                            authProv,
                            isDark,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.logout_rounded,
                                color: AppColors.lossRed,
                                size: 22,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  'auth.logout'.tr(),
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.lossRed,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14,
                                color: AppColors.lossRed,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    if (authProv.isAuthenticated) ...[
                      const SizedBox(height: 10),
                      KitaCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: InkWell(
                          onTap: () => _showDeleteAccountConfirmation(
                            context,
                            authProv,
                            isDark,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_forever_rounded,
                                color: AppColors.lossRed.withValues(
                                  alpha: 0.85,
                                ),
                                size: 22,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'account.deleteAccount'.tr(),
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.lossRed.withValues(
                                          alpha: 0.85,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'account.deleteAccountDesc'.tr(),
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: isDark
                                            ? AppColors.darkTextMuted
                                            : AppColors.lightTextMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14,
                                color: AppColors.lossRed.withValues(
                                  alpha: 0.85,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTile({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final tileContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBg : AppColors.lightBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: tileContent,
        ),
      );
    }
    return tileContent;
  }

  void _showChangeUsernameDialog(
    BuildContext context,
    AuthProvider authProv,
    bool isDark,
  ) {
    final controller = TextEditingController(text: authProv.displayName);
    String? errorMessage;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: isDark
                ? AppColors.darkSurface
                : AppColors.lightSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              authProv.isGuest
                  ? 'account.changeNickname'.tr()
                  : 'account.changeUsername'.tr(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLength: 15,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: authProv.isGuest
                        ? 'account.enterNewNickname'.tr()
                        : 'account.enterNewUsername'.tr(),
                    hintStyle: TextStyle(
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                    counterStyle: TextStyle(
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                    filled: true,
                    fillColor: isDark ? AppColors.darkBg : AppColors.lightBg,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: AppColors.primaryAmber,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    errorMessage!,
                    style: const TextStyle(
                      color: AppColors.lossRed,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.of(ctx).pop(),
                child: Text(
                  'common.cancel'.tr(),
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkTextMuted
                        : AppColors.lightTextMuted,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryAmber,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: isLoading
                    ? null
                    : () async {
                        final trimmed = controller.text.trim();
                        if (trimmed.length < 2) {
                          setDialogState(() {
                            errorMessage = 'auth.usernameTooShort'.tr();
                          });
                          return;
                        }
                        if (trimmed.length > 15) {
                          setDialogState(() {
                            errorMessage = 'auth.usernameTooLong'.tr();
                          });
                          return;
                        }
                        final validChars = RegExp(r'^[a-zA-Z0-9_-]+$');
                        if (!validChars.hasMatch(trimmed)) {
                          setDialogState(() {
                            errorMessage = 'auth.usernameInvalid'.tr();
                          });
                          return;
                        }

                        setDialogState(() {
                          isLoading = true;
                          errorMessage = null;
                        });

                        try {
                          await authProv.updateUsername(trimmed);
                          if (ctx.mounted) {
                            Navigator.of(ctx).pop();
                          }
                          KitaToast.show(
                            message: authProv.isGuest
                                ? 'account.nicknameUpdated'.tr()
                                : 'account.usernameUpdated'.tr(),
                            type: ToastType.success,
                          );
                        } catch (e) {
                          setDialogState(() {
                            isLoading = false;
                            if (e is DioException && e.response != null) {
                              final data = e.response?.data;
                              if (data is Map && data['error'] != null) {
                                final errCode =
                                    data['error']['code']?.toString() ?? '';
                                if (errCode == 'ERR_USER_ALREADY_EXISTS') {
                                  errorMessage = 'errUserAlreadyExists'.tr();
                                  return;
                                }
                                if (errCode == 'ERR_USERNAME_RESERVED') {
                                  errorMessage = 'errUsernameReserved'.tr();
                                  return;
                                }
                                if (errCode == 'ERR_USERNAME_INVALID') {
                                  errorMessage = 'errUsernameInvalid'.tr();
                                  return;
                                }
                              }
                            }
                            errorMessage = 'errValidationFailed'.tr();
                          });
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'common.save'.tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showChangePasswordDialog(
    BuildContext context,
    AuthProvider authProv,
    bool isDark,
  ) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isLoading = false;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          Widget buildPasswordField({
            required String label,
            required TextEditingController controller,
            required bool isObscured,
            required VoidCallback onToggleObscure,
          }) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextMuted
                        : AppColors.lightTextMuted,
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: controller,
                  obscureText: isObscured,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: isDark ? AppColors.darkBg : AppColors.lightBg,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: AppColors.primaryAmber,
                        width: 2,
                      ),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        isObscured
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        size: 18,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                      onPressed: onToggleObscure,
                    ),
                  ),
                ),
              ],
            );
          }

          return AlertDialog(
            backgroundColor: isDark
                ? AppColors.darkSurface
                : AppColors.lightSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'account.changePassword'.tr(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildPasswordField(
                    label: 'account.currentPassword'.tr(),
                    controller: currentPasswordController,
                    isObscured: obscureCurrent,
                    onToggleObscure: () =>
                        setDialogState(() => obscureCurrent = !obscureCurrent),
                  ),
                  const SizedBox(height: 12),
                  buildPasswordField(
                    label: 'account.newPassword'.tr(),
                    controller: newPasswordController,
                    isObscured: obscureNew,
                    onToggleObscure: () =>
                        setDialogState(() => obscureNew = !obscureNew),
                  ),
                  const SizedBox(height: 12),
                  buildPasswordField(
                    label: 'account.confirmNewPassword'.tr(),
                    controller: confirmPasswordController,
                    isObscured: obscureConfirm,
                    onToggleObscure: () =>
                        setDialogState(() => obscureConfirm = !obscureConfirm),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      errorMessage!,
                      style: const TextStyle(
                        color: AppColors.lossRed,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.of(ctx).pop(),
                child: Text(
                  'common.cancel'.tr(),
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkTextMuted
                        : AppColors.lightTextMuted,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryAmber,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: isLoading
                    ? null
                    : () async {
                        final current = currentPasswordController.text;
                        final newP = newPasswordController.text;
                        final confirm = confirmPasswordController.text;

                        if (current.isEmpty) {
                          setDialogState(
                            () => errorMessage = 'errMissingField'.tr(),
                          );
                          return;
                        }
                        if (newP.length < 6) {
                          setDialogState(
                            () => errorMessage = 'auth.passwordTooShort'.tr(),
                          );
                          return;
                        }
                        if (newP == current) {
                          setDialogState(
                            () => errorMessage = 'errSamePassword'.tr(),
                          );
                          return;
                        }
                        if (newP != confirm) {
                          setDialogState(
                            () =>
                                errorMessage = 'auth.passwordsDoNotMatch'.tr(),
                          );
                          return;
                        }

                        setDialogState(() {
                          isLoading = true;
                          errorMessage = null;
                        });

                        try {
                          await authProv.changePassword(
                            currentPassword: current,
                            newPassword: newP,
                          );
                          if (ctx.mounted) {
                            Navigator.of(ctx).pop();
                          }
                          KitaToast.show(
                            message: 'account.passwordUpdated'.tr(),
                            type: ToastType.success,
                          );
                        } catch (e) {
                          setDialogState(() {
                            isLoading = false;
                            if (e is DioException && e.response != null) {
                              final data = e.response?.data;
                              if (data is Map && data['error'] != null) {
                                final errCode =
                                    data['error']['code']?.toString() ?? '';
                                if (errCode == 'ERR_WRONG_PASSWORD') {
                                  errorMessage = 'errWrongPassword'.tr();
                                  return;
                                }
                                if (errCode == 'ERR_SAME_PASSWORD') {
                                  errorMessage = 'errSamePassword'.tr();
                                  return;
                                }
                              }
                            }
                            errorMessage = 'errValidationFailed'.tr();
                          });
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'common.save'.tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showLogoutConfirmation(
    BuildContext context,
    AuthProvider authProv,
    bool isDark,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        title: Text(
          'settings.logoutConfirmTitle'.tr(),
          style: TextStyle(
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'settings.logoutConfirmDesc'.tr(),
          style: TextStyle(
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'common.cancel'.tr(),
              style: TextStyle(
                color: isDark
                    ? AppColors.darkTextMuted
                    : AppColors.lightTextMuted,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.lossRed),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
              authProv.logout();
            },
            child: Text(
              'settings.confirm'.tr(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountConfirmation(
    BuildContext context,
    AuthProvider authProv,
    bool isDark,
  ) {
    bool isDeleting = false;
    final passwordController = TextEditingController();
    bool obscurePassword = true;
    String? errorMessage;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return PopScope(
            canPop: !isDeleting,
            child: AlertDialog(
              backgroundColor: isDark
                  ? AppColors.darkSurface
                  : AppColors.lightSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.lossRed,
                    size: 26,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'account.deleteAccountConfirmTitle'.tr(),
                      style: TextStyle(
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'account.deleteAccountConfirmDesc'.tr(),
                      style: TextStyle(
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'account.enterPasswordToDelete'.tr(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      enabled: !isDeleting,
                      onChanged: (_) {
                        if (errorMessage != null) {
                          setDialogState(() => errorMessage = null);
                        } else {
                          setDialogState(() {});
                        }
                      },
                      style: TextStyle(
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: 'account.deleteAccountPasswordHint'.tr(),
                        hintStyle: TextStyle(
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted,
                          fontSize: 13,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? AppColors.darkBg
                            : AppColors.lightBg,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: AppColors.lossRed,
                            width: 2,
                          ),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            size: 18,
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.lightTextMuted,
                          ),
                          onPressed: isDeleting
                              ? null
                              : () => setDialogState(
                                  () => obscurePassword = !obscurePassword,
                                ),
                        ),
                      ),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        errorMessage!,
                        style: const TextStyle(
                          color: AppColors.lossRed,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting ? null : () => Navigator.of(ctx).pop(),
                  child: Text(
                    'common.cancel'.tr(),
                    style: TextStyle(
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.lossRed,
                    disabledBackgroundColor: AppColors.lossRed.withValues(
                      alpha: 0.35,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: (isDeleting || passwordController.text.isEmpty)
                      ? null
                      : () async {
                          final password = passwordController.text;
                          setDialogState(() {
                            isDeleting = true;
                            errorMessage = null;
                          });
                          try {
                            final success = await authProv.deleteAccount(
                              password: password,
                            );
                            if (ctx.mounted) {
                              Navigator.of(ctx).pop();
                            }
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                            if (success) {
                              KitaToast.show(
                                message: 'account.accountDeleted'.tr(),
                                type: ToastType.success,
                              );
                            }
                          } catch (e) {
                            if (ctx.mounted) {
                              setDialogState(() {
                                isDeleting = false;
                                if (e is DioException && e.response != null) {
                                  final data = e.response?.data;
                                  if (data is Map && data['error'] != null) {
                                    final errCode =
                                        data['error']['code']?.toString() ?? '';
                                    if (errCode == 'ERR_WRONG_PASSWORD') {
                                      errorMessage = 'errWrongPassword'.tr();
                                      return;
                                    }
                                  }
                                }
                                errorMessage = 'errValidationFailed'.tr();
                              });
                            }
                          }
                        },
                  child: isDeleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'account.deleteAccount'.tr(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
