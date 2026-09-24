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
  /// If [isGuest] is true, the match is tagged as a guest match so it can
  /// be wiped cleanly when the guest logs off or quits.
  Future<void> saveMatch(
    MatchRecordModel match, {
    required bool isGuest,
    String? userId,
  }) async {
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
        'is_guest': isGuest,
        'user_id': userId,
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
  /// If [isGuest] is true, returns matches tagged as guest.
  /// If [isGuest] is false, returns matches associated with [userId] or not tagged as guest.
  Future<List<MatchRecordModel>> getMatches({
    String? userId,
    bool isGuest = false,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyMatches);
      if (raw == null || raw.isEmpty) return [];

      final list = jsonDecode(raw) as List<dynamic>;
      final results = <MatchRecordModel>[];

      for (final item in list) {
        if (item is! Map<String, dynamic>) continue;
        final itemIsGuest = item['is_guest'] == true;
        final itemUserId = item['user_id'] as String?;

        if (isGuest) {
          if (!itemIsGuest) continue;
        } else {
          if (itemIsGuest) continue;
          if (userId != null && itemUserId != null && itemUserId != userId) {
            continue;
          }
        }

        final matchMap = item['match'] as Map<String, dynamic>?;
        if (matchMap != null) {
          results.add(MatchRecordModel.fromJson(matchMap));
        }
      }

      return results;
    } catch (e) {
      debugPrint('[LocalMatchHistoryService] Error getting matches: $e');
      return [];
    }
  }

  /// Deletes all offline matches that were played while in guest mode.
  /// Called when a guest logs off, quits, or switches account.
  Future<void> clearGuestMatches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyMatches);
      if (raw == null || raw.isEmpty) return;

      final list = jsonDecode(raw) as List<dynamic>;
      final retained = list.where((item) {
        if (item is! Map<String, dynamic>) return false;
        return item['is_guest'] != true;
      }).toList();

      await prefs.setString(_keyMatches, jsonEncode(retained));
    } catch (e) {
      debugPrint('[LocalMatchHistoryService] Error clearing guest matches: $e');
    }
  }

  /// Clears all offline matches stored on the device.
  Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyMatches);
    } catch (e) {
      debugPrint('[LocalMatchHistoryService] Error clearing all matches: $e');
    }
  }

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
}
