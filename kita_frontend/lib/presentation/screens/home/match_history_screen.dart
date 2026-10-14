import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/match_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/local_match_history_service.dart';
import '../../../data/services/match_api_service.dart';
import '../../../data/services/replay_file_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/kita_avatar.dart';
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

  static const int _pageSize = 20;

  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  String? _loadMoreError;
  bool _showOfflineMatches = true;

  final ScrollController _scrollController = ScrollController();

  List<MatchRecordModel> _onlineMatches = [];
  List<MatchRecordModel> _offlineMatches = [];
  List<MatchRecordModel> _visibleMatches = [];

  int _onlineOffset = 0;
  bool _hasMoreOnline = true;
  int _displayLimit = _pageSize;
  bool _hasMore = false;
  int _totalOnlineMatches = 0;

  int get _totalMatchCount {
    final authProv = context.read<AuthProvider>();
    final isGuest = authProv.isGuest || authProv.currentUser == null;
    final onlineCount = isGuest
        ? 0
        : (_totalOnlineMatches > _onlineMatches.length
              ? _totalOnlineMatches
              : _onlineMatches.length);
    final offlineCount = _showOfflineMatches ? _offlineMatches.length : 0;
    return onlineCount + offlineCount;
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    LocalMatchHistoryService.instance.matchHistoryRevision.addListener(
      _onRevisionChanged,
    );
    _fetchMatches();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    LocalMatchHistoryService.instance.matchHistoryRevision.removeListener(
      _onRevisionChanged,
    );
    super.dispose();
  }

  void _onRevisionChanged() {
    if (mounted) {
      _fetchMatches();
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (maxScroll - currentScroll <= 300) {
      if (_hasMore && !_isLoading && !_isLoadingMore) {
        _loadMoreMatches();
      }
    }
  }

  Future<void> _fetchMatches() async {
    final authProv = context.read<AuthProvider>();
    final user = authProv.currentUser;
    final isGuest = authProv.isGuest || user == null;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _loadMoreError = null;
      _onlineOffset = 0;
      _hasMoreOnline = true;
      _displayLimit = _pageSize;
    });

    try {
      // 1. Fetch saved toggle preference
      _showOfflineMatches = await LocalMatchHistoryService.instance
          .getShowOfflineMatches(userId: user?.id, isGuest: isGuest);

      // 2. Fetch offline matches from local device storage
      _offlineMatches = await LocalMatchHistoryService.instance.getMatches(
        userId: user?.id,
        isGuest: isGuest,
      );

      // 3. Fetch online matches from backend API if not guest
      if (!mounted) return;
      if (!isGuest) {
        try {
          context.read<AuthProvider>().refreshProfile();
          final result = await _matchApiService
              .getUserMatchesWithTotal(user.id, limit: _pageSize, offset: 0)
              .timeout(const Duration(seconds: 6));
          _onlineMatches = result.matches;
          _onlineOffset = result.matches.length;
          _hasMoreOnline = result.matches.length == _pageSize;
          _totalOnlineMatches = result.totalCount > 0
              ? result.totalCount
              : (user.totalGames > 0 ? user.totalGames : result.matches.length);
        } catch (e) {
          if (_offlineMatches.isEmpty) {
            _errorMessage = e.toString();
          }
          _totalOnlineMatches = user.totalGames > 0 ? user.totalGames : 0;
        }
      } else {
        _onlineMatches = [];
        _hasMoreOnline = false;
        _onlineOffset = 0;
        _totalOnlineMatches = 0;
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

  Future<void> _loadMoreMatches() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;

    final authProv = context.read<AuthProvider>();
    final user = authProv.currentUser;
    final isGuest = authProv.isGuest || user == null;

    setState(() {
      _isLoadingMore = true;
      _loadMoreError = null;
    });

    try {
      if (!isGuest && _hasMoreOnline) {
        final result = await _matchApiService
            .getUserMatchesWithTotal(
              user.id,
              limit: _pageSize,
              offset: _onlineOffset,
            )
            .timeout(const Duration(seconds: 6));

        if (result.matches.isNotEmpty) {
          _onlineMatches.addAll(result.matches);
          _onlineOffset += result.matches.length;
        }
        if (result.totalCount > 0) {
          _totalOnlineMatches = result.totalCount;
        }
        if (result.matches.length < _pageSize) {
          _hasMoreOnline = false;
        }
      }

      _displayLimit += _pageSize;

      if (mounted) {
        setState(() {
          _recomputeVisibleMatches();
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      debugPrint('[MatchHistoryScreen] Error loading more matches: $e');
      if (mounted) {
        setState(() {
          _displayLimit += _pageSize;
          _recomputeVisibleMatches();
          _isLoadingMore = false;
          _loadMoreError = 'history.loadMoreError'.tr();
        });
      }
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

    // Deduplicate in case matches exist both online and locally
    final seenIds = <String>{};
    final deduplicated = <MatchRecordModel>[];
    for (final m in combined) {
      if (seenIds.add(m.id)) {
        deduplicated.add(m);
      }
    }

    _visibleMatches = deduplicated.take(_displayLimit).toList();
    _hasMore = _hasMoreOnline || deduplicated.length > _visibleMatches.length;
  }

  Future<void> _toggleOfflineFilter(bool value) async {
    setState(() {
      _showOfflineMatches = value;
      _recomputeVisibleMatches();
    });
    final authProv = context.read<AuthProvider>();
    final user = authProv.currentUser;
    final isGuest = authProv.isGuest || user == null;
    await LocalMatchHistoryService.instance.setShowOfflineMatches(
      value,
      userId: user?.id,
      isGuest: isGuest,
    );
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

  Future<void> _loadReplayFromFile() async {
    try {
      final loadedMatch = await ReplayFileService.instance.pickAndLoadReplay(
        dialogTitle: 'replay.pickDialogTitle'.tr(),
      );

      if (loadedMatch == null) return;
      if (!mounted) return;

      final authProv = context.read<AuthProvider>();
      final user = authProv.currentUser;
      final isGuest = authProv.isGuest || user == null;
      await LocalMatchHistoryService.instance.saveMatch(
        loadedMatch,
        userId: user?.id,
        isGuest: isGuest,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.primaryAmber,
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'replay.loadSuccess'.tr(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MatchReplayScreen(match: loadedMatch),
        ),
      );

      if (mounted) {
        _fetchMatches();
      }
    } on FormatException catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.lossRed,
          content: Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'replay.invalidFile'.tr(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.lossRed,
          content: Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'replay.invalidFile'.tr(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  String _extractReplayCode(String input) {
    var trimmed = input.trim();
    if (trimmed.isEmpty) return '';

    final uri = Uri.tryParse(trimmed);
    if (uri != null) {
      if (uri.pathSegments.contains('replay')) {
        final idx = uri.pathSegments.indexOf('replay');
        if (idx + 1 < uri.pathSegments.length) {
          return uri.pathSegments[idx + 1].trim();
        }
      }
    }

    if (trimmed.contains('/')) {
      trimmed = trimmed.split('/').last.trim();
    }
    return trimmed;
  }

  void _showLoadReplayDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textController = TextEditingController();
    String? localError;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setModalState) {
          Future<void> submitCode() async {
            final rawText = textController.text.trim();
            final code = _extractReplayCode(rawText);

            if (code.isEmpty) {
              setModalState(() {
                localError = 'replay.enterCodeError'.tr();
              });
              return;
            }

            setModalState(() {
              isLoading = true;
              localError = null;
            });

            try {
              final authProv = this.context.read<AuthProvider>();
              final user = authProv.currentUser;
              final isGuest = authProv.isGuest || user == null;

              // 1. Check local match storage first
              final localMatches = await LocalMatchHistoryService.instance
                  .getMatches(userId: user?.id, isGuest: isGuest);
              final matchingLocal = localMatches
                  .where(
                    (m) =>
                        m.id.toLowerCase() == code.toLowerCase() ||
                        (m.id.contains('-') &&
                            m.id.split('-').first.toLowerCase() ==
                                code.toLowerCase()),
                  )
                  .firstOrNull;

              if (matchingLocal != null) {
                if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                if (mounted) {
                  await Navigator.of(this.context).push(
                    MaterialPageRoute(
                      builder: (_) => MatchReplayScreen(match: matchingLocal),
                    ),
                  );
                  if (mounted) _fetchMatches();
                }
                return;
              }

              // 2. Fetch from backend
              final loaded = await _matchApiService.getMatchDetails(code);
              await LocalMatchHistoryService.instance.saveMatch(
                loaded,
                userId: user?.id,
                isGuest: isGuest,
              );

              if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
              if (mounted) {
                await Navigator.of(this.context).push(
                  MaterialPageRoute(
                    builder: (_) => MatchReplayScreen(match: loaded),
                  ),
                );
                if (mounted) _fetchMatches();
              }
            } catch (_) {
              if (dialogCtx.mounted) {
                setModalState(() {
                  isLoading = false;
                  localError = 'replay.replayNotFound'.tr();
                });
              }
            }
          }

          return AlertDialog(
            backgroundColor: AppColors.getCard(isDark),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                const Icon(
                  Icons.smart_display_rounded,
                  color: AppColors.primaryAmber,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  'replay.loadReplayTitle'.tr(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getTextPrimary(isDark),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: textController,
                    autofocus: true,
                    style: TextStyle(
                      color: AppColors.getTextPrimary(isDark),
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'replay.enterCodeOrLink'.tr(),
                      hintStyle: TextStyle(
                        color: AppColors.getTextMuted(isDark),
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(
                        Icons.tag_rounded,
                        color: AppColors.primaryAmber,
                        size: 20,
                      ),
                      suffixIcon: textController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              color: AppColors.getTextMuted(isDark),
                              onPressed: () {
                                textController.clear();
                                setModalState(() {});
                              },
                            )
                          : IconButton(
                              icon: const Icon(
                                Icons.content_paste_rounded,
                                size: 18,
                              ),
                              color: AppColors.getTextMuted(isDark),
                              tooltip: 'Paste',
                              onPressed: () async {
                                final data = await Clipboard.getData(
                                  'text/plain',
                                );
                                if (data?.text != null) {
                                  textController.text = data!.text!;
                                  setModalState(() {});
                                }
                              },
                            ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      filled: true,
                      fillColor: AppColors.getSurface(isDark),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: AppColors.getBorder(isDark),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: AppColors.getBorder(isDark),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: AppColors.primaryAmber,
                          width: 1.5,
                        ),
                      ),
                    ),
                    onChanged: (_) {
                      if (localError != null) {
                        setModalState(() => localError = null);
                      } else {
                        setModalState(() {});
                      }
                    },
                    onSubmitted: (_) => submitCode(),
                  ),
                  if (localError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      localError!,
                      style: const TextStyle(
                        color: AppColors.lossRed,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryAmber,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      onPressed: isLoading ? null : submitCode,
                      child: isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'replay.watchMatch'.tr(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.of(dialogCtx).pop();
                        _loadReplayFromFile();
                      },
                      icon: const Icon(Icons.file_open_rounded, size: 16),
                      label: Text(
                        'replay.uploadFile'.tr(),
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.getTextSecondary(isDark),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(
                  'common.cancel'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          );
        },
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
        showLanguageToggle: false,
        showThemeToggle: false,
        title: 'history.title'.tr(),
        extraActions: [
          IconButton(
            tooltip: 'replay.loadReplay'.tr(),
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.file_open_rounded,
              color: AppColors.primaryAmber,
              size: 20,
            ),
            onPressed: _showLoadReplayDialog,
          ),
        ],
      ),
      body: ResponsiveLayout(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _fetchMatches,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10.0,
                    vertical: 12.0,
                  ),
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
                          if (_totalMatchCount > 0)
                            Text(
                              '$_totalMatchCount',
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
                              const Icon(
                                Icons.error_outline_rounded,
                                size: 40,
                                color: Colors.redAccent,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              KitaButton(
                                text: 'common.retry'.tr(),
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
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _visibleMatches.length,
                          itemBuilder: (context, index) {
                            final match = _visibleMatches[index];
                            final prevMatch = index > 0
                                ? _visibleMatches[index - 1]
                                : null;
                            final showDateDivider =
                                prevMatch == null ||
                                !_isSameDay(
                                  prevMatch.startedAt,
                                  match.startedAt,
                                );

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (showDateDivider)
                                  _buildDateDivider(
                                    match.startedAt,
                                    isDark,
                                    isFirst: index == 0,
                                  ),
                                _buildMatchCard(
                                  context,
                                  match,
                                  authProv.currentUser?.id ?? '',
                                  isDark,
                                ),
                                const SizedBox(height: 10),
                              ],
                            );
                          },
                        ),
                        if (_isLoadingMore) ...[
                          const SizedBox(height: 12),
                          const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ] else if (_loadMoreError != null) ...[
                          const SizedBox(height: 12),
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _loadMoreError!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? AppColors.darkTextMuted
                                        : AppColors.lightTextMuted,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                KitaButton(
                                  text: 'common.retry'.tr(),
                                  height: 32,
                                  fontSize: 12,
                                  onPressed: _loadMoreMatches,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
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
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: _showOfflineMatches
                        ? AppColors.primaryAmber.withValues(alpha: 0.15)
                        : (isDark
                              ? AppColors.darkSurfaceElevated
                              : AppColors.lightSurface),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.smart_toy_rounded,
                    size: 18,
                    color: _showOfflineMatches
                        ? AppColors.primaryAmber
                        : (isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _showOfflineMatches,
            activeThumbColor: AppColors.primaryAmber,
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
          const Icon(
            Icons.account_circle_outlined,
            size: 42,
            color: AppColors.guestOrange,
          ),
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
          Icon(
            Icons.history_toggle_off_rounded,
            size: 48,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
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

  bool _isSameDay(DateTime a, DateTime b) {
    final localA = a.toLocal();
    final localB = b.toLocal();
    return localA.year == localB.year &&
        localA.month == localB.month &&
        localA.day == localB.day;
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(local.year, local.month, local.day);
    if (_isSameDay(today, target)) {
      return 'history.today'.tr();
    }
    final yesterday = today.subtract(const Duration(days: 1));
    if (_isSameDay(yesterday, target)) {
      return 'history.yesterday'.tr();
    }
    return DateFormat('d MMM y').format(local);
  }

  Widget _buildDateDivider(DateTime date, bool isDark, {bool isFirst = false}) {
    return Padding(
      padding: EdgeInsets.only(top: isFirst ? 4 : 10, bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Divider(color: AppColors.getBorder(isDark), height: 1),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _formatDate(date),
              style: TextStyle(
                fontSize: 11,
                color: AppColors.getTextMuted(isDark),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Divider(color: AppColors.getBorder(isDark), height: 1),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchCard(
    BuildContext context,
    MatchRecordModel match,
    String myUserId,
    bool isDark,
  ) {
    final bool isOffline = match.isOffline || match.id.startsWith('offline');
    final bool isCoop = match.isLocalCoop;
    final bool isWhite = match.isUserWhite(myUserId);

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
                                ? 'common.black'.tr()
                                : 'common.white'.tr()))));
    final opponentRating = opponent?.rating ?? 1200;

    final isDraw = match.isDraw || match.isDrawOutcome;
    final bool isWinner = match.isUserWinner(myUserId);
    final bool isLoser = match.isUserLoser(myUserId);

    Color resultColor;
    if (isCoop) {
      resultColor = isDraw ? AppColors.drawYellow : AppColors.accent;
    } else if (isWinner) {
      resultColor = AppColors.victory;
    } else if (isLoser) {
      resultColor = AppColors.lossRed;
    } else if (isDraw) {
      resultColor = AppColors.drawYellow;
    } else {
      resultColor = AppColors.accentGold;
    }

    return KitaCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () => _openReplay(match),
      child: Row(
        children: [
          // Left: Result Indicator Pillar
          Container(
            width: 4,
            height: 44,
            decoration: BoxDecoration(
              color: resultColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),

          // B/W or 2P Team Badge
          if (isCoop)
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.accent, width: 1.2),
              ),
              child: const Center(
                child: Text(
                  '2P',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: AppColors.accent,
                  ),
                ),
              ),
            )
          else
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isWhite ? Colors.white : Colors.black,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey, width: 1.2),
              ),
              child: Center(
                child: Text(
                  isWhite ? 'W' : 'B',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: isWhite ? Colors.black : Colors.white,
                  ),
                ),
              ),
            ),
          const SizedBox(width: 10),

          // Player / AI / Coop PP
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

          // Match details
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
                      const SizedBox(width: 6),
                      if (match.isDraw)
                        Tooltip(
                          message: 'online.resultDraw'.tr(),
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: resultColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: resultColor.withValues(alpha: 0.6),
                                width: 1,
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.handshake_outlined,
                                size: 11,
                                color: resultColor,
                              ),
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: resultColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: resultColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            match.winnerId == match.whitePlayerId
                                ? 'game.whiteWins'.tr()
                                : 'game.blackWins'.tr(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: resultColor,
                            ),
                          ),
                        ),
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
                const SizedBox(height: 3),
                Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'replay.movesCount'.tr(args: ['${match.totalMoves}']),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                    ),
                    if (match.endedAt != null)
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
                ),
              ],
            ),
          ),

          // Right: Replay Action Icon
          const Icon(
            Icons.play_circle_outline_rounded,
            color: AppColors.primaryAmber,
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
