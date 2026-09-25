import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/match_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/local_match_history_service.dart';
import '../../../data/services/match_api_service.dart';
import '../../providers/auth_provider.dart';
import '../../screens/game/match_replay_screen.dart';
import '../../screens/home/match_history_screen.dart';
import '../common/avatar_picker.dart';
import '../common/kita_card.dart';

class DashboardMatchHistoryCard extends StatefulWidget {
  const DashboardMatchHistoryCard({super.key});

  @override
  State<DashboardMatchHistoryCard> createState() => _DashboardMatchHistoryCardState();
}

class _DashboardMatchHistoryCardState extends State<DashboardMatchHistoryCard> {
  final MatchApiService _matchApiService = MatchApiService();
  List<MatchRecordModel> _matches = [];
  bool _isLoading = true;
  bool _hasMore = false;
  int _offset = 0;
  static const int _pageSize = 5;

  @override
  void initState() {
    super.initState();
    _fetchMatches(reset: true);
  }

  Future<void> _fetchMatches({bool reset = false}) async {
    final authProv = context.read<AuthProvider>();
    final user = authProv.currentUser;
    final isGuest = authProv.isGuest || user == null;

    if (reset) {
      _offset = 0;
      if (!_isLoading && mounted) {
        setState(() {
          _isLoading = true;
        });
      }
    }

    try {
      final showOffline =
          await LocalMatchHistoryService.instance.getShowOfflineMatches();

      final offlineList = showOffline
          ? await LocalMatchHistoryService.instance.getMatches()
          : <MatchRecordModel>[];

      if (isGuest) {
        if (mounted) {
          setState(() {
            _matches = offlineList;
            _isLoading = false;
            _hasMore = false;
          });
        }
        return;
      }

      final onlineList = await _matchApiService.getUserMatches(
        user.id,
        limit: _pageSize,
        offset: _offset,
      );

      if (mounted) {
        setState(() {
          final List<MatchRecordModel> current = reset ? [] : List.from(_matches);
          if (reset) {
            current.addAll(onlineList);
            if (showOffline) {
              current.addAll(offlineList);
            }
            current.sort((a, b) => b.startedAt.compareTo(a.startedAt));
            _matches = current.take(_pageSize).toList();
          } else {
            current.addAll(onlineList);
            current.sort((a, b) => b.startedAt.compareTo(a.startedAt));
            _matches = current;
          }
          _hasMore = onlineList.length == _pageSize;
          _offset += onlineList.length;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _openReplay(MatchRecordModel match) {
    final isOffline = match.isOffline || match.id.startsWith('offline');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MatchReplayScreen(
          match: isOffline || match.moves.isNotEmpty ? match : null,
          matchId: isOffline ? null : match.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProv = context.watch<AuthProvider>();
    final currentUserId = authProv.currentUser?.id ?? '';
    final isGuest = authProv.isGuest;

    return KitaCard(
      padding: const EdgeInsets.all(14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          InkWell(
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MatchHistoryScreen()),
              );
              // Refresh on return in case offline toggle or games changed
              _fetchMatches(reset: true);
            },
            borderRadius: BorderRadius.circular(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.history_rounded,
                      color: AppColors.accent,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'dashboard.recentMatches'.tr(),
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
                if (_matches.isNotEmpty)
                  Text(
                    '${_matches.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (_isLoading && _matches.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_matches.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.history_toggle_off_rounded,
                      size: 32,
                      color: isDark
                          ? AppColors.darkTextMuted.withValues(alpha: 0.5)
                          : AppColors.lightTextMuted.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isGuest
                          ? 'dashboard.guestNotice'.tr()
                          : 'dashboard.noRecentMatches'.tr(),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _matches.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final match = _matches[index];
                return _buildMatchTile(match, currentUserId, isDark);
              },
            ),
            if (_hasMore) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => _fetchMatches(reset: false),
                  child: Text(
                    'dashboard.loadMore'.tr(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  String _getAiDifficultyLabel(UserProfile? opponent) {
    final rating = opponent?.rating ?? 1200;
    final username = (opponent?.username ?? '').toLowerCase();

    if (rating <= 1000 || username.contains('easy') || username.contains('beginner')) {
      return 'game.easy'.tr();
    } else if (rating >= 1400 || username.contains('hard') || username.contains('grandmaster')) {
      return 'game.hard'.tr();
    } else {
      return 'game.medium'.tr();
    }
  }

  Widget _buildPlayerAvatar(UserProfile? player, bool isDark) {
    final int avatarIndex = player?.avatarIndex ?? 0;
    final avatarItem = AvatarPicker.avatars[avatarIndex % AvatarPicker.avatars.length];
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: avatarItem.accentColor.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(
          color: avatarItem.accentColor.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: Center(
        child: Icon(
          avatarItem.icon,
          size: 16,
          color: avatarItem.accentColor,
        ),
      ),
    );
  }

  Widget _buildAiAvatar(bool isDark) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: AppColors.primaryLight.withValues(alpha: 0.7),
          width: 1.2,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.smart_toy_rounded,
          size: 17,
          color: AppColors.primaryLight,
        ),
      ),
    );
  }

  Widget _buildEndReasonBadge(MatchRecordModel match) {
    final bool isTimeout = match.isTimeout;
    final icon = isTimeout ? Icons.timer_outlined : Icons.flag_outlined;
    final tooltip = isTimeout ? 'online.reasonTimeout'.tr() : 'online.reasonResigned'.tr();
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: AppColors.lossRed.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: AppColors.lossRed.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
        child: Center(
          child: Icon(
            icon,
            size: 11,
            color: AppColors.lossRed,
          ),
        ),
      ),
    );
  }

  Widget _buildMatchTile(MatchRecordModel match, String currentUserId, bool isDark) {
    final bool isOffline = match.isOffline || match.id.startsWith('offline');
    final bool isWhite = isOffline
        ? (match.blackPlayerId == 'bot')
        : (match.whitePlayerId == currentUserId);
    final opponent = isWhite ? match.blackPlayer : match.whitePlayer;
    final bool isVsAi = isOffline ||
        match.blackPlayerId == 'bot' ||
        match.whitePlayerId == 'bot' ||
        (opponent?.id == 'bot') ||
        (opponent?.username.toLowerCase().contains('bot') ?? false);
    final opponentName = opponent?.username ??
        (isOffline ? 'game.aiBot'.tr() : (isWhite ? 'Black' : 'White'));
    final opponentRating = opponent?.rating ?? 1200;

    final isDraw = match.result == 'draw';
    final bool isWinner;
    final bool isLoser;

    if (isOffline) {
      final playerSide = isWhite ? 'white' : 'black';
      final winningSide = match.winnerId == match.whitePlayerId
          ? 'white'
          : (match.winnerId == match.blackPlayerId ? 'black' : null);
      isWinner = winningSide != null && winningSide == playerSide;
      isLoser = winningSide != null && winningSide != playerSide && !isDraw;
    } else {
      isWinner = match.winnerId != null && match.winnerId == currentUserId;
      isLoser =
          match.winnerId != null && match.winnerId != currentUserId && !isDraw;
    }

    final Color outcomeColor;
    if (isWinner) {
      outcomeColor = AppColors.victory;
    } else if (isLoser) {
      outcomeColor = AppColors.lossRed;
    } else if (isDraw) {
      outcomeColor = AppColors.drawGray;
    } else {
      outcomeColor = AppColors.accentGold;
    }

    final dateStr = DateFormat('dd.MM').format(match.startedAt.toLocal());

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBg : AppColors.lightBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          // Left: Result Indicator Color Bar
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: outcomeColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),

          // Player / AI PP (vertically centered next to text block)
          if (isVsAi) _buildAiAvatar(isDark) else _buildPlayerAvatar(opponent, isDark),
          const SizedBox(width: 10),

          // Match Details (Top: Name / AI Difficulty, Bottom: Moves & Date)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    if (isVsAi) ...[
                      Flexible(
                        child: Text(
                          _getAiDifficultyLabel(opponent),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ] else ...[
                      Flexible(
                        child: Text(
                          opponentName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '($opponentRating)',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.ratingGold,
                        ),
                      ),
                    ],
                    if (match.isTimeout || match.isResigned) ...[
                      const SizedBox(width: 6),
                      _buildEndReasonBadge(match),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${match.totalMoves} ${'game.moveCount'.tr(args: ['']).trim()} • $dateStr',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
              ],
            ),
          ),

          // Replay Button
          IconButton(
            icon: const Icon(
              Icons.play_circle_fill_rounded,
              color: AppColors.winBlue,
              size: 26,
            ),
            tooltip: 'dashboard.watchReplay'.tr(),
            onPressed: () => _openReplay(match),
          ),
        ],
      ),
    );
  }
}
