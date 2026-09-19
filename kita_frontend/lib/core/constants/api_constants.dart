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
      return 'http://localhost:8080';
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
  static String userProfile(String id) => '/api/users/profile/$id';

  // Matches & Replay
  static String userMatches(String userId) => '/api/matches/user/$userId';
  static String matchDetails(String matchId) => '/api/matches/$matchId';
  static String matchMoves(String matchId) => '/api/matches/$matchId/moves';

  // WebSocket
  static String get wsUrl {
    final uri = Uri.parse(baseUrl);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    return '$scheme://${uri.host}:${uri.port}/ws';
  }
}
