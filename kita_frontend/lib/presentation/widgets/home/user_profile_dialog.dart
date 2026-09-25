import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/user_api_service.dart';
import '../../providers/auth_provider.dart';
import '../common/avatar_picker.dart';
import '../common/stat_badge.dart';

class UserProfileDialog extends StatefulWidget {
  final String? userId;
  final UserProfile? profile;
  final String? fallbackName;
  final int? fallbackAvatarIndex;
  final int? fallbackRating;
  final bool? isGuest;
  final bool? isBot;
  final VoidCallback? onInvite;

  const UserProfileDialog({
    super.key,
    this.userId,
    this.profile,
    this.fallbackName,
    this.fallbackAvatarIndex,
    this.fallbackRating,
    this.isGuest,
    this.isBot,
    this.onInvite,
  });

  static Future<void> show(
    BuildContext context, {
    String? userId,
    UserProfile? profile,
    String? fallbackName,
    int? fallbackAvatarIndex,
    int? fallbackRating,
    bool? isGuest,
    bool? isBot,
    VoidCallback? onInvite,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UserProfileDialog(
        userId: userId,
        profile: profile,
        fallbackName: fallbackName,
        fallbackAvatarIndex: fallbackAvatarIndex,
        fallbackRating: fallbackRating,
        isGuest: isGuest,
        isBot: isBot,
        onInvite: onInvite,
      ),
    );
  }

  @override
  State<UserProfileDialog> createState() => _UserProfileDialogState();
}

class _UserProfileDialogState extends State<UserProfileDialog> {
  UserProfile? _fetchedProfile;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initProfileFetch();
  }

  void _initProfileFetch() {
    final authProv = context.read<AuthProvider>();
    final isCurrent = (widget.userId == null && widget.profile == null) ||
        (authProv.currentUser != null &&
            (widget.userId == authProv.currentUser!.id ||
                widget.profile?.id == authProv.currentUser!.id));

    if (isCurrent) return;

    if (widget.profile != null) {
      _fetchedProfile = widget.profile;
      return;
    }

    final isBot = widget.isBot == true || widget.userId == 'bot';
    final isGuest = widget.isGuest == true ||
        (widget.userId != null && widget.userId!.startsWith('guest-'));

    if (isBot || isGuest) return;

    final targetId = widget.userId;
    if (targetId != null && targetId.isNotEmpty) {
      _isLoading = true;
      UserApiService().getUserProfile(targetId).then((user) {
        if (mounted) {
          setState(() {
            _fetchedProfile = user;
            _isLoading = false;
          });
        }
      }).catchError((_) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProv = context.watch<AuthProvider>();

    final isCurrent = (widget.userId == null && widget.profile == null) ||
        (authProv.currentUser != null &&
            (widget.userId == authProv.currentUser!.id ||
                widget.profile?.id == authProv.currentUser!.id));

    final isBot = widget.isBot == true || widget.userId == 'bot';
    final isGuest = isCurrent
        ? authProv.isGuest
        : (widget.isGuest == true ||
            (widget.userId != null && widget.userId!.startsWith('guest-')));

    final UserProfile? user = isCurrent
        ? authProv.currentUser
        : (_fetchedProfile ?? widget.profile);

    final String displayName = isCurrent
        ? authProv.displayName
        : (user?.username ??
            widget.fallbackName ??
            (isBot ? 'game.aiBot'.tr() : 'Guest'));

    final int rawAvatarIndex = isCurrent
        ? authProv.avatarIndex
        : (user?.avatarIndex ?? widget.fallbackAvatarIndex ?? (isBot ? 7 : 0));

    final avatarItem = AvatarPicker.avatars[rawAvatarIndex % AvatarPicker.avatars.length];

    final int rating = isCurrent
        ? (user?.rating ?? 1200)
        : (user?.rating ?? widget.fallbackRating ?? 1200);

    String badgeText;
    Color badgeColor;
    if (isBot) {
      badgeText = 'profile.botPlayer'.tr();
      badgeColor = AppColors.accentGold;
    } else if (isGuest) {
      badgeText = 'profile.guestPlayer'.tr();
      badgeColor = AppColors.guestOrange;
    } else {
      badgeText = 'profile.registeredPlayer'.tr();
      badgeColor = AppColors.winBlue;
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'profile.title'.tr(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Avatar & Change Avatar Button (only for current user)
                    Center(
                      child: Stack(
                        children: [
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              color: avatarItem.accentColor.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: avatarItem.accentColor,
                                width: 3,
                              ),
                            ),
                            child: Icon(
                              avatarItem.icon,
                              color: avatarItem.accentColor,
                              size: 46,
                            ),
                          ),
                          if (isCurrent)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: InkWell(
                                onTap: () => AvatarPicker.show(context),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryGreen,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.edit_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Display Name
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Badges
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        StatBadge(
                          rating: rating,
                          isGuest: isGuest,
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: badgeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Stats Grid
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkBg : AppColors.lightBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'profile.stats'.tr(),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              if (_isLoading)
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatItem(
                                  label: 'profile.matchesCount'.tr(),
                                  value: '${user?.totalGames ?? 0}',
                                  icon: Icons.sports_esports_rounded,
                                  color: AppColors.winBlue,
                                  isDark: isDark,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatItem(
                                  label: 'profile.winRate'.tr(),
                                  value: '${(user?.winRate ?? 0).toStringAsFixed(1)}%',
                                  icon: Icons.trending_up_rounded,
                                  color: AppColors.winStat,
                                  isDark: isDark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatItem(
                                  label: 'profile.rating'.tr(),
                                  value: '$rating',
                                  icon: Icons.military_tech_rounded,
                                  color: AppColors.ratingGold,
                                  isDark: isDark,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatItem(
                                  label: 'profile.wld'.tr(),
                                  value: '${user?.wins ?? 0} / ${user?.losses ?? 0} / ${user?.draws ?? 0}',
                                  icon: Icons.analytics_rounded,
                                  color: AppColors.primaryVibrant,
                                  isDark: isDark,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Quick Action button (e.g. Invite to Match if opened from Friends section)
                    if (widget.onInvite != null && !isCurrent) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            widget.onInvite!();
                          },
                          icon: const Icon(Icons.sports_esports_rounded, size: 20),
                          label: Text(
                            'online.sendInvite'.tr(),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: AppColors.darkTextPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
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

  Widget _buildStatItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
