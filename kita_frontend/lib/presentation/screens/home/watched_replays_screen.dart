import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/match_model.dart';
import '../../../data/services/match_api_service.dart';
import '../../../data/services/replay_file_service.dart';
import '../../../data/services/watched_replay_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/kita_app_bar.dart';
import '../../widgets/common/kita_card.dart';
import '../../widgets/common/responsive_layout.dart';
import '../game/match_replay_screen.dart';

/// Screen displaying all external match replays the user has watched/loaded
/// (e.g. via code, .kita file, DM chat cards, or links), separate from their own played matches.
class WatchedReplaysScreen extends StatefulWidget {
  const WatchedReplaysScreen({super.key});

  @override
  State<WatchedReplaysScreen> createState() => _WatchedReplaysScreenState();
}

class _WatchedReplaysScreenState extends State<WatchedReplaysScreen> {
  final MatchApiService _matchApiService = MatchApiService();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String _searchQuery = '';
  List<WatchedMatchEntry> _watchedEntries = [];

  @override
  void initState() {
    super.initState();
    WatchedReplayService.instance.watchedReplayRevision.addListener(_onRevisionChanged);
    _loadWatchedReplays();
  }

  @override
  void dispose() {
    _searchController.dispose();
    WatchedReplayService.instance.watchedReplayRevision.removeListener(_onRevisionChanged);
    super.dispose();
  }

  void _onRevisionChanged() {
    if (mounted) {
      _loadWatchedReplays();
    }
  }

  Future<void> _loadWatchedReplays() async {
    final authProv = context.read<AuthProvider>();
    final user = authProv.currentUser;
    final isGuest = authProv.isGuest || user == null;

    final list = await WatchedReplayService.instance.getWatchedEntries(
      userId: user?.id,
      isGuest: isGuest,
    );

    if (mounted) {
      setState(() {
        _watchedEntries = list;
        _isLoading = false;
      });
    }
  }

  List<WatchedMatchEntry> get _filteredEntries {
    if (_searchQuery.trim().isEmpty) return _watchedEntries;
    final q = _searchQuery.trim().toLowerCase();
    return _watchedEntries.where((entry) {
      final m = entry.match;
      final white = (m.whitePlayer?.username ?? m.whitePlayerId).toLowerCase();
      final black = (m.blackPlayer?.username ?? m.blackPlayerId).toLowerCase();
      final id = m.id.toLowerCase();
      return white.contains(q) || black.contains(q) || id.contains(q);
    }).toList();
  }

  void _openReplay(MatchRecordModel match) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MatchReplayScreen(
          match: match,
          isWatchedReplay: true,
        ),
      ),
    );
  }

  Future<void> _deleteReplay(String matchId) async {
    setState(() {
      _watchedEntries.removeWhere((e) => e.match.id == matchId);
    });

    final authProv = context.read<AuthProvider>();
    final user = authProv.currentUser;
    final isGuest = authProv.isGuest || user == null;

    await WatchedReplayService.instance.deleteWatchedReplay(
      matchId,
      userId: user?.id,
      isGuest: isGuest,
    );
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

              // Check if already in watched matches
              final matching = _watchedEntries.where((entry) {
                final m = entry.match;
                return m.id.toLowerCase() == code.toLowerCase() ||
                    (m.id.contains('-') && m.id.split('-').first.toLowerCase() == code.toLowerCase());
              }).firstOrNull?.match;

              if (matching != null) {
                if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                if (mounted) _openReplay(matching);
                return;
              }

              // Fetch from backend
              final loaded = await _matchApiService.getMatchDetails(code);
              await WatchedReplayService.instance.saveWatchedReplay(
                loaded,
                userId: user?.id,
                isGuest: isGuest,
              );

              if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
              if (mounted) _openReplay(loaded);
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppColors.getBorder(isDark)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
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
                        foregroundColor: AppColors.darkTextPrimary,
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
                                color: AppColors.darkTextPrimary,
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
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
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
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
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

  Future<void> _loadReplayFromFile() async {
    try {
      final loadedMatch = await ReplayFileService.instance.pickAndLoadReplay(
        dialogTitle: 'replay.pickDialogTitle'.tr(),
      );

      if (loadedMatch == null || !mounted) return;

      final authProv = context.read<AuthProvider>();
      final user = authProv.currentUser;
      final isGuest = authProv.isGuest || user == null;

      await WatchedReplayService.instance.saveWatchedReplay(
        loadedMatch,
        userId: user?.id,
        isGuest: isGuest,
      );

      if (!mounted) return;
      _openReplay(loadedMatch);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.lossRed,
          content: Text('replay.invalidFile'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _extractReplayCode(String input) {
    var trimmed = input.trim();
    if (trimmed.isEmpty) return '';

    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.pathSegments.contains('replay')) {
      final idx = uri.pathSegments.indexOf('replay');
      if (idx + 1 < uri.pathSegments.length) {
        return uri.pathSegments[idx + 1].trim();
      }
    }

    if (trimmed.contains('/')) {
      trimmed = trimmed.split('/').last.trim();
    }
    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final entries = _filteredEntries;

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: KitaAppBar(
        leadingIcon: Icons.video_library_rounded,
        iconColor: AppColors.primaryAmber,
        showAuthActions: false,
        showBack: true,
        showLanguageToggle: false,
        showThemeToggle: false,
        title: 'replay.watchedReplays'.tr(),
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
        padding: EdgeInsets.zero,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primaryAmber),
              )
            : RefreshIndicator(
                color: AppColors.primaryAmber,
                onRefresh: _loadWatchedReplays,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Subtitle / Header counter
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'replay.watchedReplaysSubtitle'.tr(),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.getTextMuted(isDark),
                              ),
                            ),
                            if (_watchedEntries.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryAmber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${_watchedEntries.length}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryAmber,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Search bar
                      if (_watchedEntries.isNotEmpty) ...[
                        Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.getSurface(isDark),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.getBorder(isDark)),
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) => setState(() => _searchQuery = val),
                            style: TextStyle(
                              fontSize: 13.5,
                              color: AppColors.getTextPrimary(isDark),
                            ),
                            decoration: InputDecoration(
                              hintText: 'chats.search'.tr(),
                              hintStyle: TextStyle(
                                fontSize: 13,
                                color: AppColors.getTextMuted(isDark),
                              ),
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: AppColors.getTextMuted(isDark),
                                size: 18,
                              ),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(
                                        Icons.clear_rounded,
                                        color: AppColors.getTextMuted(isDark),
                                        size: 16,
                                      ),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 9,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Matches List or Empty State
                      if (entries.isEmpty)
                        _buildEmptyState(isDark)
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: entries.length,
                          itemBuilder: (context, index) {
                            final entry = entries[index];
                            final prevEntry = index > 0 ? entries[index - 1] : null;
                            final showDateDivider = prevEntry == null ||
                                !_isSameDay(prevEntry.watchedAt, entry.watchedAt);

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (showDateDivider)
                                  _buildDateDivider(entry.watchedAt, isDark, isFirst: index == 0),
                                _buildWatchedMatchCard(context, entry.match, isDark),
                                const SizedBox(height: 8),
                              ],
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 30),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.getCard(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.getBorder(isDark)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryAmber.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.smart_display_outlined,
              size: 40,
              color: AppColors.primaryAmber,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'replay.noWatchedReplays'.tr(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.getTextPrimary(isDark),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'replay.noWatchedReplaysDesc'.tr(),
            style: TextStyle(
              fontSize: 13,
              color: AppColors.getTextSecondary(isDark),
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: _showLoadReplayDialog,
            icon: const Icon(Icons.file_open_rounded, size: 16),
            label: Text('replay.watchMatch'.tr()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryAmber,
              foregroundColor: AppColors.darkTextPrimary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWatchedMatchCard(
    BuildContext context,
    MatchRecordModel match,
    bool isDark,
  ) {
    final white = match.whitePlayer;
    final black = match.blackPlayer;

    final whiteName = (white?.username != null && white!.username.isNotEmpty)
        ? white.username
        : (match.whitePlayerId.isNotEmpty ? match.whitePlayerId : 'common.white'.tr());
    final blackName = (black?.username != null && black!.username.isNotEmpty)
        ? black.username
        : (match.blackPlayerId.isNotEmpty ? match.blackPlayerId : 'common.black'.tr());

    final isDraw = match.isDraw || match.isDrawOutcome;
    final whiteWon = !isDraw && match.winnerId != null && match.winnerId == match.whitePlayerId;
    final blackWon = !isDraw && match.winnerId != null && match.winnerId == match.blackPlayerId;

    final Color resultColor = isDraw
        ? AppColors.drawYellow
        : (whiteWon || blackWon ? AppColors.winGreen : AppColors.accentGold);

    final moveCount = match.totalMoves > 0 ? match.totalMoves : match.moves.length;
    String? durationText;
    if (match.endedAt != null) {
      final seconds = match.endedAt!.difference(match.startedAt).inSeconds;
      if (seconds > 0) {
        durationText = _formatDuration(seconds);
      }
    }

    return Dismissible(
      key: Key('watched_${match.id}'),
      direction: DismissDirection.horizontal,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
          color: AppColors.lossRed,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.lossRed,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
      ),
      onDismissed: (_) => _deleteReplay(match.id),
      child: KitaCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        onTap: () => _openReplay(match),
        child: Row(
          children: [
            // Left result pillar
            Container(
              width: 4,
              height: 44,
              decoration: BoxDecoration(
                color: resultColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),

            // Main info: White and Black players stacked vertically (alt alta)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Order rows so the winner is always shown on top
                  if (blackWon) ...[
                    // Black player row (Winner)
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            blackName,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.winGreen,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (black?.rating != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            '${black!.rating.toInt()}',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: AppColors.getTextMuted(isDark),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    // White player row
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey.shade600, width: 1),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            whiteName,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.getTextPrimary(isDark),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (white?.rating != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            '${white!.rating.toInt()}',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: AppColors.getTextMuted(isDark),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ] else ...[
                    // White player row (Winner or Draw)
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey.shade600, width: 1),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            whiteName,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: whiteWon ? FontWeight.w800 : FontWeight.w600,
                              color: whiteWon
                                  ? AppColors.winGreen
                                  : AppColors.getTextPrimary(isDark),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (white?.rating != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            '${white!.rating.toInt()}',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: AppColors.getTextMuted(isDark),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Black player row
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            blackName,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.getTextPrimary(isDark),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (black?.rating != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            '${black!.rating.toInt()}',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: AppColors.getTextMuted(isDark),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Moves count & duration stacked vertically (alt alta) next to play button
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'replay.movesCount'.tr(args: ['$moveCount']),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTextSecondary(isDark),
                  ),
                ),
                if (durationText != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    durationText,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.getTextMuted(isDark),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(width: 4),

            // Play icon action
            IconButton(
              icon: const Icon(
                Icons.play_circle_fill_rounded,
                color: AppColors.primaryAmber,
                size: 28,
              ),
              tooltip: 'replay.watchReplay'.tr(),
              onPressed: () => _openReplay(match),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    if (seconds < 0) seconds = 0;
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    final la = a.toLocal();
    final lb = b.toLocal();
    return la.year == lb.year && la.month == lb.month && la.day == lb.day;
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
    return DateFormat('d MMM y', context.locale.toString()).format(local);
  }

  Widget _buildDateDivider(DateTime date, bool isDark, {bool isFirst = false}) {
    return Padding(
      padding: EdgeInsets.only(top: isFirst ? 4 : 10, bottom: 8),
      child: Row(
        children: [
          Expanded(child: Divider(color: AppColors.getBorder(isDark), height: 1)),
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
          Expanded(child: Divider(color: AppColors.getBorder(isDark), height: 1)),
        ],
      ),
    );
  }
}
