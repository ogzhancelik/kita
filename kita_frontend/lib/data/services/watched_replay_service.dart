import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/storage/secure_storage_service.dart';
import '../models/match_model.dart';

/// Entry representing a watched replay and the timestamp when it was watched.
class WatchedMatchEntry {
  final MatchRecordModel match;
  final DateTime watchedAt;

  const WatchedMatchEntry({
    required this.match,
    required this.watchedAt,
  });
}

/// Local storage service that persists and manages external replays the user has watched
/// (e.g. loaded via code, .kita file, DM chat cards, or deep links), separate from
/// their own personal played match history.
class WatchedReplayService {
  WatchedReplayService._();
  static final WatchedReplayService instance = WatchedReplayService._();

  static const String _keyPrefix = 'kita_watched_replays_v1_user_';
  static const String _guestKey = 'kita_watched_replays_v1_guest';
  static const int _maxStored = 1000;

  /// ValueNotifier that increments whenever watched replays are added, deleted, or cleared.
  final ValueNotifier<int> watchedReplayRevision = ValueNotifier<int>(0);

  void notifyWatchedReplaysChanged() {
    watchedReplayRevision.value++;
  }

  Future<String> _resolveKey({String? userId, bool? isGuest}) async {
    if (isGuest == true) return _guestKey;
    if (userId != null &&
        userId.isNotEmpty &&
        userId != 'guest' &&
        userId != 'local_player') {
      return '$_keyPrefix$userId';
    }
    try {
      final user = await SecureStorageService().getUser();
      if (user != null && user.id.isNotEmpty && user.id != 'guest') {
        return '$_keyPrefix${user.id}';
      }
    } catch (_) {}
    return _guestKey;
  }

  /// Saves a watched match into local storage, scoping to current account or guest.
  /// If the match already exists in history, moves it to the top (most recently watched first).
  Future<void> saveWatchedReplay(
    MatchRecordModel match, {
    String? userId,
    bool? isGuest,
  }) async {
    final moveCount = match.totalMoves > 0 ? match.totalMoves : match.moves.length;
    if (moveCount < 1) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _resolveKey(userId: userId, isGuest: isGuest);
      final raw = prefs.getString(key);

      List<dynamic> list = [];
      if (raw != null && raw.isNotEmpty) {
        try {
          list = jsonDecode(raw) as List<dynamic>;
        } catch (_) {
          list = [];
        }
      }

      final entry = {
        'id': match.id,
        'watched_at': DateTime.now().toIso8601String(),
        'match': match.toJson(),
      };

      // Remove previous entry with this ID if already present
      list.removeWhere((item) => item is Map && item['id'] == match.id);

      // Insert at the front (most recent first)
      list.insert(0, entry);

      if (list.length > _maxStored) {
        list = list.sublist(0, _maxStored);
      }

      await prefs.setString(key, jsonEncode(list));
      notifyWatchedReplaysChanged();
    } catch (e) {
      debugPrint('[WatchedReplayService] Error saving watched replay: $e');
    }
  }

  /// Retrieves the list of watched match entries, ordered most recently watched first.
  Future<List<WatchedMatchEntry>> getWatchedEntries({
    String? userId,
    bool? isGuest,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _resolveKey(userId: userId, isGuest: isGuest);
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return [];

      final list = jsonDecode(raw) as List<dynamic>;
      final results = <WatchedMatchEntry>[];
      final seenIds = <String>{};

      for (final item in list) {
        if (item is! Map<String, dynamic>) continue;
        final matchMap = (item['match'] as Map<String, dynamic>?) ?? item;
        try {
          final parsed = MatchRecordModel.fromJson(matchMap);
          if (seenIds.add(parsed.id)) {
            final watchedAtStr = item['watched_at'] as String?;
            final watchedAt = (watchedAtStr != null && watchedAtStr.isNotEmpty)
                ? (DateTime.tryParse(watchedAtStr) ?? parsed.startedAt)
                : parsed.startedAt;
            results.add(WatchedMatchEntry(match: parsed, watchedAt: watchedAt));
          }
        } catch (e) {
          debugPrint('[WatchedReplayService] Error parsing watched match: $e');
        }
      }
      return results;
    } catch (e) {
      debugPrint('[WatchedReplayService] Error getting watched entries: $e');
      return [];
    }
  }

  /// Retrieves the list of watched matches, ordered most recently watched first.
  Future<List<MatchRecordModel>> getWatchedReplays({
    String? userId,
    bool? isGuest,
  }) async {
    final entries = await getWatchedEntries(userId: userId, isGuest: isGuest);
    return entries.map((e) => e.match).toList();
  }

  /// Deletes a specific match from the watched replays list.
  Future<void> deleteWatchedReplay(
    String matchId, {
    String? userId,
    bool? isGuest,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _resolveKey(userId: userId, isGuest: isGuest);
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return;

      final list = jsonDecode(raw) as List<dynamic>;
      list.removeWhere((item) => item is Map && item['id'] == matchId);

      await prefs.setString(key, jsonEncode(list));
      notifyWatchedReplaysChanged();
    } catch (e) {
      debugPrint('[WatchedReplayService] Error deleting watched replay: $e');
    }
  }

  /// Clears all watched replays for the current account/guest.
  Future<void> clearAllWatchedReplays({
    String? userId,
    bool? isGuest,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _resolveKey(userId: userId, isGuest: isGuest);
      await prefs.remove(key);
      notifyWatchedReplaysChanged();
    } catch (e) {
      debugPrint('[WatchedReplayService] Error clearing watched replays: $e');
    }
  }
}
