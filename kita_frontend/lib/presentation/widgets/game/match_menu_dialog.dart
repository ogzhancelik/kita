import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/game_models.dart';
import '../../../data/models/ws_message_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/game_settings_provider.dart';
import '../../providers/offline_game_provider.dart';
import '../../providers/online_game_provider.dart';
import '../../screens/game/match_replay_screen.dart';
import '../home/settings_dialog.dart';
import 'game_over_dialog.dart';

/// Modal bottom sheet for in-match menu actions:
/// (Return to Main Menu / Results / Rematch | Settings, Rotate Board | Resign, Offer Draw)
///
/// Unified template shared by both online and offline matches.
class MatchMenuDialog extends StatelessWidget {
  final bool isOffline;

  const MatchMenuDialog({
    super.key,
    this.isOffline = false,
  });

  static Future<void> show(BuildContext context, {bool isOffline = false}) {
    FocusManager.instance.primaryFocus?.unfocus();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MatchMenuDialog(isOffline: isOffline),
    ).whenComplete(() {
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onlineProv = context.watch<OnlineGameProvider>();
    final offlineProv = context.watch<OfflineGameProvider>();
    final gameSettings = context.watch<GameSettingsProvider>();

    final isGameOver = isOffline
        ? offlineProv.gameOverData.value != null
        : onlineProv.gameOverData.value != null;

    final isLocalCoop = isOffline && offlineProv.offlinePlayMode == PlayMode.localCoop;
    final isHorizontal = isLocalCoop
        ? offlineProv.localCoopIsHorizontal
        : gameSettings.isHorizontal;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
        maxWidth: 520,
      ),
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.getSurface(isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(
          color: AppColors.getBorder(isDark),
          width: 1,
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 4, bottom: 12),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  'online.matchMenu'.tr(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.getTextPrimary(isDark),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // ─── Section 1: Navigation & Rematch ─────────────────────
              if (isOffline && !isGameOver)
                _MenuTile(
                  icon: Icons.replay_rounded,
                  iconColor: AppColors.primaryGreen,
                  title: 'game.newGame'.tr(),
                  textColor: AppColors.getTextPrimary(isDark),
                  onTap: () {
                    Navigator.of(context).pop();
                    offlineProv.requestRematch();
                  },
                ),

              _MenuTile(
                icon: Icons.home_rounded,
                iconColor: AppColors.accentGold,
                title: 'online.returnToMenu'.tr(),
                subtitle: 'online.returnToMenuDesc'.tr(),
                textColor: AppColors.getTextPrimary(isDark),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),

              if (isGameOver) ...[
                _MenuTile(
                  icon: Icons.analytics_outlined,
                  iconColor: AppColors.accentGold,
                  title: 'online.showResults'.tr(),
                  textColor: AppColors.getTextPrimary(isDark),
                  onTap: () {
                    Navigator.of(context).pop();
                    final data = isOffline
                        ? offlineProv.gameOverData.value
                        : onlineProv.gameOverData.value;
                    if (data != null) {
                      GameOverDialog.show(
                        context: context,
                        gameOverData: data,
                        myUserId: isOffline
                            ? (offlineProv.offlinePlayerId ?? 'local')
                            : (onlineProv.myUserId ?? ''),
                        isLocalCoop: isLocalCoop,
                        myTeam: isOffline ? offlineProv.myTeam : onlineProv.myTeam,
                        onRematch: () {
                          if (isOffline) {
                            offlineProv.requestRematch();
                          } else {
                            onlineProv.requestRematch();
                          }
                        },
                        onBackToMenu: () {
                          if (isOffline) {
                            offlineProv.resignAndClear();
                          } else {
                            onlineProv.leaveFinishedMatch();
                            context.read<AuthProvider>().refreshProfile();
                          }
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        },
                        onReviewMatch: (isOffline && offlineProv.offlinePlayMode == PlayMode.vsAi)
                            ? () {
                                final matchRecord = offlineProv.lastOfflineMatchRecord ??
                                    offlineProv.buildCurrentOfflineMatchRecord(data);
                                if (matchRecord != null) {
                                  Navigator.of(context, rootNavigator: true).pop();
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => MatchReplayScreen(match: matchRecord),
                                    ),
                                  );
                                }
                              }
                            : null,
                      );
                    }
                  },
                ),
                if (!isOffline && !onlineProv.isRematchRequested.value || isOffline)
                  _MenuTile(
                    icon: Icons.replay_rounded,
                    iconColor: AppColors.primaryGreen,
                    title: 'online.rematch'.tr(),
                    textColor: AppColors.getTextPrimary(isDark),
                    onTap: () {
                      Navigator.of(context).pop();
                      if (isOffline) {
                        offlineProv.requestRematch();
                      } else {
                        onlineProv.requestRematch();
                      }
                    },
                  ),
              ],

              // ─── Divider 1: return main menu | settings, rotate board ──
              _buildDivider(isDark),

              // ─── Section 2: Settings & Rotate Board ──────────────────
              _MenuTile(
                icon: Icons.settings_rounded,
                iconColor: AppColors.primaryGreen,
                title: 'settings.title'.tr(),
                subtitle: 'settings.generalSection'.tr(),
                textColor: AppColors.getTextPrimary(isDark),
                onTap: () {
                  Navigator.of(context).pop();
                  SettingsDialog.show(context);
                },
              ),

              _MenuTile(
                icon: Icons.rotate_90_degrees_cw_rounded,
                iconColor: AppColors.primaryGreen,
                title: 'online.rotateBoard'.tr(),
                subtitle: isHorizontal
                    ? 'game.orientationHorizontal'.tr()
                    : 'game.orientationVertical'.tr(),
                textColor: AppColors.getTextPrimary(isDark),
                showChevron: false,
                onTap: () {
                  if (isLocalCoop) {
                    offlineProv.toggleLocalCoopOrientation();
                  } else {
                    gameSettings.toggleOrientation();
                  }
                },
              ),

              // ─── Divider 2: settings, rotate board | resign, offer draw
              if (!isGameOver) ...[
                _buildDivider(isDark),

                // ─── Section 3: In-Match Actions (Resign, Draw) ────────
                _MenuTile(
                  icon: Icons.flag_outlined,
                  iconColor: AppColors.lossRed,
                  title: 'online.resign'.tr(),
                  textColor: AppColors.lossRed,
                  showChevron: false,
                  onTap: () {
                    Navigator.of(context).pop();
                    _confirmResign(context, isOffline: isOffline);
                  },
                ),

                if (!isOffline) ...[
                  ValueListenableBuilder<DrawOfferPayload?>(
                    valueListenable: onlineProv.drawOffer,
                    builder: (context, incomingOffer, _) {
                      if (incomingOffer != null) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _MenuTile(
                              icon: Icons.check_circle_outline,
                              iconColor: AppColors.primaryGreen,
                              title: 'online.acceptDraw'.tr(),
                              textColor: AppColors.primaryGreen,
                              showChevron: false,
                              onTap: () {
                                Navigator.of(context).pop();
                                onlineProv.acceptDrawOffer();
                              },
                            ),
                            _MenuTile(
                              icon: Icons.highlight_off_rounded,
                              iconColor: AppColors.lossRed,
                              title: 'online.declineDraw'.tr(),
                              textColor: AppColors.lossRed,
                              showChevron: false,
                              onTap: () {
                                Navigator.of(context).pop();
                                onlineProv.declineDrawOffer();
                              },
                            ),
                          ],
                        );
                      }

                      return ValueListenableBuilder<bool>(
                        valueListenable: onlineProv.isDrawOfferPending,
                        builder: (context, isPending, _) {
                          final drawColor = isPending
                              ? AppColors.getTextMuted(isDark)
                              : AppColors.getDraw(isDark);
                          return _MenuTile(
                            icon: Icons.handshake_outlined,
                            iconColor: drawColor,
                            title: isPending
                                ? 'online.drawOfferSent'.tr()
                                : 'online.drawOffer'.tr(),
                            textColor: drawColor,
                            showChevron: false,
                            onTap: isPending
                                ? null
                                : () {
                                    Navigator.of(context).pop();
                                    _confirmDrawOffer(context, onlineProv);
                                  },
                          );
                        },
                      );
                    },
                  ),
                ],
              ],

              const SizedBox(height: 8),

              // Cancel button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.getTextSecondary(isDark),
                    side: BorderSide(color: AppColors.getBorder(isDark)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text('online.cancel'.tr()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Divider(
        color: AppColors.getBorder(isDark),
        height: 1,
      ),
    );
  }

  void _confirmResign(BuildContext context, {required bool isOffline}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.getCard(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'online.resignTitle'.tr(),
          style: TextStyle(
            color: AppColors.getTextPrimary(isDark),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'online.resignConfirm'.tr(),
          style: TextStyle(color: AppColors.getTextSecondary(isDark)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'online.cancel'.tr(),
              style: TextStyle(color: AppColors.getTextSecondary(isDark)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (isOffline) {
                context.read<OfflineGameProvider>().resign();
              } else {
                context.read<OnlineGameProvider>().resign();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.lossRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('online.resign'.tr()),
          ),
        ],
      ),
    );
  }

  void _confirmDrawOffer(BuildContext context, OnlineGameProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.getCard(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'online.drawOfferTitle'.tr(),
          style: TextStyle(
            color: AppColors.getTextPrimary(isDark),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'online.drawOfferConfirm'.tr(),
          style: TextStyle(color: AppColors.getTextSecondary(isDark)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'online.cancel'.tr(),
              style: TextStyle(color: AppColors.getTextSecondary(isDark)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              provider.sendDrawOffer();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentGold,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('online.drawOffer'.tr()),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Color textColor;
  final Widget? trailing;
  final bool showChevron;
  final VoidCallback? onTap;

  const _MenuTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    required this.textColor,
    this.trailing,
    this.showChevron = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget? effectiveTrailing;
    if (trailing != null) {
      effectiveTrailing = trailing;
    } else if (showChevron) {
      effectiveTrailing = Icon(
        Icons.chevron_right_rounded,
        size: 20,
        color: AppColors.getTextMuted(isDark),
      );
    }

    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.getTextMuted(isDark),
                ),
              )
            : null,
        trailing: effectiveTrailing,
        onTap: onTap,
      ),
    );
  }
}
