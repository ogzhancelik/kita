import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../data/models/friend_models.dart';
import '../../data/models/notification_model.dart';
import '../../data/models/ws_message_models.dart';
import '../../data/services/notification_api_service.dart';
import '../widgets/matchmaking/activity_conflict_dialog.dart';
import 'friends_provider.dart';
import 'online_game_provider.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationApiService _apiService;
  final List<KitaNotification> _notifications = [];
  bool _isDashboardActive = true;
  bool _isLoading = false;

  NotificationProvider([NotificationApiService? apiService])
      : _apiService = apiService ?? NotificationApiService();

  bool get isDashboardActive => _isDashboardActive;
  bool get isLoading => _isLoading;

  /// Clears in-memory notifications (e.g. on logout or guest switch).
  void clear() {
    _notifications.clear();
    _isLoading = false;
    notifyListeners();
  }

  /// Loads persistent notifications from the backend.
  Future<void> loadNotifications() async {
    if (_apiService.runtimeType == NotificationApiService &&
        (ApiClient.currentToken == null || ApiClient.currentToken!.isEmpty)) {
      return;
    }

    _isLoading = true;

    try {
      final result = await _apiService.fetchNotifications();
      // Keep any active live rematch notifications in memory
      final rematches = _notifications.where((n) => n.type == KitaNotificationType.rematch).toList();
      _notifications.clear();
      _notifications.addAll(rematches);

      for (final n in result.notifications) {
        if (!_notifications.any((existing) => existing.id == n.id)) {
          _notifications.add(n);
        }
      }
    } catch (e) {
      debugPrint('[NotificationProvider] Failed to load notifications: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setDashboardActive(bool active) {
    if (_isDashboardActive != active) {
      _isDashboardActive = active;
      notifyListeners();
    }
  }

  /// All notifications in chronological order (newest first).
  List<KitaNotification> get allNotifications {
    final list = List<KitaNotification>.from(_notifications);
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  /// Interactive notifications that haven't been interacted with yet (status == pending),
  /// sorted primarily by priority: Rematch (1) > Challenge (2) > Friend Request (3),
  /// and secondarily by timestamp (newest first).
  List<KitaNotification> get pendingNotifications {
    final list = _notifications.where((n) => n.isPending).toList();
    list.sort((a, b) {
      final pComp = a.priority.compareTo(b.priority);
      if (pComp != 0) return pComp;
      return b.timestamp.compareTo(a.timestamp);
    });
    return list;
  }

  /// Top 3 non-interacted actionable notifications for the Home Menu summary card.
  List<KitaNotification> get homeSummaryNotifications {
    return pendingNotifications.take(3).toList();
  }

  /// True if there are any unread info notifications or pending actionable notifications.
  bool get hasUnread {
    return _notifications.any((n) => !n.isRead) || pendingNotifications.isNotEmpty;
  }

  /// Unread badge count.
  int get unreadCount {
    return _notifications.where((n) => !n.isRead).length;
  }

  /// Add a notification if not already present.
  void addNotification(KitaNotification notification) {
    final existingIdx = _notifications.indexWhere((n) => n.id == notification.id);
    if (existingIdx >= 0) {
      _notifications[existingIdx] = notification;
    } else {
      _notifications.insert(0, notification);
    }
    notifyListeners();
  }

  /// Mark all informational notifications as read.
  void markInformationalAsRead() {
    bool changed = false;
    for (int i = 0; i < _notifications.length; i++) {
      final n = _notifications[i];
      if (n.type == KitaNotificationType.info && !n.isRead) {
        _notifications[i] = n.copyWith(status: NotificationStatus.read);
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
      _apiService.markAllAsRead().catchError((e) {
        debugPrint('[NotificationProvider] Failed to sync markAllAsRead to backend: $e');
      });
    }
  }

  /// Ignore a notification (triggered by swipe left or right).
  /// Ignored notifications transition into a dimmed/read state and leave the home summary.
  void ignoreNotification(String id) {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx >= 0) {
      _notifications[idx] = _notifications[idx].copyWith(
        status: NotificationStatus.ignored,
      );
      notifyListeners();
      _apiService.updateStatus(id, NotificationStatus.ignored).catchError((e) {
        debugPrint('[NotificationProvider] Failed to sync ignoreNotification to backend: $e');
      });
    }
  }

  /// Accept an actionable notification.
  Future<void> acceptNotification(BuildContext context, String id) async {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx < 0) return;
    final notif = _notifications[idx];

    // Mark as accepted immediately in state
    _notifications[idx] = notif.copyWith(status: NotificationStatus.accepted);
    notifyListeners();

    if (notif.type != KitaNotificationType.rematch) {
      _apiService.updateStatus(id, NotificationStatus.accepted).catchError((e) {
        debugPrint('[NotificationProvider] Failed to sync acceptNotification to backend: $e');
      });
    }

    try {
      if (notif.type == KitaNotificationType.rematch || notif.type == KitaNotificationType.challenge) {
        final onlineProv = context.read<OnlineGameProvider>();
        final canProceed = await ActivityConflictHelper.checkAndConfirm(
          context: context,
          provider: onlineProv,
        );
        if (!canProceed) return;

        if (notif.type == KitaNotificationType.rematch) {
          onlineProv.acceptRematch(notif.matchId);
        } else {
          if (notif.inviteId != null && notif.inviteId!.isNotEmpty) {
            onlineProv.acceptInvitation(notif.inviteId!);
          } else {
            onlineProv.acceptIncomingRequest();
          }
        }
      } else if (notif.type == KitaNotificationType.friendRequest && notif.friendshipId != null) {
        final friendsProv = context.read<FriendsProvider>();
        await friendsProv.acceptRequest(notif.friendshipId!);
      }
    } catch (e) {
      debugPrint('[NotificationProvider] Error accepting notification $id: $e');
    }
  }

  /// Decline an actionable notification.
  Future<void> declineNotification(BuildContext context, String id) async {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx < 0) return;
    final notif = _notifications[idx];

    // Mark as declined immediately in state
    _notifications[idx] = notif.copyWith(status: NotificationStatus.declined);
    notifyListeners();

    if (notif.type != KitaNotificationType.rematch) {
      _apiService.updateStatus(id, NotificationStatus.declined).catchError((e) {
        debugPrint('[NotificationProvider] Failed to sync declineNotification to backend: $e');
      });
    }

    try {
      if (notif.type == KitaNotificationType.rematch) {
        final onlineProv = context.read<OnlineGameProvider>();
        onlineProv.declineRematch(notif.matchId);
      } else if (notif.type == KitaNotificationType.challenge) {
        final onlineProv = context.read<OnlineGameProvider>();
        if (notif.inviteId != null && notif.inviteId!.isNotEmpty) {
          onlineProv.declineInvitation(notif.inviteId!);
        } else {
          onlineProv.declineIncomingRequest();
        }
      } else if (notif.type == KitaNotificationType.friendRequest && notif.friendshipId != null) {
        final friendsProv = context.read<FriendsProvider>();
        await friendsProv.declineRequest(notif.friendshipId!);
      }
    } catch (e) {
      debugPrint('[NotificationProvider] Error declining notification $id: $e');
    }
  }

  /// Synchronize action taken on a friendship from elsewhere (e.g. FriendsScreen).
  void syncFriendshipActioned(String friendshipId, NotificationStatus status) {
    final id = 'friend_request_$friendshipId';
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx >= 0) {
      _notifications[idx] = _notifications[idx].copyWith(status: status);
      notifyListeners();
      _apiService.updateStatus(id, status).catchError((e) {
        debugPrint('[NotificationProvider] Failed to sync friendship action to backend: $e');
      });
    }
  }

  /// Add informational notification for rematch rejection.
  void addRematchDeclinedNotification(String? declinerName) {
    final name = (declinerName != null && declinerName.isNotEmpty) ? declinerName : 'Rakip';
    final notif = KitaNotification(
      id: 'rematch_declined_${DateTime.now().millisecondsSinceEpoch}',
      type: KitaNotificationType.info,
      status: NotificationStatus.pending,
      title: 'notifications.rematchDeclinedTitle',
      subtitle: 'notifications.rematchDeclinedSubtitle'.tr(args: [name]),
      senderName: name,
      timestamp: DateTime.now(),
    );
    addNotification(notif);
  }

  /// Add informational notification for match invitation/challenge rejection.
  void addChallengeDeclinedNotification(String? declinerName) {
    final name = (declinerName != null && declinerName.isNotEmpty) ? declinerName : 'Arkadaş';
    final notif = KitaNotification(
      id: 'challenge_declined_${DateTime.now().millisecondsSinceEpoch}',
      type: KitaNotificationType.info,
      status: NotificationStatus.pending,
      title: 'notifications.challengeDeclinedTitle',
      subtitle: 'notifications.challengeDeclinedSubtitle'.tr(args: [name]),
      senderName: name,
      timestamp: DateTime.now(),
    );
    addNotification(notif);
  }

  /// Remove or decline an incoming challenge that was cancelled by inviter.
  void removeOrExpireChallenge({String? inviteId, String? inviterId}) {
    bool removed = false;
    _notifications.removeWhere((n) {
      if (n.type != KitaNotificationType.challenge) return false;
      final matchInvite = (inviteId != null && inviteId.isNotEmpty) &&
          (n.inviteId == inviteId || n.id == 'challenge_$inviteId' || n.id == inviteId);
      final matchInviter = (inviterId != null && inviterId.isNotEmpty) &&
          (n.actorId == inviterId);
      if (matchInvite || matchInviter) {
        removed = true;
        return true;
      }
      return false;
    });

    if (removed) {
      notifyListeners();
    }
    loadNotifications();
  }

  /// Add informational notification for friend request rejection.
  void addFriendRequestDeclinedNotification(String? declinerName) {
    final name = (declinerName != null && declinerName.isNotEmpty) ? declinerName : 'Kullanıcı';
    final notif = KitaNotification(
      id: 'friend_request_declined_${DateTime.now().millisecondsSinceEpoch}',
      type: KitaNotificationType.info,
      status: NotificationStatus.pending,
      title: 'notifications.friendRequestDeclinedTitle',
      subtitle: 'notifications.friendRequestDeclinedSubtitle'.tr(args: [name]),
      senderName: name,
      timestamp: DateTime.now(),
    );
    addNotification(notif);
  }

  /// Add informational notification for friend request acceptance.
  void addFriendRequestAcceptedNotification(String? accepterName) {
    final name = (accepterName != null && accepterName.isNotEmpty) ? accepterName : 'Kullanıcı';
    final notif = KitaNotification(
      id: 'friend_request_accepted_${DateTime.now().millisecondsSinceEpoch}',
      type: KitaNotificationType.info,
      status: NotificationStatus.pending,
      title: 'notifications.friendRequestAcceptedTitle',
      subtitle: 'notifications.friendRequestAcceptedSubtitle'.tr(args: [name]),
      senderName: name,
      timestamp: DateTime.now(),
    );
    addNotification(notif);
  }

  /// Synchronize incoming friend request from WebSocket message.
  void syncFromWsFriendRequest(Map<String, dynamic> payload) {
    final friendshipId = payload['friendship_id']?.toString() ?? '';
    final username = payload['username']?.toString() ?? '';
    final rating = (payload['rating'] as num?)?.toInt() ?? 1200;
    final createdAtStr = payload['created_at']?.toString() ?? '';
    final createdAt = DateTime.tryParse(createdAtStr) ?? DateTime.now();

    final id = 'friend_request_$friendshipId';
    final existingIdx = _notifications.indexWhere((n) => n.id == id);
    if (existingIdx < 0) {
      final notif = KitaNotification(
        id: id,
        type: KitaNotificationType.friendRequest,
        status: NotificationStatus.pending,
        title: 'notifications.friendRequestTitle',
        subtitle: username,
        senderName: username,
        senderRating: rating,
        friendshipId: friendshipId,
        timestamp: createdAt,
      );
      _notifications.insert(0, notif);
      notifyListeners();
    }
  }

  /// Remove notification completely.
  void removeNotification(String id) {
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();
    _apiService.deleteNotification(id).catchError((e) {
      debugPrint('[NotificationProvider] Failed to sync deleteNotification to backend: $e');
    });
  }

  /// Clear all read/actioned/ignored notifications.
  void clearInteracted() {
    _notifications.removeWhere((n) => !n.isPending);
    notifyListeners();
  }

  /// Synchronize from incoming match request in OnlineGameProvider.
  void syncFromIncomingMatchRequest(IncomingMatchRequest? req) {
    if (req == null) return;

    final notifType = req.type == IncomingMatchRequestType.rematch
        ? KitaNotificationType.rematch
        : KitaNotificationType.challenge;

    final id = '${notifType.name}_${req.id}';
    final existingIdx = _notifications.indexWhere((n) => n.id == id);
    if (existingIdx >= 0) {
      // Already tracked
      return;
    }

    final notif = KitaNotification(
      id: id,
      type: notifType,
      status: NotificationStatus.pending,
      title: notifType == KitaNotificationType.rematch
          ? 'notifications.rematchTitle'
          : 'notifications.challengeTitle',
      subtitle: req.senderName,
      senderName: req.senderName,
      senderRating: req.senderRating,
      timeControl: req.timeControl,
      colorPreference: req.colorPreference,
      actorId: req.senderId,
      matchId: notifType == KitaNotificationType.rematch ? req.id : null,
      inviteId: notifType == KitaNotificationType.challenge ? req.id : null,
      timestamp: DateTime.now(),
    );

    addNotification(notif);
  }

  /// Synchronize incoming friend requests from FriendsProvider.
  void syncFromFriendRequests(List<FriendItemModel> incoming) {
    bool changed = false;
    for (final item in incoming) {
      final id = 'friend_request_${item.friendshipId}';
      final existingIdx = _notifications.indexWhere((n) => n.id == id);
      if (existingIdx < 0) {
        final notif = KitaNotification(
          id: id,
          type: KitaNotificationType.friendRequest,
          status: NotificationStatus.pending,
          title: 'notifications.friendRequestTitle',
          subtitle: item.username,
          senderName: item.username,
          senderRating: item.rating,
          friendshipId: item.friendshipId,
          timestamp: item.createdAt,
        );
        _notifications.insert(0, notif);
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
    }
  }
}
