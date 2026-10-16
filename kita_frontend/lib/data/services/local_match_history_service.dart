import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/storage/secure_storage_service.dart';
import '../models/match_model.dart';

import 'user_api_service.dart';

/// Local service responsible for persisting and managing offline games
/// (such as "Play vs Computer") in account-scoped device storage.
class LocalMatchHistoryService {
  LocalMatchHistoryService._();
  static final LocalMatchHistoryService instance = LocalMatchHistoryService._();

  static const String _legacyKeyMatches = 'kita_offline_matches_v1';
  static const String _keyMatchesPrefix = 'kita_offline_matches_v1_user_';
  static const String _guestKeyMatches = 'kita_offline_matches_v1_guest';

  static const String _legacyKeyShowOffline = 'kita_show_offline_matches';
  static const String _keyShowOfflinePrefix = 'kita_show_offline_matches_user_';
  static const String _guestKeyShowOffline = 'kita_show_offline_matches_guest';

  static const String _legacyKeyActiveOfflineGame = 'kita_active_offline_game_v1';
  static const String _keyActiveOfflineGamePrefix = 'kita_active_offline_game_v1_user_';
  static const String _guestKeyActiveOfflineGame = 'kita_active_offline_game_v1_guest';

  static const int _maxStoredMatches = 5000;

  /// ValueNotifier that increments on any match changes (saving, clearing, visibility toggle, or game over).
  final ValueNotifier<int> matchHistoryRevision = ValueNotifier<int>(0);

  /// Notifies listeners that match history has been updated.
  void notifyMatchesChanged() {
    matchHistoryRevision.value++;
    UserApiService.notifyLeaderboardChanged();
  }

  /// Resolves the SharedPreferences key for offline match list scoped to account or guest.
  Future<String> _resolveMatchesKey({
    String? userId,
    bool? isGuest,
    MatchRecordModel? match,
  }) async {
    if (isGuest == true) {
      return _guestKeyMatches;
    }
    if (userId != null &&
        userId.isNotEmpty &&
        userId != 'guest' &&
        userId != 'local_player') {
      return '$_keyMatchesPrefix$userId';
    }
    // Check match for explicit player ID
    if (match != null) {
      final w = match.whitePlayerId;
      final b = match.blackPlayerId;
      if (w.isNotEmpty &&
          w != 'bot' &&
          w != 'guest' &&
          w != 'local_player' &&
          w != 'local_white' &&
          w != 'local_black') {
        return '$_keyMatchesPrefix$w';
      }
      if (b.isNotEmpty &&
          b != 'bot' &&
          b != 'guest' &&
          b != 'local_player' &&
          b != 'local_white' &&
          b != 'local_black') {
        return '$_keyMatchesPrefix$b';
      }
    }
    // Fallback to checking SecureStorageService cached user
    try {
      final user = await SecureStorageService().getUser();
      if (user != null && user.id.isNotEmpty && user.id != 'guest') {
        return '$_keyMatchesPrefix${user.id}';
      }
    } catch (_) {}

    // If neither explicit userId nor guest was specified and no user in storage, check prefs
    if (userId == null && isGuest == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        if (!prefs.containsKey(_guestKeyMatches)) {
          final accountKeys = prefs.getKeys().where((k) => k.startsWith(_keyMatchesPrefix)).toList();
          if (accountKeys.length == 1) {
            return accountKeys.first;
          }
        }
      } catch (_) {}
    }

    return _guestKeyMatches;
  }

  /// Resolves the SharedPreferences key for the show-offline preference scoped to account.
  Future<String> _resolveShowOfflineKey({
    String? userId,
    bool? isGuest,
  }) async {
    if (isGuest == true) {
      return _guestKeyShowOffline;
    }
    if (userId != null &&
        userId.isNotEmpty &&
        userId != 'guest' &&
        userId != 'local_player') {
      return '$_keyShowOfflinePrefix$userId';
    }
    try {
      final user = await SecureStorageService().getUser();
      if (user != null && user.id.isNotEmpty && user.id != 'guest') {
        return '$_keyShowOfflinePrefix${user.id}';
      }
    } catch (_) {}
    return _guestKeyShowOffline;
  }

  /// Resolves the SharedPreferences key for active in-progress match scoped to account.
  Future<String> _resolveActiveGameKey({
    String? userId,
    bool? isGuest,
  }) async {
    if (isGuest == true) {
      return _guestKeyActiveOfflineGame;
    }
    if (userId != null &&
        userId.isNotEmpty &&
        userId != 'guest' &&
        userId != 'local_player') {
      return '$_keyActiveOfflineGamePrefix$userId';
    }
    try {
      final user = await SecureStorageService().getUser();
      if (user != null && user.id.isNotEmpty && user.id != 'guest') {
        return '$_keyActiveOfflineGamePrefix${user.id}';
      }
    } catch (_) {}
    return _guestKeyActiveOfflineGame;
  }

  /// Migrates any legacy global offline matches into account-scoped keys.
  Future<void> _checkAndMigrateLegacyData(SharedPreferences prefs) async {
    final rawLegacy = prefs.getString(_legacyKeyMatches);
    if (rawLegacy == null || rawLegacy.isEmpty) return;

    try {
      final list = jsonDecode(rawLegacy) as List<dynamic>;
      if (list.isEmpty) {
        await prefs.remove(_legacyKeyMatches);
        return;
      }

      final Map<String, List<dynamic>> grouped = {};

      for (final item in list) {
        if (item is! Map<String, dynamic>) continue;
        final matchMap = (item['match'] as Map<String, dynamic>?) ?? item;
        final whiteId = matchMap['white_player_id'] as String? ?? matchMap['whitePlayerId'] as String?;
        final blackId = matchMap['black_player_id'] as String? ?? matchMap['blackPlayerId'] as String?;

        String? inferredUser;
        if (whiteId != null &&
            whiteId.isNotEmpty &&
            whiteId != 'bot' &&
            whiteId != 'guest' &&
            whiteId != 'local_player' &&
            whiteId != 'local_white' &&
            whiteId != 'local_black') {
          inferredUser = whiteId;
        } else if (blackId != null &&
            blackId.isNotEmpty &&
            blackId != 'bot' &&
            blackId != 'guest' &&
            blackId != 'local_player' &&
            blackId != 'local_white' &&
            blackId != 'local_black') {
          inferredUser = blackId;
        }

        final targetKey = inferredUser != null
            ? '$_keyMatchesPrefix$inferredUser'
            : _guestKeyMatches;

        grouped.putIfAbsent(targetKey, () => []).add(item);
      }

      for (final entry in grouped.entries) {
        final targetKey = entry.key;
        final legacyItems = entry.value;

        final existingRaw = prefs.getString(targetKey);
        List<dynamic> existingList = [];
        if (existingRaw != null && existingRaw.isNotEmpty) {
          try {
            existingList = jsonDecode(existingRaw) as List<dynamic>;
          } catch (_) {}
        }

        final existingIds = existingList
            .whereType<Map<String, dynamic>>()
            .map((e) => e['id'])
            .whereType<String>()
            .toSet();

        for (final item in legacyItems) {
          final id = item['id'];
          if (id is String && !existingIds.contains(id)) {
            existingList.add(item);
            existingIds.add(id);
          }
        }

        if (existingList.length > _maxStoredMatches) {
          existingList = existingList.sublist(0, _maxStoredMatches);
        }

        await prefs.setString(targetKey, jsonEncode(existingList));
      }

      await prefs.remove(_legacyKeyMatches);
      debugPrint('[LocalMatchHistoryService] Migrated legacy offline matches into account-scoped storage.');
    } catch (e) {
      debugPrint('[LocalMatchHistoryService] Migration error: $e');
    }
  }

  /// Saves an offline match to local device storage, scoped by account ID.
  Future<void> saveMatch(
    MatchRecordModel match, {
    bool? isGuest,
    String? userId,
  }) async {
    final moveCount = match.totalMoves > 0 ? match.totalMoves : match.moves.length;
    if (moveCount <= 1) {
      debugPrint('[LocalMatchHistoryService] Skipping saving 0-move or 1-move match: ${match.id}');
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await _checkAndMigrateLegacyData(prefs);

      final key = await _resolveMatchesKey(
        userId: userId,
        isGuest: isGuest,
        match: match,
      );

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
        'saved_at': DateTime.now().toIso8601String(),
        'match': match.toJson(),
      };

      // If a match with this ID already exists, update it in place instead of duplicating
      final existingIndex = list.indexWhere((item) =>
          item is Map && item['id'] == match.id);

      if (existingIndex >= 0) {
        list[existingIndex] = entry;
      } else {
        // Insert at the front (most recent first)
        list.insert(0, entry);
      }

      // Limit storage size
      if (list.length > _maxStoredMatches) {
        list = list.sublist(0, _maxStoredMatches);
      }

      await prefs.setString(key, jsonEncode(list));
      notifyMatchesChanged();
    } catch (e) {
      debugPrint('[LocalMatchHistoryService] Error saving match: $e');
    }
  }

  /// Retrieves offline matches from local storage scoped by account ID.
  Future<List<MatchRecordModel>> getMatches({
    String? userId,
    bool? isGuest,
    int? limit,
    int? offset,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _checkAndMigrateLegacyData(prefs);

      final List<String> targetKeys = [];
      if (userId == null && isGuest == null) {
        final allKeys = prefs.getKeys().where((k) =>
            k.startsWith(_keyMatchesPrefix) ||
            k == _guestKeyMatches ||
            k == _legacyKeyMatches).toList();
        targetKeys.addAll(allKeys);
      } else {
        final key = await _resolveMatchesKey(userId: userId, isGuest: isGuest);
        targetKeys.add(key);
      }

      final results = <MatchRecordModel>[];
      final seenIds = <String>{};

      for (final key in targetKeys) {
        final raw = prefs.getString(key);
        if (raw == null || raw.isEmpty) continue;

        try {
          final list = jsonDecode(raw) as List<dynamic>;
          for (final item in list) {
            if (item is! Map<String, dynamic>) continue;
            final matchMap = (item['match'] as Map<String, dynamic>?) ?? item;
            try {
              final parsed = MatchRecordModel.fromJson(matchMap);
              if (seenIds.add(parsed.id)) {
                final count = parsed.totalMoves > 0 ? parsed.totalMoves : parsed.moves.length;
                if (count > 1) {
                  results.add(parsed);
                }
              }
            } catch (e) {
              debugPrint('[LocalMatchHistoryService] Error parsing match: $e');
            }
          }
        } catch (_) {}
      }

      results.sort((a, b) => b.startedAt.compareTo(a.startedAt));

      var filtered = results;
      if (offset != null && offset > 0) {
        if (offset >= filtered.length) {
          return [];
        }
        filtered = filtered.sublist(offset);
      }
      if (limit != null && limit > 0 && filtered.length > limit) {
        filtered = filtered.sublist(0, limit);
      }

      return filtered;
    } catch (e) {
      debugPrint('[LocalMatchHistoryService] Error getting matches: $e');
      return [];
    }
  }

  /// Deletes offline match records from the device for the specified account or guest.
  Future<void> clearOfflineMatches({
    String? userId,
    bool? isGuest,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (userId == null && isGuest == null) {
        await clearAllAccounts();
        return;
      }
      final key = await _resolveMatchesKey(userId: userId, isGuest: isGuest);
      await prefs.remove(key);
      notifyMatchesChanged();
    } catch (e) {
      debugPrint('[LocalMatchHistoryService] Error clearing offline matches: $e');
    }
  }

  /// Clears offline matches for all accounts stored on this device.
  Future<void> clearAllAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) =>
        k.startsWith(_keyMatchesPrefix) ||
        k == _guestKeyMatches ||
        k == _legacyKeyMatches
      ).toList();
      for (final key in keys) {
        await prefs.remove(key);
      }
      notifyMatchesChanged();
    } catch (e) {
      debugPrint('[LocalMatchHistoryService] Error clearing all offline matches: $e');
    }
  }

  /// Alias for [clearOfflineMatches] for guest matches.
  Future<void> clearGuestMatches() => clearOfflineMatches(isGuest: true);

  /// Clears matches for the specified or current account.
  Future<void> clearAll({String? userId, bool? isGuest}) =>
      clearOfflineMatches(userId: userId, isGuest: isGuest);

  /// Gets the user's toggle setting for showing/hiding offline games in match history.
  /// Defaults to true.
  Future<bool> getShowOfflineMatches({
    String? userId,
    bool? isGuest,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _resolveShowOfflineKey(userId: userId, isGuest: isGuest);
      if (prefs.containsKey(key)) {
        return prefs.getBool(key) ?? true;
      }
      if (prefs.containsKey(_legacyKeyShowOffline)) {
        final legacyVal = prefs.getBool(_legacyKeyShowOffline) ?? true;
        await prefs.setBool(key, legacyVal);
        return legacyVal;
      }
      return true;
    } catch (_) {
      return true;
    }
  }

  /// Persists the user's toggle setting for showing/hiding offline games in match history.
  Future<void> setShowOfflineMatches(
    bool show, {
    String? userId,
    bool? isGuest,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _resolveShowOfflineKey(userId: userId, isGuest: isGuest);
      await prefs.setBool(key, show);
      notifyMatchesChanged();
    } catch (e) {
      debugPrint('[LocalMatchHistoryService] Error saving showOfflineMatches preference: $e');
    }
  }

  // ─── Active Offline Match Persistence ──────────────────────────────

  /// Saves an active, in-progress offline game to SharedPreferences, scoped to account.
  Future<void> saveActiveOfflineGame(
    ActiveOfflineGameData data, {
    String? userId,
    bool? isGuest,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _resolveActiveGameKey(
        userId: userId ?? data.playerId,
        isGuest: isGuest ?? data.isGuest,
      );
      await prefs.setString(key, jsonEncode(data.toJson()));
    } catch (e) {
      debugPrint('[LocalMatchHistoryService] Error saving active offline game: $e');
    }
  }

  /// Retrieves the active in-progress offline game from SharedPreferences for account, if any.
  Future<ActiveOfflineGameData?> getActiveOfflineGame({
    String? userId,
    bool? isGuest,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _resolveActiveGameKey(userId: userId, isGuest: isGuest);
      final raw = prefs.getString(key);
      if (raw != null && raw.isNotEmpty) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        return ActiveOfflineGameData.fromJson(map);
      }

      // Check legacy active match key if scoped is empty
      final legacyRaw = prefs.getString(_legacyKeyActiveOfflineGame);
      if (legacyRaw != null && legacyRaw.isNotEmpty) {
        final map = jsonDecode(legacyRaw) as Map<String, dynamic>;
        final data = ActiveOfflineGameData.fromJson(map);
        final matches = (isGuest == true && data.isGuest) ||
            (userId != null && data.playerId == userId);
        if (matches) {
          await prefs.remove(_legacyKeyActiveOfflineGame);
          await saveActiveOfflineGame(data, userId: userId, isGuest: isGuest);
          return data;
        }
      }
      return null;
    } catch (e) {
      debugPrint('[LocalMatchHistoryService] Error reading active offline game: $e');
      return null;
    }
  }

  /// Clears the active offline game from SharedPreferences (on game over or resignation).
  Future<void> clearActiveOfflineGame({
    String? userId,
    bool? isGuest,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _resolveActiveGameKey(userId: userId, isGuest: isGuest);
      await prefs.remove(key);
      if (prefs.containsKey(_legacyKeyActiveOfflineGame)) {
        await prefs.remove(_legacyKeyActiveOfflineGame);
      }
    } catch (e) {
      debugPrint('[LocalMatchHistoryService] Error clearing active offline game: $e');
    }
  }
}

/// Data class representing an active in-progress offline match for local storage persistence.
class ActiveOfflineGameData {
  final String matchId;
  final String playMode; // "vsAi" or "localCoop"
  final int botDifficulty;
  final String playerTeam; // "white" or "black"
  final String? playerId;
  final String? playerName;
  final int? playerRating;
  final int? playerAvatarIndex;
  final bool isGuest;
  final String? opponentName;
  final int? opponentAvatarIndex;
  final int elapsedSeconds;
  final List<Map<String, dynamic>> moveHistory;
  final DateTime startedAt;

  final int timeControl;
  final int whiteRemainingMs;
  final int blackRemainingMs;

  const ActiveOfflineGameData({
    required this.matchId,
    required this.playMode,
    required this.botDifficulty,
    required this.playerTeam,
    this.playerId,
    this.playerName,
    this.playerRating,
    this.playerAvatarIndex,
    required this.isGuest,
    this.opponentName,
    this.opponentAvatarIndex,
    required this.elapsedSeconds,
    required this.moveHistory,
    required this.startedAt,
    this.timeControl = 0,
    this.whiteRemainingMs = 0,
    this.blackRemainingMs = 0,
  });

  Map<String, dynamic> toJson() => {
    'matchId': matchId,
    'playMode': playMode,
    'botDifficulty': botDifficulty,
    'playerTeam': playerTeam,
    'playerId': playerId,
    'playerName': playerName,
    'playerRating': playerRating,
    'playerAvatarIndex': playerAvatarIndex,
    'isGuest': isGuest,
    'opponentName': opponentName,
    'opponentAvatarIndex': opponentAvatarIndex,
    'elapsedSeconds': elapsedSeconds,
    'moveHistory': moveHistory,
    'startedAt': startedAt.toIso8601String(),
    'timeControl': timeControl,
    'whiteRemainingMs': whiteRemainingMs,
    'blackRemainingMs': blackRemainingMs,
  };

  factory ActiveOfflineGameData.fromJson(Map<String, dynamic> json) =>
      ActiveOfflineGameData(
        matchId: json['matchId'] as String,
        playMode: json['playMode'] as String? ?? 'vsAi',
        botDifficulty: (json['botDifficulty'] as num?)?.toInt() ?? 1,
        playerTeam: json['playerTeam'] as String? ?? 'white',
        playerId: json['playerId'] as String?,
        playerName: json['playerName'] as String?,
        playerRating: (json['playerRating'] as num?)?.toInt(),
        playerAvatarIndex: (json['playerAvatarIndex'] as num?)?.toInt(),
        isGuest: json['isGuest'] as bool? ?? false,
        opponentName: json['opponentName'] as String?,
        opponentAvatarIndex: (json['opponentAvatarIndex'] as num?)?.toInt(),
        elapsedSeconds: (json['elapsedSeconds'] as num?)?.toInt() ?? 0,
        moveHistory: (json['moveHistory'] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [],
        startedAt: json['startedAt'] != null
            ? DateTime.tryParse(json['startedAt'] as String) ?? DateTime.now()
            : DateTime.now(),
        timeControl: (json['timeControl'] as num?)?.toInt() ?? 0,
        whiteRemainingMs: (json['whiteRemainingMs'] as num?)?.toInt() ?? 0,
        blackRemainingMs: (json['blackRemainingMs'] as num?)?.toInt() ?? 0,
      );
}
