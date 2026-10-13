import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/friend_models.dart';
import '../../providers/friends_provider.dart';
import '../common/avatar_picker.dart';
import '../home/user_profile_dialog.dart';

/// Dedicated player search view backed by server-side query,
/// showing player tiles with inline "Add Friend" actions.
class PlayerSearchView extends StatefulWidget {
  final bool isModal;
  final VoidCallback? onClose;

  const PlayerSearchView({
    super.key,
    this.isModal = false,
    this.onClose,
  });

  @override
  State<PlayerSearchView> createState() => _PlayerSearchViewState();
}

class _PlayerSearchViewState extends State<PlayerSearchView> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounceTimer;

  List<PlayerSearchResultModel> _results = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  String _lastQuery = '';
  final Map<String, bool> _pendingActions = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final query = _searchController.text;
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
        _hasSearched = false;
        _lastQuery = '';
      });
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _executeSearch(query);
    });
  }

  Future<void> _executeSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _lastQuery = trimmed;
    });

    final friendsProv = context.read<FriendsProvider>();
    final results = await friendsProv.searchPlayers(trimmed);

    if (!mounted) return;

    // Check if query is still the same
    if (_searchController.text.trim() == trimmed) {
      setState(() {
        _results = results;
        _isSearching = false;
      });
    }
  }

  Future<void> _sendFriendRequest(PlayerSearchResultModel player) async {
    setState(() {
      _pendingActions[player.id] = true;
    });

    final friendsProv = context.read<FriendsProvider>();
    final ok = await friendsProv.sendRequest(player.username);

    if (!mounted) return;

    setState(() {
      _pendingActions[player.id] = false;
      if (ok) {
        final idx = _results.indexWhere((r) => r.id == player.id);
        if (idx != -1) {
          _results[idx] = _results[idx].copyWith(friendshipStatus: 'outgoing');
        }
      }
    });

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.winGreen,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'online.friendRequestSent'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.darkCard,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AppColors.lossRed,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  friendsProv.errorMessage ?? 'online.friendRequestFailed'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.darkCard,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _acceptFriendRequest(PlayerSearchResultModel player) async {
    if (player.friendshipId == null || player.friendshipId!.isEmpty) return;

    setState(() {
      _pendingActions[player.id] = true;
    });

    final friendsProv = context.read<FriendsProvider>();
    final ok = await friendsProv.acceptRequest(player.friendshipId!);

    if (!mounted) return;

    setState(() {
      _pendingActions[player.id] = false;
      if (ok) {
        final idx = _results.indexWhere((r) => r.id == player.id);
        if (idx != -1) {
          _results[idx] = _results[idx].copyWith(friendshipStatus: 'friend');
        }
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.removeListener(_onTextChanged);
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search Input Bar
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: widget.isModal ? 20 : 16,
            vertical: 12,
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _focusNode,
            autofocus: widget.isModal,
            textInputAction: TextInputAction.search,
            onSubmitted: (v) => _executeSearch(v),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.getTextPrimary(isDark),
            ),
            decoration: InputDecoration(
              hintText: 'online.searchPlayersHint'.tr(),
              hintStyle: TextStyle(
                fontSize: 14,
                color: AppColors.getTextMuted(isDark),
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 20,
                color: AppColors.getTextMuted(isDark),
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear_rounded,
                        size: 18,
                        color: AppColors.getTextMuted(isDark),
                      ),
                      onPressed: () {
                        _searchController.clear();
                        _focusNode.requestFocus();
                      },
                      splashRadius: 18,
                    )
                  : null,
              filled: true,
              fillColor: AppColors.getSurface(isDark),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.getBorder(isDark)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.getBorder(isDark)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primaryGreen,
                  width: 1.6,
                ),
              ),
            ),
          ),
        ),

        // Results / Empty / Loading content
        Expanded(
          child: _buildContent(isDark),
        ),
      ],
    );
  }

  Widget _buildContent(bool isDark) {
    if (_isSearching) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: AppColors.primaryGreen,
              strokeWidth: 2.2,
            ),
            const SizedBox(height: 12),
            Text(
              'online.searchPlayers'.tr(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.getTextMuted(isDark),
              ),
            ),
          ],
        ),
      );
    }

    if (!_hasSearched || _searchController.text.trim().isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.getBrandPrimary(isDark).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_search_rounded,
                  color: AppColors.getBrandPrimary(isDark),
                  size: 32,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'online.searchPlayers'.tr(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.getTextPrimary(isDark),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'online.searchPrompt'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.getTextSecondary(isDark),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 52,
                color: AppColors.getTextMuted(isDark),
              ),
              const SizedBox(height: 12),
              Text(
                'online.noPlayersFound'.tr(),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.getTextPrimary(isDark),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'online.noPlayersFoundSubtitle'.tr(args: [_lastQuery]),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.getTextSecondary(isDark),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.symmetric(
        horizontal: widget.isModal ? 20 : 16,
        vertical: 8,
      ),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final player = _results[index];
        return _PlayerSearchTile(
          player: player,
          isDark: isDark,
          isPending: _pendingActions[player.id] == true,
          onAddFriend: () => _sendFriendRequest(player),
          onAcceptRequest: () => _acceptFriendRequest(player),
          onTap: () {
            UserProfileDialog.show(context, userId: player.id);
          },
        );
      },
    );
  }
}

class _PlayerSearchTile extends StatelessWidget {
  final PlayerSearchResultModel player;
  final bool isDark;
  final bool isPending;
  final VoidCallback onAddFriend;
  final VoidCallback onAcceptRequest;
  final VoidCallback onTap;

  const _PlayerSearchTile({
    required this.player,
    required this.isDark,
    required this.isPending,
    required this.onAddFriend,
    required this.onAcceptRequest,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final avatarItem = AvatarPicker.avatars[player.avatarIndex % AvatarPicker.avatars.length];

    return Material(
      color: AppColors.getSurface(isDark),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.getBorder(isDark),
              width: 1.1,
            ),
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: avatarItem.accentColor.withValues(alpha: 0.18),
                  border: Border.all(
                    color: avatarItem.accentColor.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  avatarItem.icon,
                  color: avatarItem.accentColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),

              // Player Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      player.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.getTextPrimary(isDark),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        // Rating Tag
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: AppColors.accentGold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.emoji_events_rounded,
                                size: 11,
                                color: AppColors.accentGold,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                player.displayRating,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.accentGold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Inline Action
              _buildActionWidget(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionWidget() {
    switch (player.friendshipStatus) {
      case 'friend':
        return Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.winGreen.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.winGreen.withValues(alpha: 0.35),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_rounded,
                size: 15,
                color: AppColors.winGreen,
              ),
              const SizedBox(width: 6),
              Text(
                'online.statusFriends'.tr(),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.winGreen,
                ),
              ),
            ],
          ),
        );

      case 'outgoing':
        return Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.accentGold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.accentGold.withValues(alpha: 0.35),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 15,
                color: AppColors.accentGold,
              ),
              const SizedBox(width: 6),
              Text(
                'online.statusRequested'.tr(),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accentGold,
                ),
              ),
            ],
          ),
        );

      case 'incoming':
        return SizedBox(
          height: 34,
          child: ElevatedButton.icon(
            onPressed: isPending ? null : onAcceptRequest,
            icon: isPending
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.darkTextPrimary,
                    ),
                  )
                : const Icon(Icons.check_rounded, size: 15),
            label: Text(
              'online.statusAccept'.tr(),
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: AppColors.darkTextPrimary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        );

      case 'none':
      default:
        return SizedBox(
          height: 34,
          child: ElevatedButton.icon(
            onPressed: isPending ? null : onAddFriend,
            icon: isPending
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.darkTextPrimary,
                    ),
                  )
                : const Icon(Icons.person_add_alt_1_rounded, size: 15),
            label: Text(
              'online.addFriendAction'.tr(),
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: AppColors.darkTextPrimary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        );
    }
  }
}
