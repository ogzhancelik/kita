import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/ws_message_models.dart';
import '../../providers/online_game_provider.dart';
import '../../widgets/common/kita_app_bar.dart';
import '../../widgets/common/kita_avatar.dart';
import '../../widgets/common/kita_button.dart';
import '../../widgets/common/kita_card.dart';
import '../../widgets/common/responsive_layout.dart';
import '../../widgets/home/user_profile_dialog.dart';
import '../../widgets/matchmaking/activity_conflict_dialog.dart';
import '../../widgets/room/room_dialog.dart';

/// Screen displaying public, joinable game rooms with server-side pagination.
class RoomBrowserScreen extends StatefulWidget {
  const RoomBrowserScreen({super.key});

  @override
  State<RoomBrowserScreen> createState() => _RoomBrowserScreenState();
}

class _RoomBrowserScreenState extends State<RoomBrowserScreen> {
  int _currentPage = 1;
  final int _limit = 10;
  String? _joiningRoomCode;

  @override
  void initState() {
    super.initState();
    _fetchRooms();
  }

  void _fetchRooms() {
    final provider = context.read<OnlineGameProvider>();
    provider.requestRoomsList(page: _currentPage, limit: _limit);
  }

  void _onNextPage(int totalPages) {
    if (_currentPage < totalPages) {
      setState(() => _currentPage++);
      _fetchRooms();
    }
  }

  void _onPrevPage() {
    if (_currentPage > 1) {
      setState(() => _currentPage--);
      _fetchRooms();
    }
  }

  Future<void> _handleJoin(String roomCode) async {
    final provider = context.read<OnlineGameProvider>();
    final canProceed = await ActivityConflictHelper.checkAndConfirm(
      context: context,
      provider: provider,
    );
    if (!canProceed) return;
    if (!mounted) return;
    setState(() => _joiningRoomCode = roomCode);
    provider.joinRoom(roomCode);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OnlineGameProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Show error snackbar if joining failed
    if (_joiningRoomCode != null && provider.lastError.value != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _joiningRoomCode != null) {
          final err = provider.lastError.value?.message ?? 'Error';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                err,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              backgroundColor: AppColors.lossRed,
            ),
          );
          setState(() => _joiningRoomCode = null);
          provider.clearError();
        }
      });
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: KitaAppBar(
        title: 'online.roomBrowserTitle'.tr(),
        showBack: true,
        showAuthActions: false,
        showLanguageToggle: false,
        showThemeToggle: false,
        iconColor: AppColors.winBlue,
        leadingIcon: Icons.meeting_room,
        extraActions: [
          IconButton(
            tooltip: 'common.refresh'.tr(),
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppColors.primaryAmber,
              size: 20,
            ),
            onPressed: _fetchRooms,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => CreateRoomDialog.show(context),
        backgroundColor: AppColors.primaryAmber,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, color: AppColors.darkTextPrimary),
        label: Text(
          'online.createRoom'.tr(),
          style: const TextStyle(
            color: AppColors.darkTextPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ResponsiveLayout(
        maxWidth: 640,
        padding: EdgeInsets.zero,
        child: ValueListenableBuilder<RoomsListPayload?>(
          valueListenable: provider.roomsList,
          builder: (ctx, payload, _) {
            if (payload == null) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primaryAmber),
              );
            }

            final rooms = payload.rooms.where((r) {
              if (provider.myUserId != null &&
                  provider.myUserId!.isNotEmpty &&
                  r.hostId == provider.myUserId) {
                return false;
              }
              if (provider.myUsername != null &&
                  provider.myUsername!.isNotEmpty &&
                  r.hostName == provider.myUsername) {
                return false;
              }
              if (provider.currentRoomCode != null &&
                  provider.currentRoomCode!.isNotEmpty &&
                  r.roomCode == provider.currentRoomCode) {
                return false;
              }
              return true;
            }).toList();
            final totalPages = (payload.total / _limit).ceil().clamp(1, 999);

            return RefreshIndicator(
              color: AppColors.primaryAmber,
              onRefresh: () async => _fetchRooms(),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14.0,
                        vertical: 12.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Join with code quick banner
                          _buildJoinWithCodeBanner(isDark),
                          const SizedBox(height: 14),

                          // 2. Section Header
                          _buildSectionHeader(payload.total, isDark),
                          const SizedBox(height: 10),

                          // 3. Rooms List or Empty State
                          if (rooms.isEmpty)
                            _buildEmptyState(isDark)
                          else
                            ...rooms.map((room) {
                              final isJoining =
                                  _joiningRoomCode == room.roomCode;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10.0),
                                child: _RoomCard(
                                  room: room,
                                  isDark: isDark,
                                  isJoining: isJoining,
                                  onJoin: () => _handleJoin(room.roomCode),
                                ),
                              );
                            }),
                          const SizedBox(height: 70), // Padding for FAB
                        ],
                      ),
                    ),
                  ),

                  // 4. Pagination Bar
                  if (payload.total > _limit)
                    _buildPaginationBar(totalPages, isDark),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildJoinWithCodeBanner(bool isDark) {
    return KitaCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      onTap: () => JoinRoomDialog.show(context),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.primaryAmber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.pin_rounded,
              size: 18,
              color: AppColors.primaryAmber,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'online.joinRoom'.tr(),
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
                  'online.privateRoomDesc'.tr(),
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
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(int totalCount, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'online.roomBrowserTitle'.tr(),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
        ),
        if (totalCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primaryAmber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'online.activePublicRooms'.tr(args: ['$totalCount']),
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryAmber,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPaginationBar(int totalPages, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          InkWell(
            onTap: _currentPage > 1 ? _onPrevPage : null,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _currentPage > 1
                    ? AppColors.primaryAmber.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.chevron_left_rounded,
                size: 22,
                color: _currentPage > 1
                    ? AppColors.primaryAmber
                    : (isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Text(
              'online.pageIndicator'.tr(args: ['$_currentPage', '$totalPages']),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          InkWell(
            onTap: _currentPage < totalPages
                ? () => _onNextPage(totalPages)
                : null,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _currentPage < totalPages
                    ? AppColors.primaryAmber.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: _currentPage < totalPages
                    ? AppColors.primaryAmber
                    : (isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted),
              ),
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
            Icons.meeting_room_outlined,
            size: 48,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
          const SizedBox(height: 12),
          Text(
            'online.noRoomsFound'.tr(),
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
            'online.noRoomsDesc'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 180,
            child: KitaButton(
              text: 'online.createRoom'.tr(),
              icon: Icons.add_rounded,
              height: 40,
              fontSize: 13,
              onPressed: () => CreateRoomDialog.show(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  final RoomInfoPayload room;
  final bool isDark;
  final bool isJoining;
  final VoidCallback onJoin;

  const _RoomCard({
    required this.room,
    required this.isDark,
    required this.isJoining,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    final mins = room.timeControl ~/ 60000;
    final timeStr = room.timeControl == 0
        ? 'online.timeUnlimited'.tr()
        : 'online.minuteShort'.tr(args: ['$mins']);

    return KitaCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: isJoining ? null : onJoin,
      child: Row(
        children: [
          // Host Avatar with profile popup on tap
          GestureDetector(
            onTap: () {
              if (room.hostId != null && room.hostId!.isNotEmpty) {
                UserProfileDialog.show(
                  context,
                  userId: room.hostId!,
                  fallbackName: room.hostName,
                  fallbackAvatarIndex: room.hostAvatarIndex,
                  fallbackAvatarCustom: room.hostAvatarCustom,
                  fallbackRating: room.hostRating,
                );
              }
            },
            child: KitaAvatar(
              size: 40,
              avatarIndex: room.hostAvatarIndex,
              avatarCustom: room.hostAvatarCustom,
              borderWidth: 1.5,
            ),
          ),
          const SizedBox(width: 12),

          // Host & Room Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        room.hostName.isNotEmpty
                            ? room.hostName
                            : 'online.roomHost'.tr(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.getTextPrimary(isDark),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryAmber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.primaryAmber.withValues(alpha: 0.35),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        room.roomCode,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          letterSpacing: 0.8,
                          color: AppColors.primaryAmber,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      '★ ${room.displayRating}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ratingGold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '·',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.getTextMuted(isDark),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.timer_outlined,
                      size: 13,
                      color: AppColors.getTextMuted(isDark),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.getTextSecondary(isDark),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Join Button
          SizedBox(
            width: 76,
            child: KitaButton(
              text: 'online.join'.tr(),
              height: 36,
              fontSize: 13,
              isLoading: isJoining,
              onPressed: isJoining ? null : onJoin,
            ),
          ),
        ],
      ),
    );
  }
}
