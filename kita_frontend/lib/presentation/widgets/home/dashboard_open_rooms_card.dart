import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/ws_message_models.dart';
import '../../providers/online_game_provider.dart';
import '../../screens/room/room_browser_screen.dart';
import '../common/kita_card.dart';
import '../matchmaking/activity_conflict_dialog.dart';
import '../room/room_dialog.dart';

class DashboardOpenRoomsCard extends StatefulWidget {
  const DashboardOpenRoomsCard({super.key});

  @override
  State<DashboardOpenRoomsCard> createState() => _DashboardOpenRoomsCardState();
}

class _DashboardOpenRoomsCardState extends State<DashboardOpenRoomsCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<OnlineGameProvider>().requestRoomsList(page: 1, limit: 10000);
      }
    });
  }

  String _formatTimeControl(int ms) => TimeControlPreset.format(ms);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onlineProv = context.watch<OnlineGameProvider>();

    return KitaCard(
      padding: const EdgeInsets.all(14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with Title & Create Room Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RoomBrowserScreen()),
                ),
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.meeting_room_rounded,
                      color: AppColors.sectionOpenRooms,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'dashboard.openRooms'.tr(),
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

              // "Oda Kur" Button
              TextButton.icon(
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.primaryAmber.withValues(
                    alpha: 0.15,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => CreateRoomDialog.show(context),
                icon: const Icon(
                  Icons.add_rounded,
                  size: 16,
                  color: AppColors.primaryAmber,
                ),
                label: Text(
                  'dashboard.createRoom'.tr(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryAmber,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ValueListenable for Rooms List
          ValueListenableBuilder<RoomsListPayload?>(
            valueListenable: onlineProv.roomsList,
            builder: (ctx, roomsPayload, _) {
              final joinableRooms = onlineProv.joinableRooms;
              final rooms = joinableRooms.take(5).toList();

              if (rooms.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.inbox_rounded,
                          size: 32,
                          color: isDark
                              ? AppColors.darkTextMuted.withValues(alpha: 0.5)
                              : AppColors.lightTextMuted.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'dashboard.noOpenRooms'.tr(),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final remainingCount = joinableRooms.length - 5;
              final hasMore = remainingCount > 0;

              return Column(
                children: [
                  ...rooms.map((room) => _buildRoomTile(room, onlineProv, isDark)),
                  if (hasMore)
                    _buildViewAllTile(context, remainingCount, isDark),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildViewAllTile(
    BuildContext context,
    int remainingCount,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(top: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const RoomBrowserScreen()),
          ),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBg : AppColors.lightBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.primaryAmber.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryAmber.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.more_horiz_rounded,
                    size: 15,
                    color: AppColors.primaryAmber,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'dashboard.viewAllRooms'.tr(args: ['$remainingCount']),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryAmber,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 13,
                  color: AppColors.primaryAmber,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoomTile(
    RoomInfoPayload room,
    OnlineGameProvider onlineProv,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBg : AppColors.lightBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: room.hostOnline ? AppColors.online : AppColors.lossRed,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (room.hostOnline ? AppColors.online : AppColors.lossRed).withValues(alpha: 0.5),
                  blurRadius: 3,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        room.hostName,
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.ratingGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        room.displayRating,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.ratingGold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _formatTimeControl(room.timeControl),
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
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryAmber,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            onPressed: () async {
              final canProceed = await ActivityConflictHelper.checkAndConfirm(
                context: context,
                provider: onlineProv,
              );
              if (!canProceed) return;
              onlineProv.joinRoom(room.roomCode);
            },
            child: Text(
              'online.join'.tr(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
