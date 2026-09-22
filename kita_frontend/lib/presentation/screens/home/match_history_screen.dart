import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/match_model.dart';
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
  List<MatchRecordModel> _matches = [];

  @override
  void initState() {
    super.initState();
    _fetchMatches();
  }

  Future<void> _fetchMatches() async {
    final authProv = context.read<AuthProvider>();
    final user = authProv.currentUser;

    if (authProv.isGuest || user == null) {
      if (mounted) {
        setState(() {
          _matches = [];
          _isLoading = false;
        });
      }
      return;
    }

    try {
      context.read<AuthProvider>().refreshProfile();
      final list = await _matchApiService
          .getUserMatches(user.id)
          .timeout(const Duration(seconds: 6));
      if (!mounted) return;
      setState(() {
        _matches = list;
        _errorMessage = null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _openReplay(MatchRecordModel match) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MatchReplayScreen(matchId: match.id),
      ),
    );
  }

  void _openDemoReplay() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MatchReplayScreen(match: MatchRecordModel.sampleDemoMatch()),
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
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Featured Demo Match Banner
                      _buildDemoBanner(isDark),
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
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          if (_matches.isNotEmpty)
                            Text(
                              '${_matches.length}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Error state / Guest Notice or Empty State or List
                      if (_errorMessage != null) ...[
                        KitaCard(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              const Icon(Icons.error_outline_rounded, size: 40, color: Colors.redAccent),
                              const SizedBox(height: 8),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
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
                      ] else if (isGuest) ...[
                        _buildGuestNotice(isDark),
                      ] else if (_matches.isEmpty) ...[
                        _buildEmptyState(isDark),
                      ] else ...[
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _matches.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final match = _matches[index];
                            return _buildMatchCard(context, match, authProv.currentUser?.id ?? '', isDark);
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

  Widget _buildDemoBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryGreen.withValues(alpha: isDark ? 0.35 : 0.2),
            const Color(0xFF2C3E50).withValues(alpha: isDark ? 0.4 : 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primaryGreen.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryGreen,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryGreen.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.movie_filter_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'history.demoReplayTitle'.tr(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'history.demoReplayDesc'.tr(),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          KitaButton(
            text: 'history.watchDemo'.tr(),
            height: 38,
            width: 120,
            fontSize: 13,
            icon: Icons.play_arrow_rounded,
            onPressed: _openDemoReplay,
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
          const Icon(Icons.account_circle_outlined, size: 42, color: AppColors.guestOrange),
          const SizedBox(height: 10),
          Text(
            'history.guestTitle'.tr(),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'history.guestDesc'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
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
          Icon(Icons.history_toggle_off_rounded, size: 48, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
          const SizedBox(height: 12),
          Text(
            'history.emptyTitle'.tr(),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'history.emptyDesc'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchCard(BuildContext context, MatchRecordModel match, String myUserId, bool isDark) {
    final isWhite = match.whitePlayerId == myUserId;
    final opponent = isWhite ? match.blackPlayer : match.whitePlayer;
    final opponentName = opponent?.username ?? (isWhite ? 'Black' : 'White');
    final opponentRating = opponent?.rating ?? 1200;

    final isWinner = match.winnerId != null && match.winnerId == myUserId;
    final isLoser = match.winnerId != null && match.winnerId != myUserId && match.result != 'draw';
    final isDraw = match.result == 'draw';

    Color resultColor;
    String resultText;
    if (isWinner) {
      resultColor = AppColors.primaryGreen;
      resultText = 'history.victory'.tr();
    } else if (isLoser) {
      resultColor = Colors.redAccent;
      resultText = 'history.defeat'.tr();
    } else if (isDraw) {
      resultColor = Colors.grey;
      resultText = 'history.draw'.tr();
    } else {
      resultColor = Colors.orangeAccent;
      resultText = match.result.toUpperCase();
    }

    final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(match.startedAt);

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
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '•  ${'replay.movesCount'.tr(args: ['${match.totalMoves}'])}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Right: Replay Action Icon
          Icon(
            Icons.play_circle_outline_rounded,
            color: AppColors.primaryGreen,
            size: 28,
          ),
        ],
      ),
    );
  }
}
