import 'package:flutter/material.dart';
import '../../core/storage/secure_storage_service.dart';

/// Provider for OS-level system push notification preferences.
/// These settings govern notifications delivered to the device notification tray
/// when the application is backgrounded or inactive. In-app notifications remain
/// permanently active and unaffected.
class OsNotificationProvider extends ChangeNotifier {
  final SecureStorageService _storage;

  static const String _keyChallenges = 'kita_os_notif_challenges';
  static const String _keyRematch = 'kita_os_notif_rematch';
  static const String _keyTurnMoves = 'kita_os_notif_turn_moves';
  static const String _keyFriendRequests = 'kita_os_notif_friends';
  static const String _keyChat = 'kita_os_notif_chat';
  static const String _keyNews = 'kita_os_notif_news';

  bool _challengesEnabled = true;
  bool _rematchEnabled = true;
  bool _turnMovesEnabled = true;
  bool _friendRequestsEnabled = true;
  bool _chatEnabled = true;
  bool _newsEnabled = true;

  bool get challengesEnabled => _challengesEnabled;
  bool get rematchEnabled => _rematchEnabled;
  bool get turnMovesEnabled => _turnMovesEnabled;
  bool get friendRequestsEnabled => _friendRequestsEnabled;
  bool get chatEnabled => _chatEnabled;
  bool get newsEnabled => _newsEnabled;

  OsNotificationProvider([SecureStorageService? storage])
      : _storage = storage ?? SecureStorageService() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final results = await Future.wait([
        _storage.readString(_keyChallenges),
        _storage.readString(_keyRematch),
        _storage.readString(_keyTurnMoves),
        _storage.readString(_keyFriendRequests),
        _storage.readString(_keyChat),
        _storage.readString(_keyNews),
      ]);
      if (results[0] != null) _challengesEnabled = results[0] == 'true';
      if (results[1] != null) _rematchEnabled = results[1] == 'true';
      if (results[2] != null) _turnMovesEnabled = results[2] == 'true';
      if (results[3] != null) _friendRequestsEnabled = results[3] == 'true';
      if (results[4] != null) _chatEnabled = results[4] == 'true';
      if (results[5] != null) _newsEnabled = results[5] == 'true';
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setChallengesEnabled(bool val) async {
    if (_challengesEnabled == val) return;
    _challengesEnabled = val;
    notifyListeners();
    await _storage.writeString(_keyChallenges, val.toString());
  }

  Future<void> setRematchEnabled(bool val) async {
    if (_rematchEnabled == val) return;
    _rematchEnabled = val;
    notifyListeners();
    await _storage.writeString(_keyRematch, val.toString());
  }

  Future<void> setTurnMovesEnabled(bool val) async {
    if (_turnMovesEnabled == val) return;
    _turnMovesEnabled = val;
    notifyListeners();
    await _storage.writeString(_keyTurnMoves, val.toString());
  }

  Future<void> setFriendRequestsEnabled(bool val) async {
    if (_friendRequestsEnabled == val) return;
    _friendRequestsEnabled = val;
    notifyListeners();
    await _storage.writeString(_keyFriendRequests, val.toString());
  }

  Future<void> setChatEnabled(bool val) async {
    if (_chatEnabled == val) return;
    _chatEnabled = val;
    notifyListeners();
    await _storage.writeString(_keyChat, val.toString());
  }

  Future<void> setNewsEnabled(bool val) async {
    if (_newsEnabled == val) return;
    _newsEnabled = val;
    notifyListeners();
    await _storage.writeString(_keyNews, val.toString());
  }
}
