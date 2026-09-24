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
        context.read<OnlineGameProvider>().requestRoomsList(page: 1, limit: 5);
      }
    });
  }

  String _formatTimeControl(int ms) {
    if (ms <= 0) return 'online.timeUnlimited'.tr();
    final mins = ms ~/ 60000;
    if (mins == 1) return 'online.timeBullet'.tr();
    if (mins == 3) return 'online.timeBlitz'.tr();
    if (mins == 5) return 'online.timeRapid'.tr();
    return 'online.minuteShort'.tr(args: ['$mins']);
  }

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
                      color: AppColors.winBlue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'dashboard.openRooms'.tr(),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ],
                ),
              ),

              // "Oda Kur" Button
              TextButton.icon(
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.15),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => CreateRoomDialog.show(context),
                icon: const Icon(Icons.add_rounded, size: 16, color: AppColors.primaryGreen),
                label: Text(
                  'dashboard.createRoomShort'.tr(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryGreen,
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
              final rooms = onlineProv.joinableRooms.take(5).toList();

              if (rooms.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.inbox_rounded,
                          size: 32,
                          color: isDark ? AppColors.darkTextMuted.withValues(alpha: 0.5) : AppColors.lightTextMuted.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'dashboard.noOpenRooms'.tr(),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: rooms.map((room) => _buildRoomTile(room, onlineProv, isDark)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRoomTile(RoomInfoPayload room, OnlineGameProvider onlineProv, bool isDark) {
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
              color: AppColors.online,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.online.withValues(alpha: 0.5),
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
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.ratingGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${room.hostRating}',
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
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
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
