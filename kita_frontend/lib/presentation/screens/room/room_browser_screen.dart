import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/ws_message_models.dart';
import '../../providers/online_game_provider.dart';
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
              content: Text(err),
              backgroundColor: AppColors.lossRed,
            ),
          );
          setState(() => _joiningRoomCode = null);
          provider.clearError();
        }
      });
    }


    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        title: Text('online.roomBrowserTitle'.tr()),
        backgroundColor: AppColors.getCard(isDark),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'online.refresh'.tr(),
            onPressed: _fetchRooms,
          ),
        ],
      ),
      body: ValueListenableBuilder<RoomsListPayload?>(
        valueListenable: provider.roomsList,
        builder: (ctx, payload, _) {
          if (payload == null) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            );
          }

          final rooms = payload.rooms.where((r) {
            if (provider.myUserId != null && provider.myUserId!.isNotEmpty && r.hostId == provider.myUserId) {
              return false;
            }
            if (provider.myUsername != null && provider.myUsername!.isNotEmpty && r.hostName == provider.myUsername) {
              return false;
            }
            if (provider.currentRoomCode != null && provider.currentRoomCode!.isNotEmpty && r.roomCode == provider.currentRoomCode) {
              return false;
            }
            return true;
          }).toList();
          final totalPages = (payload.total / _limit).ceil().clamp(1, 999);

          return RefreshIndicator(
            color: AppColors.primaryGreen,
            onRefresh: () async => _fetchRooms(),
            child: Column(
              children: [
                // Top stats bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: AppColors.getSurface(isDark),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'online.activePublicRooms'.tr(args: ['${payload.total}']),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.getTextSecondary(isDark),
                        ),
                      ),
                      Text(
                        'online.pageIndicator'.tr(
                          args: ['$_currentPage', '$totalPages'],
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.getTextMuted(isDark),
                        ),
                      ),
                    ],
                  ),
                ),

                // Rooms List
                Expanded(
                  child: rooms.isEmpty
                      ? _buildEmptyState(isDark)
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: rooms.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (ctx, index) {
                            final room = rooms[index];
                            final isJoining = _joiningRoomCode == room.roomCode;
                            return _RoomCard(
                              room: room,
                              isDark: isDark,
                              isJoining: isJoining,
                              onJoin: () async {
                                final canProceed = await ActivityConflictHelper.checkAndConfirm(
                                  context: context,
                                  provider: provider,
                                );
                                if (!canProceed) return;
                                if (!context.mounted) return;
                                setState(() => _joiningRoomCode = room.roomCode);
                                provider.joinRoom(room.roomCode);
                              },
                            );
                          },
                        ),
                ),

                // Pagination bar
                if (payload.total > _limit)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.getCard(isDark),
                      border: Border(
                        top: BorderSide(color: AppColors.getBorder(isDark)),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: _currentPage > 1 ? _onPrevPage : null,
                          color: AppColors.primaryGreen,
                        ),
                        const SizedBox(width: 16),
                        Text(
                          '$_currentPage / $totalPages',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.getTextPrimary(isDark),
                          ),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed:
                              _currentPage < totalPages ? () => _onNextPage(totalPages) : null,
                          color: AppColors.primaryGreen,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => CreateRoomDialog.show(context),
        backgroundColor: AppColors.primaryGreen,
        icon: const Icon(Icons.add, color: AppColors.darkTextPrimary),
        label: Text(
          'online.createRoom'.tr(),
          style: const TextStyle(
            color: AppColors.darkTextPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.meeting_room_outlined,
            size: 64,
            color: AppColors.getTextMuted(isDark),
          ),
          const SizedBox(height: 16),
          Text(
            'online.noRoomsFound'.tr(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.getTextSecondary(isDark),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'online.noRoomsDesc'.tr(),
            style: TextStyle(
              fontSize: 13,
              color: AppColors.getTextMuted(isDark),
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => CreateRoomDialog.show(context),
            icon: const Icon(Icons.add),
            label: Text('online.createRoom'.tr()),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryGreen,
              side: const BorderSide(color: AppColors.primaryGreen),
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.getCard(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.getBorder(isDark)),
      ),
      child: Row(
        children: [
          // Room Code Tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              room.roomCode,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppColors.primaryGreen,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  room.hostName.isNotEmpty
                      ? room.hostName
                      : 'online.roomHost'.tr(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.getTextPrimary(isDark),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 13,
                      color: AppColors.getTextMuted(isDark),
                    ),
                    const SizedBox(width: 4),
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

          // Join Button
          ElevatedButton(
            onPressed: isJoining ? null : onJoin,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: AppColors.darkTextPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: isJoining
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.darkTextPrimary,
                    ),
                  )
                : Text('online.join'.tr()),
          ),
        ],
      ),
    );
  }
}
