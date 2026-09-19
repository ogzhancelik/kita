import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/user_api_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/kita_app_bar.dart';
import '../../widgets/common/kita_button.dart';
import '../../widgets/common/kita_card.dart';
import '../../widgets/common/responsive_layout.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final UserApiService _apiService = UserApiService();
  List<UserProfile> _players = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _apiService.getLeaderboard(limit: 50);
      if (mounted) {
        setState(() {
          _players = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUserId = context.watch<AuthProvider>().currentUser?.id;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: KitaAppBar(
        title: 'leaderboard.title'.tr(),
        showBack: true,
        showAuthActions: false,
      ),
      body: ResponsiveLayout(
        maxWidth: 640,
        child: RefreshIndicator(
          onRefresh: _loadLeaderboard,
          color: AppColors.primaryGreen,
          child: _buildBody(isDark, currentUserId),
        ),
      ),
    );
  }

  Widget _buildBody(bool isDark, String? currentUserId) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primaryGreen,
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 54,
                color: AppColors.lossRed,
              ),
              const SizedBox(height: 16),
              Text(
                'leaderboard.error'.tr(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              KitaButton(
                text: 'leaderboard.retry'.tr(),
                icon: Icons.refresh_rounded,
                variant: KitaButtonVariant.primary,
                onPressed: _loadLeaderboard,
              ),
            ],
          ),
        ),
      );
    }

    if (_players.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.emoji_events_outlined,
                  size: 60,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
                const SizedBox(height: 14),
                Text(
                  'leaderboard.empty'.tr(),
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                KitaButton(
                  text: 'leaderboard.refresh'.tr(),
                  icon: Icons.refresh_rounded,
                  variant: KitaButtonVariant.outline,
                  height: 40,
                  onPressed: _loadLeaderboard,
                ),
              ],
            ),
          ),
        ],
      );
    }

    final top3 = _players.take(3).toList();
    final remaining = _players.skip(3).toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
      children: [
        // 1. Top 3 Podium (if we have at least 2 or 3 players)
        if (top3.length >= 2) ...[
          _buildPodium(top3, isDark, currentUserId),
          const SizedBox(height: 16),
        ],

        // 2. Table Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: Text(
                  '#',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'leaderboard.player'.tr(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
              ),
              Text(
                '${'leaderboard.winRate'.tr()} / ${'leaderboard.rating'.tr()}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
            ],
          ),
        ),

        // 3. Player Cards (All if < 2, or remaining players 4+)
        ...(top3.length < 2 ? _players : remaining).asMap().entries.map((entry) {
          final rank = (top3.length < 2 ? 0 : 3) + entry.key + 1;
          final player = entry.value;
          final isCurrentUser = player.id == currentUserId;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: _buildPlayerRow(
              rank: rank,
              player: player,
              isDark: isDark,
              isCurrentUser: isCurrentUser,
            ),
          );
        }),

        const SizedBox(height: 24),
      ],
    );
  }

  // --- Podium for Top 3 ---
  Widget _buildPodium(List<UserProfile> top3, bool isDark, String? currentUserId) {
    final first = top3[0];
    final second = top3.length > 1 ? top3[1] : null;
    final third = top3.length > 2 ? top3[2] : null;

    return KitaCard(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.emoji_events_rounded, color: AppColors.ratingGold, size: 20),
              const SizedBox(width: 6),
              Text(
                'leaderboard.topPlayers'.tr(),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // 2nd Place (Left)
              if (second != null)
                Flexible(
                  child: _buildPodiumColumn(
                    player: second,
                    rank: 2,
                    medalColor: const Color(0xFFC0C0C0), // Silver
                    height: 105,
                    isDark: isDark,
                    isCurrentUser: second.id == currentUserId,
                  ),
                ),

              // 1st Place (Center - Highest)
              Flexible(
                child: _buildPodiumColumn(
                  player: first,
                  rank: 1,
                  medalColor: AppColors.ratingGold, // Gold
                  height: 130,
                  isDark: isDark,
                  isCurrentUser: first.id == currentUserId,
                ),
              ),

              // 3rd Place (Right)
              if (third != null)
                Flexible(
                  child: _buildPodiumColumn(
                    player: third,
                    rank: 3,
                    medalColor: const Color(0xFFCD7F32), // Bronze
                    height: 90,
                    isDark: isDark,
                    isCurrentUser: third.id == currentUserId,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumColumn({
    required UserProfile player,
    required int rank,
    required Color medalColor,
    required double height,
    required bool isDark,
    required bool isCurrentUser,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Crown or rank badge
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            CircleAvatar(
              radius: rank == 1 ? 26 : 22,
              backgroundColor: medalColor.withValues(alpha: 0.25),
              child: CircleAvatar(
                radius: rank == 1 ? 23 : 19,
                backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                child: Text(
                  player.username.isNotEmpty ? player.username[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: rank == 1 ? 16 : 14,
                    fontWeight: FontWeight.bold,
                    color: medalColor,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: medalColor,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: medalColor.withValues(alpha: 0.5),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '#$rank',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Username
        Text(
          player.username,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isCurrentUser ? FontWeight.w900 : FontWeight.bold,
            color: isCurrentUser
                ? AppColors.primaryGreen
                : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
          ),
        ),

        const SizedBox(height: 2),

        // Rating
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: medalColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '${player.rating} ELO',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: medalColor,
            ),
          ),
        ),
      ],
    );
  }

  // --- Regular Player Row ---
  Widget _buildPlayerRow({
    required int rank,
    required UserProfile player,
    required bool isDark,
    required bool isCurrentUser,
  }) {
    Color rankColor = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    if (rank == 1) rankColor = AppColors.ratingGold;
    if (rank == 2) rankColor = const Color(0xFFC0C0C0);
    if (rank == 3) rankColor = const Color(0xFFCD7F32);

    return KitaCard(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      borderColor: isCurrentUser ? AppColors.primaryGreen : null,
      backgroundColor: isCurrentUser
          ? (isDark
              ? AppColors.primaryGreen.withValues(alpha: 0.08)
              : AppColors.primaryGreen.withValues(alpha: 0.06))
          : null,
      child: Row(
        children: [
          // Rank Number
          SizedBox(
            width: 32,
            child: Text(
              '#$rank',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: rankColor,
              ),
            ),
          ),

          // Avatar
          CircleAvatar(
            radius: 16,
            backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            child: Text(
              player.username.isNotEmpty ? player.username[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Username & Record (W/L/D)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        player.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: isCurrentUser ? FontWeight.w900 : FontWeight.w700,
                          color: isCurrentUser
                              ? AppColors.primaryGreen
                              : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                        ),
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'leaderboard.you'.tr(),
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${player.wins}${'leaderboard.wins'.tr()} · ${player.losses}${'leaderboard.losses'.tr()} · ${player.draws}${'leaderboard.draws'.tr()} (${player.totalGames} ${'leaderboard.games'.tr()})',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Win Rate & Rating Badge
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.ratingGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.ratingGold.withValues(alpha: 0.5),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, size: 13, color: AppColors.ratingGold),
                    const SizedBox(width: 3),
                    Text(
                      '${player.rating}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ratingGold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '%${player.winRate.toStringAsFixed(1)} ${'leaderboard.winRate'.tr()}',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: player.winRate >= 50
                      ? AppColors.primaryGreen
                      : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
