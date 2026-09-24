import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/match_model.dart';
import '../../../data/services/match_api_service.dart';
import '../../providers/auth_provider.dart';
import '../../screens/game/match_replay_screen.dart';
import '../../screens/home/match_history_screen.dart';
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

    if (authProv.isGuest || user == null) {
      if (mounted) {
        setState(() {
          _matches = [];
          _isLoading = false;
          _hasMore = false;
        });
      }
      return;
    }

    if (reset) {
      _offset = 0;
      if (!_isLoading && mounted) {
        setState(() {
          _isLoading = true;
        });
      }
    }

    try {
      final list = await _matchApiService.getUserMatches(
        user.id,
        limit: _pageSize,
        offset: _offset,
      );

      if (mounted) {
        setState(() {
          if (reset) {
            _matches = list;
          } else {
            _matches.addAll(list);
          }
          _hasMore = list.length == _pageSize;
          _offset += list.length;
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MatchReplayScreen(matchId: match.id),
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
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MatchHistoryScreen()),
            ),
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
          else if (isGuest || _matches.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.history_toggle_off_rounded,
                      size: 32,
                      color: isDark ? AppColors.darkTextMuted.withValues(alpha: 0.5) : AppColors.lightTextMuted.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isGuest ? 'dashboard.guestNotice'.tr() : 'dashboard.noRecentMatches'.tr(),
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

  Widget _buildMatchTile(MatchRecordModel match, String currentUserId, bool isDark) {
    final isWhite = match.whitePlayerId == currentUserId;
    final opponent = isWhite ? match.blackPlayer : match.whitePlayer;
    final opponentName = opponent?.username ?? (isWhite ? 'Black' : 'White');
    final opponentRating = opponent?.rating ?? 1200;

    final isWinner = match.winnerId != null && match.winnerId == currentUserId;
    final isLoser = match.winnerId != null && match.winnerId != currentUserId && match.result != 'draw';
    final isDraw = match.result == 'draw';

    final Color outcomeColor;
    final String outcomeText;
    if (isWinner) {
      outcomeColor = AppColors.victory;
      outcomeText = 'history.victory'.tr();
    } else if (isLoser) {
      outcomeColor = AppColors.lossRed;
      outcomeText = 'history.defeat'.tr();
    } else if (isDraw) {
      outcomeColor = AppColors.drawGray;
      outcomeText = 'history.draw'.tr();
    } else {
      outcomeColor = AppColors.accentGold;
      outcomeText = match.result.toUpperCase();
    }

    final dateStr = DateFormat('dd.MM HH:mm').format(match.startedAt.toLocal());

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
          // Outcome Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: outcomeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: outcomeColor.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: Text(
              outcomeText,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: outcomeColor,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Match Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'vs $opponentName',
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
                ),
                const SizedBox(height: 2),
                Text(
                  '${match.totalMoves} ${'game.moveCount'.tr(args: ['']).trim()} • $dateStr',
                  style: TextStyle(
                    fontSize: 10.5,
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
