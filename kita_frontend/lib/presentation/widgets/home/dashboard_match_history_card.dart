import 'dart:async';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/navigation/app_route_observer.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/match_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/local_match_history_service.dart';
import '../../../data/services/match_api_service.dart';
import '../../providers/auth_provider.dart';
import '../../screens/game/match_replay_screen.dart';
import '../../screens/home/match_history_screen.dart';
import '../common/kita_avatar.dart';
import '../common/kita_card.dart';

class DashboardMatchHistoryCard extends StatefulWidget {
  const DashboardMatchHistoryCard({super.key});

  @override
  State<DashboardMatchHistoryCard> createState() =>
      _DashboardMatchHistoryCardState();
}

class _DashboardMatchHistoryCardState extends State<DashboardMatchHistoryCard>
    with RouteAware {
  final MatchApiService _matchApiService = MatchApiService();
  List<MatchRecordModel> _matches = [];
  bool _isLoading = true;
  bool _isFetching = false;
  bool _needsRefetch = false;
  bool _hasMore = false;
  int _offset = 0;
  static const int _pageSize = 5;

  String? _lastUserId;
  bool? _lastIsGuest;
  bool? _lastIsOnlineUnavailable;
  bool _routeSubscribed = false;

  @override
  void initState() {
    super.initState();
    LocalMatchHistoryService.instance.matchHistoryRevision.addListener(
      _onRevisionChanged,
    );
    _fetchMatches(reset: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_routeSubscribed) {
      final modalRoute = ModalRoute.of(context);
      if (modalRoute != null) {
        appRouteObserver.subscribe(this, modalRoute);
        _routeSubscribed = true;
      }
    }

    final authProv = context.read<AuthProvider>();
    final currentUserId = authProv.currentUser?.id;
    final currentIsGuest = authProv.isGuest;
    final currentIsOnlineUnavailable = authProv.isOnlineUnavailable;
    if (_lastUserId != currentUserId ||
        _lastIsGuest != currentIsGuest ||
        _lastIsOnlineUnavailable != currentIsOnlineUnavailable) {
      _lastUserId = currentUserId;
      _lastIsGuest = currentIsGuest;
      _lastIsOnlineUnavailable = currentIsOnlineUnavailable;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fetchMatches(reset: true);
      });
    }
  }

  @override
  void dispose() {
    if (_routeSubscribed) {
      appRouteObserver.unsubscribe(this);
    }
    LocalMatchHistoryService.instance.matchHistoryRevision.removeListener(
      _onRevisionChanged,
    );
    super.dispose();
  }

  @override
  void didPopNext() {
    // When returning to dashboard from match screen, replay screen, or history screen,
    // automatically refresh recent matches.
    _fetchMatches(reset: true);
  }

  void _onRevisionChanged() {
    if (mounted) {
      _fetchMatches(reset: true);
    }
  }

  Future<void> _fetchMatches({bool reset = false}) async {
    if (!mounted) return;
    if (_isFetching) {
      if (reset) _needsRefetch = true;
      return;
    }
    _isFetching = true;
    _needsRefetch = false;

    final authProv = context.read<AuthProvider>();
    final user = authProv.currentUser;
    final isGuest = authProv.isGuest || user == null;
    final isOnlineUnavailable = authProv.isOnlineUnavailable;

    if (reset) {
      _offset = 0;
      if (!_isLoading && mounted) {
        setState(() {
          _isLoading = true;
        });
      }
    }

    try {
      final showOffline = await LocalMatchHistoryService.instance
          .getShowOfflineMatches(userId: user?.id, isGuest: isGuest);

      final offlineList = showOffline
          ? await LocalMatchHistoryService.instance.getMatches(
              userId: user?.id,
              isGuest: isGuest,
            )
          : <MatchRecordModel>[];

      // Immediately display local offline matches so card does not show a blank loading state
      if (reset && showOffline && offlineList.isNotEmpty && mounted) {
        setState(() {
          _matches = offlineList.take(_pageSize).toList();
          _isLoading = false;
        });
      }

      List<MatchRecordModel> onlineList = [];
      if (!isGuest && !isOnlineUnavailable) {
        try {
          onlineList = await _matchApiService
              .getUserMatches(user.id, limit: _pageSize, offset: _offset)
              .timeout(const Duration(seconds: 3));
        } catch (e) {
          debugPrint(
            '[DashboardMatchHistoryCard] Offline or error fetching online matches: $e',
          );
          onlineList = [];
          if (e is TimeoutException ||
              (e is DioException &&
                  (e.type == DioExceptionType.connectionTimeout ||
                      e.type == DioExceptionType.connectionError ||
                      e.type == DioExceptionType.receiveTimeout))) {
            if (mounted) {
              authProv.setServerDown(true);
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          final List<MatchRecordModel> current = reset
              ? []
              : List.from(_matches);
          if (reset) {
            current.addAll(onlineList);
            if (showOffline) {
              current.addAll(offlineList);
            }
            current.sort((a, b) => b.startedAt.compareTo(a.startedAt));
            final seenIds = <String>{};
            final deduplicated = <MatchRecordModel>[];
            for (final m in current) {
              if (seenIds.add(m.id)) {
                deduplicated.add(m);
              }
            }
            _matches = deduplicated.take(_pageSize).toList();
            _hasMore =
                onlineList.length == _pageSize ||
                deduplicated.length > _matches.length;
          } else {
            if (onlineList.isNotEmpty) {
              current.addAll(onlineList);
            }
            if (showOffline) {
              current.addAll(offlineList);
            }
            current.sort((a, b) => b.startedAt.compareTo(a.startedAt));
            final seenIds = <String>{};
            final deduplicated = <MatchRecordModel>[];
            for (final m in current) {
              if (seenIds.add(m.id)) {
                deduplicated.add(m);
              }
            }
            final nextCount = _matches.length + _pageSize;
            _matches = deduplicated.take(nextCount).toList();
            _hasMore =
                onlineList.length == _pageSize ||
                deduplicated.length > _matches.length;
          }
          _offset += onlineList.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[DashboardMatchHistoryCard] Unexpected error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } finally {
      _isFetching = false;
      if (_needsRefetch && mounted) {
        _needsRefetch = false;
        _fetchMatches(reset: true);
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
              children: [
                const Icon(
                  Icons.history_rounded,
                  color: AppColors.sectionMatches,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'dashboard.recentMatches'.tr(),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: isDark
                      ? AppColors.darkTextMuted
                      : AppColors.lightTextMuted,
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
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
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
                      color: AppColors.primaryAmber,
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
    final username = (opponent?.username ?? '').toLowerCase();

    if (username.contains('grandmaster') || username.contains('büyük')) {
      return 'game.grandmaster'.tr();
    } else if (username.contains('novice') || username.contains('acemi')) {
      return 'game.novice'.tr();
    } else if (username.contains('easy') ||
        username.contains('beginner') ||
        username.contains('başlangıç')) {
      return 'game.easy'.tr();
    } else if (username.contains('hard') ||
        username.contains('master') ||
        username.contains('usta')) {
      return 'game.hard'.tr();
    } else if (username.contains('medium') ||
        username.contains('intermediate') ||
        username.contains('orta')) {
      return 'game.medium'.tr();
    }

    final rating = opponent?.rating ?? 1200;
    if (rating <= 950) {
      return 'game.novice'.tr();
    } else if (rating <= 1100) {
      return 'game.easy'.tr();
    } else if (rating <= 1300) {
      return 'game.medium'.tr();
    } else if (rating <= 1450) {
      return 'game.hard'.tr();
    } else {
      return 'game.grandmaster'.tr();
    }
  }

  Widget _buildPlayerAvatar(
    UserProfile? player,
    bool isDark, {
    bool? isDeleted,
    bool? isGuest,
  }) {
    final rawName = player?.username;
    final bool isNameUuid =
        rawName != null &&
        rawName.length >= 32 &&
        RegExp(r'^[0-9a-fA-F-]{32,}$').hasMatch(rawName);
    final bool effectiveDeleted =
        isDeleted ??
        (rawName == '[Deleted]' ||
            isNameUuid ||
            (player?.id != null && player!.id.contains('deleted')));
    final bool effectiveGuest =
        isGuest ??
        ((player?.id != null && player!.id.startsWith('guest-')) ||
            (rawName != null && rawName.toLowerCase().startsWith('guest')));

    return KitaAvatar(
      avatarIndex: player?.avatarIndex ?? 0,
      avatarCustom: player?.avatarCustom,
      size: 28,
      fontSize: 14,
      iconSize: 16,
      borderWidth: 1.0,
      isDeleted: effectiveDeleted,
      isGuest: effectiveGuest,
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

  Widget _buildLocalCoopAvatar(bool isDark) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.7),
          width: 1.2,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.people_outline_rounded,
          size: 17,
          color: AppColors.accent,
        ),
      ),
    );
  }

  Widget _buildEndReasonBadge(MatchRecordModel match, bool isDark) {
    final bool isTimeout = match.isTimeout;
    final bool isResigned = match.isResigned;
    final bool isDrawOffer = match.isDrawAgreement;

    final IconData icon;
    final String tooltip;
    final Color badgeColor;

    if (isTimeout) {
      icon = Icons.timer_outlined;
      tooltip = 'online.reasonTimeout'.tr();
      badgeColor = AppColors.lossRed;
    } else if (isResigned) {
      icon = Icons.flag_outlined;
      tooltip = 'online.reasonResigned'.tr();
      badgeColor = AppColors.lossRed;
    } else if (isDrawOffer) {
      icon = Icons.handshake_outlined;
      tooltip = 'online.reasonDrawAgreement'.tr();
      badgeColor = AppColors.drawYellow;
    } else {
      return const SizedBox.shrink();
    }

    return Tooltip(
      message: tooltip,
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: badgeColor.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
        child: Center(child: Icon(icon, size: 11, color: badgeColor)),
      ),
    );
  }

  Widget _buildMatchTile(
    MatchRecordModel match,
    String currentUserId,
    bool isDark,
  ) {
    final bool isOffline = match.isOffline || match.id.startsWith('offline');
    final bool isCoop = match.isLocalCoop;
    final bool isWhite = match.isUserWhite(currentUserId);
    final opponent = isWhite ? match.blackPlayer : match.whitePlayer;
    final bool isVsAi = match.isVsAi;
    final rawOpponentName = opponent?.username;
    final bool isNameUuid =
        rawOpponentName != null &&
        rawOpponentName.length >= 32 &&
        RegExp(r'^[0-9a-fA-F-]{32,}$').hasMatch(rawOpponentName);
    final bool isOpponentDeleted =
        rawOpponentName == '[Deleted]' ||
        isNameUuid ||
        (opponent?.id != null && opponent!.id.contains('deleted'));
    final bool isOpponentGuest =
        (opponent?.id != null && opponent!.id.startsWith('guest-')) ||
        (rawOpponentName != null &&
            rawOpponentName.toLowerCase().startsWith('guest'));
    final opponentName =
        (opponent?.id == 'bot' || rawOpponentName == 'game.aiBot' || isVsAi)
        ? 'game.aiBot'.tr()
        : ((rawOpponentName != null &&
                  rawOpponentName.isNotEmpty &&
                  !isNameUuid)
              ? rawOpponentName
              : (isOpponentDeleted
                    ? '[Deleted]'
                    : (isOffline
                          ? 'game.aiBot'.tr()
                          : (isWhite
                                ? 'history.blackTeam'.tr()
                                : 'history.whiteTeam'.tr()))));
    final opponentRating = opponent?.rating ?? 1200;

    final isDraw = match.isDraw || match.isDrawOutcome;
    final bool isWinner = match.isUserWinner(currentUserId);
    final bool isLoser = match.isUserLoser(currentUserId);

    final Color outcomeColor;
    if (isCoop) {
      outcomeColor = isDraw ? AppColors.drawYellow : AppColors.accent;
    } else if (isWinner) {
      outcomeColor = AppColors.victory;
    } else if (isLoser) {
      outcomeColor = AppColors.lossRed;
    } else if (isDraw) {
      outcomeColor = AppColors.drawYellow;
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

          // Player / AI / Coop PP (vertically centered next to text block)
          if (isCoop)
            _buildLocalCoopAvatar(isDark)
          else if (isVsAi)
            _buildAiAvatar(isDark)
          else
            _buildPlayerAvatar(
              opponent,
              isDark,
              isDeleted: isOpponentDeleted,
              isGuest: isOpponentGuest,
            ),
          const SizedBox(width: 10),

          // Match Details (Top: Name / AI Difficulty, Bottom: Moves & Date)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    if (isCoop) ...[
                      Flexible(
                        child: Text(
                          'game.localCoopTitle'.tr(),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (match.isDraw) ...[
                        const SizedBox(width: 6),
                        Tooltip(
                          message: 'online.resultDraw'.tr(),
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: outcomeColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: outcomeColor.withValues(alpha: 0.6),
                                width: 1,
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.handshake_outlined,
                                size: 11,
                                color: outcomeColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ] else if (isVsAi) ...[
                      Flexible(
                        child: Text(
                          _getAiDifficultyLabel(opponent),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
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
                            color: isOpponentDeleted
                                ? AppColors.getDeletedUser(isDark)
                                : (isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.lightTextPrimary),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!isOpponentGuest) ...[
                        const SizedBox(width: 4),
                        Text(
                          '($opponentRating)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isOpponentDeleted
                                ? AppColors.getDeletedUser(isDark)
                                : AppColors.ratingGold,
                          ),
                        ),
                      ],
                    ],
                    if ((match.isTimeout ||
                            match.isResigned ||
                            match.isDrawAgreement) &&
                        !(isCoop && match.isDraw)) ...[
                      const SizedBox(width: 6),
                      _buildEndReasonBadge(match, isDark),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${match.totalMoves} ${'game.moveCount'.tr(args: ['']).trim()} • $dateStr',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.darkTextMuted
                        : AppColors.lightTextMuted,
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
