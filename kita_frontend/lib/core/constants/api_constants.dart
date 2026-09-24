import 'package:flutter/foundation.dart';

class ApiConstants {
  ApiConstants._();

  static const String _envApiUrl = String.fromEnvironment('API_URL');

  // For Android emulator vs Web/Desktop/Physical device
  static String get defaultBaseUrl {
    if (_envApiUrl.isNotEmpty) {
      return _envApiUrl;
    }
    if (kIsWeb) {
      final host = Uri.base.host.isNotEmpty ? Uri.base.host : 'localhost';
      final scheme = Uri.base.scheme == 'https' ? 'https' : 'http';
      return '$scheme://$host:8080';
    }
    // For mobile or desktop testing (10.0.2.2 is Android emulator host loopback)
    return defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:8080'
        : 'http://localhost:8080';
  }

  static String baseUrl = defaultBaseUrl;

  // Auth endpoints
  static const String register = '/api/auth/register';
  static const String login = '/api/auth/login';
  static const String me = '/api/auth/me';

  // User & Stats
  static const String leaderboard = '/api/users/leaderboard';
  static const String updateAvatar = '/api/users/me/avatar';
  static String userProfile(String id) => '/api/users/profile/$id';

  // Matches & Replay
  static String userMatches(String userId) => '/api/matches/user/$userId';
  static String matchDetails(String matchId) => '/api/matches/$matchId';
  static String matchMoves(String matchId) => '/api/matches/$matchId/moves';

  // Friends
  static const String friends = '/api/friends';
  static const String friendRequests = '/api/friends/requests';
  static const String sendFriendRequest = '/api/friends/request';
  static String acceptFriendRequest(String id) => '/api/friends/$id/accept';
  static String declineFriendRequest(String id) => '/api/friends/$id/decline';
  static String removeFriend(String id) => '/api/friends/$id';

  // Notifications
  static const String notifications = '/api/notifications';
  static String notificationStatus(String id) => '/api/notifications/$id/status';
  static const String markAllNotificationsRead = '/api/notifications/mark-all-read';
  static String deleteNotification(String id) => '/api/notifications/$id';

  // WebSocket
  static String get wsUrl {
    final uri = Uri.parse(baseUrl);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    final portPart = (uri.hasPort && uri.port != 80 && uri.port != 443) ? ':${uri.port}' : '';
    return '$scheme://${uri.host}$portPart/ws';
  }
}
