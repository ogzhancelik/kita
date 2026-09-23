import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/user_api_service.dart';
import '../../screens/home/leaderboard_screen.dart';
import '../common/avatar_picker.dart';
import '../common/kita_card.dart';

class DashboardLeaderboardCard extends StatefulWidget {
  const DashboardLeaderboardCard({super.key});

  @override
  State<DashboardLeaderboardCard> createState() => _DashboardLeaderboardCardState();
}

class _DashboardLeaderboardCardState extends State<DashboardLeaderboardCard> {
  final UserApiService _apiService = UserApiService();
  String _filter = 'global'; // 'global' or 'friends'
  List<UserProfile> _topPlayers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTopPlayers();
  }

  Future<void> _fetchTopPlayers() async {
    setState(() => _isLoading = true);
    try {
      final list = await _apiService.getLeaderboard(
        limit: 3,
        filter: _filter,
      );
      if (mounted) {
        setState(() {
          _topPlayers = list.take(3).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _topPlayers = [];
          _isLoading = false;
        });
      }
    }
  }

  void _onFilterChanged(String newFilter) {
    if (_filter != newFilter) {
      setState(() => _filter = newFilter);
      _fetchTopPlayers();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return KitaCard(
      padding: const EdgeInsets.all(14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with Title & Filter Switcher
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
                ),
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.emoji_events_rounded,
                      color: AppColors.ratingGold,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'dashboard.topLeaderboard'.tr(),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ],
                ),
              ),

              // Toggle: Global / Friends
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBg : AppColors.lightBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildFilterChip('global', 'dashboard.globalTab'.tr(), isDark),
                    _buildFilterChip('friends', 'dashboard.friendsTab'.tr(), isDark),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Content Area: Top 3 Podiums or Loading
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_topPlayers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                  _filter == 'friends'
                      ? 'dashboard.friendsDesc'.tr()
                      : 'leaderboard.noPlayersFound'.tr(),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
              ),
            )
          else
            InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
              ),
              borderRadius: BorderRadius.circular(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // If 2nd exists
                  if (_topPlayers.length > 1)
                    Expanded(child: _buildPodiumItem(_topPlayers[1], 2, isDark)),
                  // 1st place
                  Expanded(child: _buildPodiumItem(_topPlayers[0], 1, isDark)),
                  // If 3rd exists
                  if (_topPlayers.length > 2)
                    Expanded(child: _buildPodiumItem(_topPlayers[2], 3, isDark))
                  else
                    const Spacer(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label, bool isDark) {
    final isSelected = _filter == filterKey;
    return InkWell(
      onTap: () => _onFilterChanged(filterKey),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryGreen
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected
                ? Colors.white
                : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
          ),
        ),
      ),
    );
  }

  Widget _buildPodiumItem(UserProfile player, int rank, bool isDark) {
    final avatarIdx = player.username.hashCode.abs() % AvatarPicker.avatars.length;
    final avatarItem = AvatarPicker.avatars[avatarIdx];
    final Color medalColor;
    final double avatarSize;

    switch (rank) {
      case 1:
        medalColor = const Color(0xFFFFD700);
        avatarSize = 52.0;
        break;
      case 2:
        medalColor = const Color(0xFFC0C0C0);
        avatarSize = 44.0;
        break;
      case 3:
      default:
        medalColor = const Color(0xFFCD7F32);
        avatarSize = 40.0;
        break;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                color: avatarItem.accentColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: medalColor,
                  width: rank == 1 ? 2.5 : 1.8,
                ),
              ),
              child: Icon(
                avatarItem.icon,
                color: avatarItem.accentColor,
                size: avatarSize * 0.55,
              ),
            ),
            Positioned(
              bottom: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: medalColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '#$rank',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          player.username,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: rank == 1 ? 13 : 12,
            fontWeight: rank == 1 ? FontWeight.w800 : FontWeight.w600,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${player.rating}',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppColors.ratingGold,
          ),
        ),
      ],
    );
  }
}
