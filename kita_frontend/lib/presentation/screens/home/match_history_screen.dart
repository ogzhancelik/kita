import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/match_model.dart';
import '../../../data/services/local_match_history_service.dart';
import '../../../data/services/match_api_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/kita_app_bar.dart';
import '../../widgets/common/kita_button.dart';
import '../../widgets/common/kita_card.dart';
import '../../widgets/common/responsive_layout.dart';
import '../game/match_replay_screen.dart';

class MatchHistoryScreen extends StatefulWidget {
  const MatchHistoryScreen({super.key});

  @override
  State<MatchHistoryScreen> createState() => _MatchHistoryScreenState();
}

class _MatchHistoryScreenState extends State<MatchHistoryScreen> {
  final MatchApiService _matchApiService = MatchApiService();

  bool _isLoading = true;
  String? _errorMessage;
  bool _showOfflineMatches = true;

  List<MatchRecordModel> _onlineMatches = [];
  List<MatchRecordModel> _offlineMatches = [];
  List<MatchRecordModel> _visibleMatches = [];

  @override
  void initState() {
    super.initState();
    _fetchMatches();
  }

  Future<void> _fetchMatches() async {
    final authProv = context.read<AuthProvider>();
    final user = authProv.currentUser;
    final isGuest = authProv.isGuest || user == null;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Fetch saved toggle preference
      _showOfflineMatches =
          await LocalMatchHistoryService.instance.getShowOfflineMatches();

      // 2. Fetch offline matches from local device storage
      _offlineMatches = await LocalMatchHistoryService.instance.getMatches();

      // 3. Fetch online matches from backend API if not guest
      if (!isGuest && user != null) {
        try {
          context.read<AuthProvider>().refreshProfile();
          final list = await _matchApiService
              .getUserMatches(user.id)
              .timeout(const Duration(seconds: 6));
          _onlineMatches = list;
        } catch (e) {
          if (_offlineMatches.isEmpty) {
            _errorMessage = e.toString();
          }
        }
      } else {
        _onlineMatches = [];
      }

      _recomputeVisibleMatches();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _recomputeVisibleMatches() {
    final List<MatchRecordModel> combined = [];

    // Add online matches
    combined.addAll(_onlineMatches);

    // Add offline matches if toggle is enabled
    if (_showOfflineMatches) {
      combined.addAll(_offlineMatches);
    }

    // Sort chronologically (most recent first)
    combined.sort((a, b) => b.startedAt.compareTo(a.startedAt));

    _visibleMatches = combined;
  }

  Future<void> _toggleOfflineFilter(bool value) async {
    setState(() {
      _showOfflineMatches = value;
      _recomputeVisibleMatches();
    });
    await LocalMatchHistoryService.instance.setShowOfflineMatches(value);
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
    final isGuest = authProv.isGuest;

    return Scaffold(
      appBar: KitaAppBar(
        showAuthActions: false,
        showBack: true,
        title: 'history.title'.tr(),
      ),
      body: ResponsiveLayout(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _fetchMatches,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10.0, vertical: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Offline Games Toggle Filter Bar
                      _buildOfflineFilterToggle(isDark),
                      const SizedBox(height: 14),

                      // Section Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'history.recentMatches'.tr(),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                          if (_visibleMatches.isNotEmpty)
                            Text(
                              '${_visibleMatches.length}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? AppColors.darkTextMuted
                                    : AppColors.lightTextMuted,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Guest Ephemeral Notice (if guest has offline matches visible)
                      if (isGuest &&
                          _showOfflineMatches &&
                          _visibleMatches.isNotEmpty)
                        _buildGuestOfflineBanner(isDark),

                      // Error state / Guest Notice or Empty State or List
                      if (_errorMessage != null && _visibleMatches.isEmpty) ...[
                        KitaCard(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  size: 40, color: Colors.redAccent),
                              const SizedBox(height: 8),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 12),
                              KitaButton(
                                text: 'leaderboard.retry'.tr(),
                                height: 38,
                                fontSize: 13,
                                onPressed: _fetchMatches,
                              ),
                            ],
                          ),
                        ),
                      ] else if (isGuest && !_showOfflineMatches) ...[
                        _buildGuestNotice(isDark),
                      ] else if (_visibleMatches.isEmpty) ...[
                        _buildEmptyState(isDark),
                      ] else ...[
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _visibleMatches.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final match = _visibleMatches[index];
                            return _buildMatchCard(
                              context,
                              match,
                              authProv.currentUser?.id ?? '',
                              isDark,
                            );
                          },
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildOfflineFilterToggle(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBg : AppColors.lightBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _showOfflineMatches
                      ? AppColors.primaryGreen.withValues(alpha: 0.15)
                      : (isDark
                          ? AppColors.darkSurfaceElevated
                          : AppColors.lightSurface),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.smart_toy_rounded,
                  size: 18,
                  color: _showOfflineMatches
                      ? AppColors.primaryGreen
                      : (isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'history.showOfflineMatches'.tr(),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'game.aiBot'.tr(),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Switch.adaptive(
            value: _showOfflineMatches,
            activeColor: AppColors.primaryGreen,
            onChanged: _toggleOfflineFilter,
          ),
        ],
      ),
    );
  }

  Widget _buildGuestOfflineBanner(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.guestOrange.withValues(alpha: isDark ? 0.14 : 0.09),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.guestOrange.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 17,
            color: AppColors.guestOrange,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'history.guestOfflineNotice'.tr(),
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.guestOrange,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestNotice(bool isDark) {
    return KitaCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(Icons.account_circle_outlined,
              size: 42, color: AppColors.guestOrange),
          const SizedBox(height: 10),
          Text(
            'history.guestTitle'.tr(),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'history.guestDesc'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return KitaCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Icon(Icons.history_toggle_off_rounded,
              size: 48,
              color: isDark
                  ? AppColors.darkTextMuted
                  : AppColors.lightTextMuted),
          const SizedBox(height: 12),
          Text(
            'history.emptyTitle'.tr(),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'history.emptyDesc'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchCard(BuildContext context, MatchRecordModel match,
      String myUserId, bool isDark) {
    final bool isOffline = match.isOffline || match.id.startsWith('offline');

    // In offline games against the bot, the player is the non-bot side
    final bool isWhite;
    if (isOffline) {
      isWhite = match.blackPlayerId == 'bot';
    } else {
      isWhite = match.whitePlayerId == myUserId;
    }

    final opponent = isWhite ? match.blackPlayer : match.whitePlayer;
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
      isWinner = match.winnerId != null && match.winnerId == myUserId;
      isLoser =
          match.winnerId != null && match.winnerId != myUserId && !isDraw;
    }

    Color resultColor;
    String resultText;
    if (isWinner) {
      resultColor = AppColors.victory;
      resultText = 'history.victory'.tr();
    } else if (isLoser) {
      resultColor = AppColors.lossRed;
      resultText = 'history.defeat'.tr();
    } else if (isDraw) {
      resultColor = AppColors.drawGray;
      resultText = 'history.draw'.tr();
    } else {
      resultColor = AppColors.accentGold;
      resultText = match.result.toUpperCase();
    }

    final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(match.startedAt.toLocal());

    return KitaCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () => _openReplay(match),
      child: Row(
        children: [
          // Left: Result Indicator Pillar
          Container(
            width: 4,
            height: 48,
            decoration: BoxDecoration(
              color: resultColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),

          // Team Badge (White vs Black)
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isWhite ? Colors.white : Colors.black,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey, width: 1.5),
            ),
            child: Center(
              child: Text(
                isWhite ? 'W' : 'B',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: isWhite ? Colors.black : Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Match details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      resultText,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: resultColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'vs $opponentName ($opponentRating)',
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
                    if (isOffline) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen
                              .withValues(alpha: isDark ? 0.22 : 0.14),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: AppColors.primaryGreen
                                .withValues(alpha: 0.4),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          'history.vsAi'.tr(),
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '•  ${'replay.movesCount'.tr(args: ['${match.totalMoves}'])}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                    ),
                    if (match.endedAt != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '•  ${_formatDuration(match.endedAt!.difference(match.startedAt).inSeconds)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Right: Replay Action Icon
          const Icon(
            Icons.play_circle_outline_rounded,
            color: AppColors.primaryGreen,
            size: 28,
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    if (seconds < 0) seconds = 0;
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}
