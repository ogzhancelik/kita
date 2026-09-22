import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/user_api_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/kita_app_bar.dart';
import '../../widgets/common/kita_button.dart';
import '../../widgets/common/kita_card.dart';
import '../../widgets/common/responsive_layout.dart';
import '../friends/friends_screen.dart';

enum _UserRowPosition {
  none,
  above,
  visible,
  below,
}

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final UserApiService _apiService = UserApiService();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _viewportKey = GlobalKey();
  final GlobalKey _userRowKey = GlobalKey();
  final GlobalKey _podiumKey = GlobalKey();

  List<UserProfile> _players = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedFilter = 'global'; // 'global' or 'friends'
  _UserRowPosition _userRowPosition = _UserRowPosition.none;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadLeaderboard();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    _checkUserPosition();
  }

  void _onFilterChanged(String filter) {
    if (_selectedFilter == filter) return;
    setState(() {
      _selectedFilter = filter;
      _isLoading = true;
      _errorMessage = null;
      _userRowPosition = _UserRowPosition.none;
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        try {
          _scrollController.jumpTo(0);
        } catch (_) {}
      }
    });

    _loadLeaderboard(filter: filter);
  }

  Future<void> _loadLeaderboard({String? filter}) async {
    final activeFilter = filter ?? _selectedFilter;
    if (!_isLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final authProv = context.read<AuthProvider>();
      if (activeFilter == 'friends' && (!authProv.isAuthenticated || authProv.isGuest)) {
        if (mounted) {
          setState(() {
            _players = [];
            _isLoading = false;
            _userRowPosition = _UserRowPosition.none;
          });
        }
        return;
      }

      final activeToken = authProv.token ?? ApiClient.currentToken;
      final list = await _apiService.getLeaderboard(
        limit: 50,
        filter: activeFilter,
        token: activeToken,
      );
      if (mounted) {
        setState(() {
          _players = list;
          _isLoading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _checkUserPosition();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
          _userRowPosition = _UserRowPosition.none;
        });
      }
    }
  }

  void _checkUserPosition() {
    if (!mounted || _isLoading || _players.isEmpty) {
      _setUserRowPosition(_UserRowPosition.none);
      return;
    }

    final authProv = context.read<AuthProvider>();
    final currentUserId = authProv.currentUser?.id;
    if (currentUserId == null) {
      _setUserRowPosition(_UserRowPosition.none);
      return;
    }

    final userIndex = _players.indexWhere((p) => p.id == currentUserId);
    final isTop3 = userIndex >= 0 && userIndex < 3;

    final BuildContext? targetContext = isTop3 ? _podiumKey.currentContext : _userRowKey.currentContext;
    final BuildContext? viewportContext = _viewportKey.currentContext;

    if (targetContext == null || viewportContext == null) return;

    try {
      final targetBox = targetContext.findRenderObject() as RenderBox?;
      final viewportBox = viewportContext.findRenderObject() as RenderBox?;

      if (targetBox == null || !targetBox.hasSize || !targetBox.attached ||
          viewportBox == null || !viewportBox.hasSize || !viewportBox.attached) {
        return;
      }

      final targetTop = targetBox.localToGlobal(Offset.zero, ancestor: viewportBox).dy;
      final targetBottom = targetTop + targetBox.size.height;
      final viewportHeight = viewportBox.size.height;

      // Threshold accounts for floating bar padding and height (~58px)
      const floatingThreshold = 58.0;

      _UserRowPosition newPosition;
      if (targetBottom <= floatingThreshold) {
        newPosition = _UserRowPosition.above;
      } else if (targetTop >= viewportHeight - floatingThreshold) {
        newPosition = _UserRowPosition.below;
      } else {
        newPosition = _UserRowPosition.visible;
      }

      _setUserRowPosition(newPosition);
    } catch (_) {
      // Ignore layout calculation errors during rapid transitions or detachment
    }
  }

  void _setUserRowPosition(_UserRowPosition newPosition) {
    if (newPosition == _userRowPosition) return;
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && newPosition != _userRowPosition) {
          setState(() {
            _userRowPosition = newPosition;
          });
        }
      });
    } else {
      setState(() {
        _userRowPosition = newPosition;
      });
    }
  }

  void _scrollToUser() {
    final authProv = context.read<AuthProvider>();
    final currentUserId = authProv.currentUser?.id;
    if (currentUserId == null) return;

    final userIndex = _players.indexWhere((p) => p.id == currentUserId);
    final isTop3 = userIndex >= 0 && userIndex < 3;

    if (isTop3 && _podiumKey.currentContext != null) {
      Scrollable.ensureVisible(
        _podiumKey.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
        alignment: 0.0,
      );
    } else if (_userRowKey.currentContext != null) {
      Scrollable.ensureVisible(
        _userRowKey.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
        alignment: 0.45,
      );
    } else if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProv = context.watch<AuthProvider>();
    final currentUserId = authProv.currentUser?.id;

    UserProfile? floatingProfile;
    String floatingRank = '';
    if (currentUserId != null) {
      final userIndex = _players.indexWhere((p) => p.id == currentUserId);
      if (userIndex >= 0) {
        floatingProfile = _players[userIndex];
        floatingRank = '#${userIndex + 1}';
      } else if (authProv.currentUser != null) {
        floatingProfile = authProv.currentUser;
        floatingRank = 'leaderboard.unrankedRank'.tr();
      }
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: KitaAppBar(
        title: 'leaderboard.title'.tr(),
        showBack: true,
        showAuthActions: false,
      ),
      body: ResponsiveLayout(
        maxWidth: 640,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: _buildFilterSelector(isDark),
            ),
            Expanded(
              child: Stack(
                key: _viewportKey,
                children: [
                  NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      _checkUserPosition();
                      return false;
                    },
                    child: RefreshIndicator(
                      onRefresh: _loadLeaderboard,
                      color: AppColors.primaryGreen,
                      child: _buildBody(isDark, currentUserId, authProv),
                    ),
                  ),

                  // Floating user row on TOP (slides down when user row is scrolled above)
                  if (floatingProfile != null)
                    Positioned(
                      top: 8,
                      left: 12,
                      right: 12,
                      child: AnimatedSlide(
                        offset: _userRowPosition == _UserRowPosition.above
                            ? Offset.zero
                            : const Offset(0, -1.2),
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        child: AnimatedOpacity(
                          opacity: _userRowPosition == _UserRowPosition.above ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 220),
                          child: IgnorePointer(
                            ignoring: _userRowPosition != _UserRowPosition.above,
                            child: _buildFloatingBar(
                              isDark: isDark,
                              isTop: true,
                              userProfile: floatingProfile,
                              rankDisplay: floatingRank,
                              onTap: _scrollToUser,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Floating user row on BOTTOM (slides up when user row is scrolled below)
                  if (floatingProfile != null)
                    Positioned(
                      bottom: 12,
                      left: 12,
                      right: 12,
                      child: AnimatedSlide(
                        offset: _userRowPosition == _UserRowPosition.below
                            ? Offset.zero
                            : const Offset(0, 1.2),
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        child: AnimatedOpacity(
                          opacity: _userRowPosition == _UserRowPosition.below ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 220),
                          child: IgnorePointer(
                            ignoring: _userRowPosition != _UserRowPosition.below,
                            child: _buildFloatingBar(
                              isDark: isDark,
                              isTop: false,
                              userProfile: floatingProfile,
                              rankDisplay: floatingRank,
                              onTap: _scrollToUser,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSelector(bool isDark) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildFilterTab(
              label: 'leaderboard.filterGlobal'.tr(),
              icon: Icons.public_rounded,
              isSelected: _selectedFilter == 'global',
              onTap: () => _onFilterChanged('global'),
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildFilterTab(
              label: 'leaderboard.filterFriends'.tr(),
              icon: Icons.people_alt_rounded,
              isSelected: _selectedFilter == 'friends',
              onTap: () => _onFilterChanged('friends'),
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primaryGreen.withValues(alpha: 0.35),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? AppColors.darkTextPrimary
                  : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected
                      ? AppColors.darkTextPrimary
                      : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(bool isDark, String? currentUserId, AuthProvider authProv) {
    if (_isLoading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          const Center(
            child: CircularProgressIndicator(
              color: AppColors.primaryGreen,
            ),
          ),
        ],
      );
    }

    if (_errorMessage != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
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
        ],
      );
    }

    // Guest handling for Friends tab
    if (_selectedFilter == 'friends' && (!authProv.isAuthenticated || authProv.isGuest)) {
      return _buildFriendsGuestPrompt(context, isDark);
    }

    final hasNoFriends = _selectedFilter == 'friends' &&
        (_players.isEmpty || (_players.length == 1 && _players[0].id == currentUserId));

    if (hasNoFriends) {
      return _buildNoFriendsState(context, isDark);
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
    final userIndex = currentUserId != null ? _players.indexWhere((p) => p.id == currentUserId) : -1;
    final isUserInTop3 = userIndex >= 0 && userIndex < 3;
    final isUserUnranked = currentUserId != null && userIndex == -1;

    return SingleChildScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Top 3 Podium
          if (top3.isNotEmpty) ...[
            KeyedSubtree(
              key: isUserInTop3 ? _podiumKey : null,
              child: _buildPodium(top3, isDark, currentUserId),
            ),
            const SizedBox(height: 16),
          ],

          // 2. Table Header & Player Cards (Players 4+ only, top-3 excluded)
          if (remaining.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
              child: Row(
                children: [
                  SizedBox(
                    width: 38,
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

            // 3. Player Cards (Only remaining players 4+)
            ...remaining.asMap().entries.map((entry) {
              final rank = 3 + entry.key + 1;
              final player = entry.value;
              final isCurrentUser = player.id == currentUserId;

              return Padding(
                key: isCurrentUser ? _userRowKey : null,
                padding: const EdgeInsets.only(bottom: 8.0),
                child: _buildPlayerRow(
                  rank: rank,
                  player: player,
                  isDark: isDark,
                  isCurrentUser: isCurrentUser,
                ),
              );
            }),
          ],

          // 4. Current user is authenticated but ranked > 50
          if (isUserUnranked && authProv.currentUser != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      thickness: 1,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Text(
                      '···',
                      style: TextStyle(
                        fontSize: 16,
                        letterSpacing: 4,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      thickness: 1,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              key: _userRowKey,
              padding: const EdgeInsets.only(bottom: 8.0),
              child: _buildPlayerRow(
                rank: 51,
                rankLabel: 'leaderboard.unrankedRank'.tr(),
                player: authProv.currentUser!,
                isDark: isDark,
                isCurrentUser: true,
              ),
            ),
          ],

          if (_selectedFilter == 'friends') ...[
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: _buildAddMoreFriendsCard(context, isDark),
            ),
          ],

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildFriendsGuestPrompt(BuildContext context, bool isDark) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      children: [
        const SizedBox(height: 24),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.people_alt_rounded,
                  size: 42,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'leaderboard.friendsLoginPrompt'.tr(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'leaderboard.friendsLoginDesc'.tr(),
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              KitaButton(
                text: 'leaderboard.loginRequired'.tr(),
                icon: Icons.login_rounded,
                variant: KitaButtonVariant.primary,
                height: 44,
                onPressed: () {
                  context.read<AuthProvider>().guardAction(context, () {});
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNoFriendsState(BuildContext context, bool isDark) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      children: [
        const SizedBox(height: 24),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.accentGold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.group_add_rounded,
                  size: 42,
                  color: AppColors.accentGold,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'leaderboard.noFriendsTitle'.tr(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'leaderboard.noFriendsDesc'.tr(),
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 200,
                child: KitaButton(
                  text: 'leaderboard.findFriends'.tr(),
                  icon: Icons.person_search_rounded,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const FriendsScreen()),
                    ).then((_) => _loadLeaderboard());
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAddMoreFriendsCard(BuildContext context, bool isDark) {
    return KitaCard(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.group_add_rounded,
              color: AppColors.primaryGreen,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'leaderboard.addMoreFriendsHint'.tr(),
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 140,
            child: KitaButton(
              text: 'leaderboard.findFriends'.tr(),
              icon: Icons.person_add_rounded,
              variant: KitaButtonVariant.outline,
              height: 34,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FriendsScreen()),
                ).then((_) => _loadLeaderboard());
              },
            ),
          ),
        ],
      ),
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
                    medalColor: AppColors.silverMedal, // Silver
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
                    medalColor: AppColors.bronzeMedal, // Bronze
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
    String? rankLabel,
    required UserProfile player,
    required bool isDark,
    required bool isCurrentUser,
  }) {
    Color rankColor = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    if (rank == 1) rankColor = AppColors.ratingGold;
    if (rank == 2) rankColor = AppColors.silverMedal;
    if (rank == 3) rankColor = AppColors.bronzeMedal;
    if (isCurrentUser) rankColor = AppColors.primaryGreen;

    final displayRank = rankLabel ?? '#$rank';

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
            width: 38,
            child: Text(
              displayRank,
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

  // --- Floating User Row (Pinned Top or Bottom) ---
  Widget _buildFloatingBar({
    required bool isDark,
    required bool isTop,
    required UserProfile userProfile,
    required String rankDisplay,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.primaryGreen,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryGreen.withValues(alpha: isDark ? 0.35 : 0.2),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Directional Arrow Badge
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isTop ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  color: AppColors.darkTextPrimary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 8),

              // Rank Number
              SizedBox(
                width: 38,
                child: Text(
                  rankDisplay,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
              const SizedBox(width: 4),

              // Avatar
              CircleAvatar(
                radius: 15,
                backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                child: Text(
                  userProfile.username.isNotEmpty ? userProfile.username[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Username + (YOU) + Subtitle hint
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            userProfile.username,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        ),
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
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'leaderboard.jumpToYourRank'.tr(),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Rating Badge & Win Rate
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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
                        const Icon(Icons.star_rounded, size: 12, color: AppColors.ratingGold),
                        const SizedBox(width: 2),
                        Text(
                          '${userProfile.rating}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: AppColors.ratingGold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '%${userProfile.winRate.toStringAsFixed(1)} ${'leaderboard.winRate'.tr()}',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: userProfile.winRate >= 50
                          ? AppColors.primaryGreen
                          : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
