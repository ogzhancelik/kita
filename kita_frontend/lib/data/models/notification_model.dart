import 'package:flutter/foundation.dart';

enum KitaNotificationType {
  rematch,       // Priority 1
  challenge,     // Priority 2
  friendRequest, // Priority 3
  info,          // Priority 4
}

enum NotificationStatus {
  pending,  // actionable and not interacted yet
  accepted,
  declined,
  ignored,
  read,     // read info notification
}

@immutable
class KitaNotification {
  final String id;
  final KitaNotificationType type;
  final NotificationStatus status;
  final String title;
  final String subtitle;
  final String? senderName;
  final int? senderRating;
  final int? timeControl;
  final String? colorPreference;
  final String? matchId;
  final String? inviteId;
  final String? friendshipId;
  final DateTime timestamp;

  const KitaNotification({
    required this.id,
    required this.type,
    this.status = NotificationStatus.pending,
    required this.title,
    required this.subtitle,
    this.senderName,
    this.senderRating,
    this.timeControl,
    this.colorPreference,
    this.matchId,
    this.inviteId,
    this.friendshipId,
    required this.timestamp,
  });

  int get priority {
    switch (type) {
      case KitaNotificationType.rematch:
        return 1;
      case KitaNotificationType.challenge:
        return 2;
      case KitaNotificationType.friendRequest:
        return 3;
      case KitaNotificationType.info:
        return 4;
    }
  }

  bool get isActionable => type != KitaNotificationType.info;
  bool get isPending => status == NotificationStatus.pending;
  bool get isIgnored => status == NotificationStatus.ignored;
  bool get isRead =>
      status == NotificationStatus.read ||
      status == NotificationStatus.ignored ||
      status == NotificationStatus.accepted ||
      status == NotificationStatus.declined;

  KitaNotification copyWith({
    NotificationStatus? status,
    String? title,
    String? subtitle,
  }) {
    return KitaNotification(
      id: id,
      type: type,
      status: status ?? this.status,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      senderName: senderName,
      senderRating: senderRating,
      timeControl: timeControl,
      colorPreference: colorPreference,
      matchId: matchId,
      inviteId: inviteId,
      friendshipId: friendshipId,
      timestamp: timestamp,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KitaNotification &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          status == other.status;

  @override
  int get hashCode => id.hashCode ^ status.hashCode;
}
