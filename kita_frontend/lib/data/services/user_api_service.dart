import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/secure_storage_service.dart';
import '../models/user_model.dart';

class UserApiService {
  final ApiClient _client;

  UserApiService([ApiClient? client]) : _client = client ?? ApiClient();

  /// Fetches top players sorted by rating (ELO)
  Future<List<UserProfile>> getLeaderboard({
    int limit = 50,
    String filter = 'global',
    String? token,
  }) async {
    String? authToken = token;
    if (authToken == null || authToken.isEmpty) {
      authToken = ApiClient.currentToken;
    }
    if (authToken == null || authToken.isEmpty) {
      authToken = await SecureStorageService().getToken();
    }
    if (authToken != null && authToken.isNotEmpty) {
      ApiClient.currentToken = authToken;
    }

    final response = await _client.dio.get(
      ApiConstants.leaderboard,
      queryParameters: {
        'limit': limit,
        'filter': filter,
        if (authToken != null && authToken.isNotEmpty) 'token': authToken,
      },
      options: (authToken != null && authToken.isNotEmpty)
          ? Options(headers: {'Authorization': 'Bearer $authToken'})
          : null,
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
}
