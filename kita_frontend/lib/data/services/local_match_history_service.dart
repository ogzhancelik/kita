import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/match_model.dart';

/// Local service responsible for persisting and managing offline games
/// (such as "Play vs Computer") in device storage.
class LocalMatchHistoryService {
  LocalMatchHistoryService._();
  static final LocalMatchHistoryService instance = LocalMatchHistoryService._();

  static const String _keyMatches = 'kita_offline_matches_v1';
  static const String _keyShowOffline = 'kita_show_offline_matches';
  static const int _maxStoredMatches = 50;

  /// Saves an offline match to local device storage.
  /// Offline matches are device-based, persisting on the local device.
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
      final raw = prefs.getString(_keyMatches);

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

      // Insert at the front (most recent first)
      list.insert(0, entry);

      // Limit storage size
      if (list.length > _maxStoredMatches) {
        list = list.sublist(0, _maxStoredMatches);
      }

      await prefs.setString(_keyMatches, jsonEncode(list));
    } catch (e) {
      debugPrint('[LocalMatchHistoryService] Error saving match: $e');
    }
  }

  /// Retrieves offline matches from local storage.
  /// Offline matches are device-based rather than account-based.
  Future<List<MatchRecordModel>> getMatches({
    String? userId,
    bool? isGuest,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyMatches);
      if (raw == null || raw.isEmpty) return [];

      final list = jsonDecode(raw) as List<dynamic>;
      final results = <MatchRecordModel>[];

      for (final item in list) {
        if (item is! Map<String, dynamic>) continue;
        final matchMap = (item['match'] as Map<String, dynamic>?) ?? item;
        try {
          final parsed = MatchRecordModel.fromJson(matchMap);
          final count = parsed.totalMoves > 0 ? parsed.totalMoves : parsed.moves.length;
          if (count > 1) {
            results.add(parsed);
          }
        } catch (e) {
          debugPrint('[LocalMatchHistoryService] Error parsing match: $e');
        }
      }

      return results;
    } catch (e) {
      debugPrint('[LocalMatchHistoryService] Error getting matches: $e');
      return [];
    }
  }

  /// Deletes offline match records from the device.
  /// Called when a guest logs out.
  Future<void> clearOfflineMatches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyMatches);
    } catch (e) {
      debugPrint('[LocalMatchHistoryService] Error clearing offline matches: $e');
    }
  }

  /// Alias for [clearOfflineMatches] for backward compatibility.
  Future<void> clearGuestMatches() => clearOfflineMatches();

  /// Clears all offline matches stored on the device.
  Future<void> clearAll() => clearOfflineMatches();

  /// Gets the user's toggle setting for showing/hiding offline games in match history.
  /// Defaults to true.
  Future<bool> getShowOfflineMatches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyShowOffline) ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Persists the user's toggle setting for showing/hiding offline games in match history.
  Future<void> setShowOfflineMatches(bool show) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyShowOffline, show);
    } catch (e) {
      debugPrint('[LocalMatchHistoryService] Error saving showOfflineMatches preference: $e');
    }
  }

  // ─── Active Offline Match Persistence ──────────────────────────────
  static const String _keyActiveOfflineGame = 'kita_active_offline_game_v1';

  /// Saves an active, in-progress offline game to SharedPreferences.
  Future<void> saveActiveOfflineGame(ActiveOfflineGameData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyActiveOfflineGame, jsonEncode(data.toJson()));
    } catch (e) {
      debugPrint('[LocalMatchHistoryService] Error saving active offline game: $e');
    }
  }

  /// Retrieves the active in-progress offline game from SharedPreferences, if any.
  Future<ActiveOfflineGameData?> getActiveOfflineGame() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyActiveOfflineGame);
      if (raw == null || raw.isEmpty) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return ActiveOfflineGameData.fromJson(map);
    } catch (e) {
      debugPrint('[LocalMatchHistoryService] Error reading active offline game: $e');
      return null;
    }
  }

  /// Clears the active offline game from SharedPreferences (on game over or resignation).
  Future<void> clearActiveOfflineGame() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyActiveOfflineGame);
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
  final bool isGuest;
  final int elapsedSeconds;
  final List<Map<String, dynamic>> moveHistory;
  final DateTime startedAt;

  const ActiveOfflineGameData({
    required this.matchId,
    required this.playMode,
    required this.botDifficulty,
    required this.playerTeam,
    this.playerId,
    this.playerName,
    this.playerRating,
    required this.isGuest,
    required this.elapsedSeconds,
    required this.moveHistory,
    required this.startedAt,
  });

  Map<String, dynamic> toJson() => {
    'matchId': matchId,
    'playMode': playMode,
    'botDifficulty': botDifficulty,
    'playerTeam': playerTeam,
    'playerId': playerId,
    'playerName': playerName,
    'playerRating': playerRating,
    'isGuest': isGuest,
    'elapsedSeconds': elapsedSeconds,
    'moveHistory': moveHistory,
    'startedAt': startedAt.toIso8601String(),
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
        isGuest: json['isGuest'] as bool? ?? false,
        elapsedSeconds: (json['elapsedSeconds'] as num?)?.toInt() ?? 0,
        moveHistory: (json['moveHistory'] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [],
        startedAt: json['startedAt'] != null
            ? DateTime.tryParse(json['startedAt'] as String) ?? DateTime.now()
            : DateTime.now(),
      );
}
