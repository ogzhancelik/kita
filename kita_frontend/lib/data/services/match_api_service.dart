import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../models/match_model.dart';

class MatchApiService {
  final ApiClient _client;

  MatchApiService([ApiClient? client]) : _client = client ?? ApiClient();

  /// Fetches matches played by a user
  Future<List<MatchRecordModel>> getUserMatches(
    String userId, {
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _client.dio.get(
      ApiConstants.userMatches(userId),
      queryParameters: {
        'limit': limit,
        'offset': offset,
      },
    );

    final data = response.data as Map<String, dynamic>;
    final list = data['matches'] as List<dynamic>? ?? [];

    return list
        .map((item) => MatchRecordModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Fetches full match details with all recorded moves
  Future<MatchRecordModel> getMatchDetails(String matchId) async {
    final response = await _client.dio.get(ApiConstants.matchDetails(matchId));
    return MatchRecordModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Fetches just the moves list for a match
  Future<List<MoveRecordModel>> getMatchMoves(String matchId) async {
    final response = await _client.dio.get(ApiConstants.matchMoves(matchId));
    final data = response.data as Map<String, dynamic>;
    final list = data['moves'] as List<dynamic>? ?? [];

    return list
        .map((item) => MoveRecordModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
