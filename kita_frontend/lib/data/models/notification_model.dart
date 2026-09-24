import 'dart:convert';
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
  final String? actorId;
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
    this.actorId,
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
      actorId: actorId,
      timestamp: timestamp,
    );
  }

  factory KitaNotification.fromJson(Map<String, dynamic> json) {
    final rawType = json['type'] as String? ?? 'info';
    final rawStatus = json['status'] as String? ?? 'pending';

    final KitaNotificationType type;
    switch (rawType) {
      case 'rematch':
        type = KitaNotificationType.rematch;
        break;
      case 'challenge':
        type = KitaNotificationType.challenge;
        break;
      case 'friend_request':
        type = KitaNotificationType.friendRequest;
        break;
      default:
        type = KitaNotificationType.info;
        break;
    }

    final NotificationStatus status;
    switch (rawStatus) {
      case 'accepted':
        status = NotificationStatus.accepted;
        break;
      case 'declined':
        status = NotificationStatus.declined;
        break;
      case 'ignored':
        status = NotificationStatus.ignored;
        break;
      case 'read':
        status = NotificationStatus.read;
        break;
      case 'pending':
      case 'unread':
      default:
        status = NotificationStatus.pending;
        break;
    }

    // Parse payload if present
    Map<String, dynamic> payloadMap = {};
    final rawPayload = json['payload'];
    if (rawPayload is Map<String, dynamic>) {
      payloadMap = rawPayload;
    } else if (rawPayload is String && rawPayload.isNotEmpty) {
      try {
        payloadMap = Map<String, dynamic>.from(
          (rawPayload.startsWith('{') ? (jsonDecodeString(rawPayload) ?? {}) : {}) as Map,
        );
      } catch (_) {}
    }

    final String? friendshipId = payloadMap['friendship_id']?.toString() ?? json['friendship_id']?.toString();
    final String? inviteId = payloadMap['invite_id']?.toString() ?? json['invite_id']?.toString();
    final String? matchId = payloadMap['match_id']?.toString() ?? json['match_id']?.toString();
    final String? senderName = json['actor_name']?.toString() ??
        payloadMap['username']?.toString() ??
        payloadMap['sender_name']?.toString() ??
        payloadMap['decliner_name']?.toString() ??
        payloadMap['accepter_name']?.toString() ??
        json['sender_name']?.toString();

    final int? senderRating = (payloadMap['rating'] as num?)?.toInt() ??
        (payloadMap['sender_rating'] as num?)?.toInt() ??
        (json['sender_rating'] as num?)?.toInt();

    final int? timeControl = (payloadMap['time_control'] as num?)?.toInt() ??
        (json['time_control'] as num?)?.toInt();

    final String? colorPreference = payloadMap['color_preference']?.toString() ??
        json['color_preference']?.toString();

    final String? actorId = json['actor_id']?.toString() ??
        payloadMap['actor_id']?.toString() ??
        payloadMap['inviter_id']?.toString();

    final createdAtStr = json['created_at']?.toString() ?? '';
    final timestamp = DateTime.tryParse(createdAtStr) ?? DateTime.now();

    return KitaNotification(
      id: json['id']?.toString() ?? '',
      type: type,
      status: status,
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      senderName: senderName,
      senderRating: senderRating,
      timeControl: timeControl,
      colorPreference: colorPreference,
      matchId: matchId,
      inviteId: inviteId,
      friendshipId: friendshipId,
      actorId: actorId,
      timestamp: timestamp,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'status': status.name,
      'title': title,
      'subtitle': subtitle,
      'sender_name': senderName,
      'sender_rating': senderRating,
      'time_control': timeControl,
      'color_preference': colorPreference,
      'match_id': matchId,
      'invite_id': inviteId,
      'friendship_id': friendshipId,
      'created_at': timestamp.toIso8601String(),
    };
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

dynamic jsonDecodeString(String s) {
  try {
    return s.isEmpty ? null : jsonDecode(s);
  } catch (_) {
    return null;
  }
}
