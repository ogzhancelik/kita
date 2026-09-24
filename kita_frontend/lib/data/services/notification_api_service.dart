import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../models/notification_model.dart';

class NotificationFetchResult {
  final List<KitaNotification> notifications;
  final int unreadCount;

  const NotificationFetchResult({
    required this.notifications,
    required this.unreadCount,
  });
}

class NotificationApiService {
  final ApiClient _client;

  NotificationApiService([ApiClient? client]) : _client = client ?? ApiClient();

  /// Fetches persistent notifications and unread badge count from the backend.
  Future<NotificationFetchResult> fetchNotifications({
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _client.dio.get(
      ApiConstants.notifications,
      queryParameters: {
        'limit': limit,
        'offset': offset,
      },
    );

    final data = response.data as Map<String, dynamic>;
    final rawList = data['notifications'] as List<dynamic>? ?? [];
    final unreadCount = (data['unread_count'] as num?)?.toInt() ?? 0;

    final notifications = rawList
        .map((item) => KitaNotification.fromJson(item as Map<String, dynamic>))
        .toList();

    return NotificationFetchResult(
      notifications: notifications,
      unreadCount: unreadCount,
    );
  }

  /// Updates the status of a notification (read, accepted, declined, ignored).
  Future<void> updateStatus(String id, NotificationStatus status) async {
    await _client.dio.patch(
      ApiConstants.notificationStatus(id),
      data: {'status': status.name},
      options: Options(extra: {'silent': true}),
    );
  }

  /// Marks all informational notifications as read.
  Future<void> markAllAsRead() async {
    await _client.dio.post(
      ApiConstants.markAllNotificationsRead,
      options: Options(extra: {'silent': true}),
    );
  }

  /// Deletes a notification.
  Future<void> deleteNotification(String id) async {
    await _client.dio.delete(
      ApiConstants.deleteNotification(id),
      options: Options(extra: {'silent': true}),
    );
  }
}
