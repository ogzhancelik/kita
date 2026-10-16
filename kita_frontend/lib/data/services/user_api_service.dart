import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../models/user_model.dart';

class UserApiService {
  final ApiClient _client;

  /// Global revision notifier to signal leaderboard changes across widgets and screens
  static final ValueNotifier<int> leaderboardRevision = ValueNotifier<int>(0);

  static void notifyLeaderboardChanged() {
    leaderboardRevision.value++;
  }

  UserApiService([ApiClient? client]) : _client = client ?? ApiClient();

  /// Fetches top players sorted by rating (ELO)
  Future<List<UserProfile>> getLeaderboard({
    int limit = 50,
    String filter = 'global',
    String? token,
  }) async {
    final authToken = (token != null && token.isNotEmpty) ? token : ApiClient.currentToken;

    final response = await _client.dio.get(
      ApiConstants.leaderboard,
      queryParameters: {
        'limit': limit,
        'filter': filter,
        if (authToken != null && authToken.isNotEmpty) 'token': authToken,
      },
      options: Options(
        extra: {'silent': true},
        headers: (authToken != null && authToken.isNotEmpty)
            ? {'Authorization': 'Bearer $authToken'}
            : null,
      ),
    );

    final data = response.data as Map<String, dynamic>;
    final list = data['leaderboard'] as List<dynamic>? ?? [];

    return list
        .map((item) => UserProfile.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Fetches public profile for a specific user ID
  Future<UserProfile> getUserProfile(String id) async {
    final response = await _client.dio.get(ApiConstants.userProfile(id));
    return UserProfile.fromJson(response.data as Map<String, dynamic>);
  }

  /// Updates authenticated user's avatar
  Future<UserProfile> updateAvatar(int avatarIndex, {String? avatarCustom}) async {
    final token = ApiClient.currentToken;

    final data = <String, dynamic>{
      'avatar_index': avatarIndex,
      'avatar_custom': ?avatarCustom,
    };

    final response = await _client.dio.put(
      ApiConstants.updateAvatar,
      data: data,
      options: (token != null && token.isNotEmpty)
          ? Options(headers: {'Authorization': 'Bearer $token'})
          : null,
    );

    return UserProfile.fromJson(response.data as Map<String, dynamic>);
  }

  /// Updates authenticated user's username
  Future<UserProfile> updateUsername(String username) async {
    final token = ApiClient.currentToken;

    final response = await _client.dio.put(
      ApiConstants.updateUsername,
      data: {'username': username.trim()},
      options: (token != null && token.isNotEmpty)
          ? Options(headers: {'Authorization': 'Bearer $token'})
          : null,
    );

    return UserProfile.fromJson(response.data as Map<String, dynamic>);
  }

  /// Permanently deletes authenticated user's account
  Future<void> deleteAccount({required String password}) async {
    final token = ApiClient.currentToken;

    await _client.dio.delete(
      ApiConstants.deleteAccount,
      data: {'password': password},
      options: (token != null && token.isNotEmpty)
          ? Options(headers: {'Authorization': 'Bearer $token'})
          : null,
    );
  }
}

