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
          results.add(MatchRecordModel.fromJson(matchMap));
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
}
