import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../models/match_model.dart';

class UserMatchesResult {
  final List<MatchRecordModel> matches;
  final int totalCount;

  const UserMatchesResult({
    required this.matches,
    required this.totalCount,
  });
}

class MatchApiService {
  final ApiClient _client;

  MatchApiService([ApiClient? client]) : _client = client ?? ApiClient();

  /// Fetches matches played by a user with the server total count
  Future<UserMatchesResult> getUserMatchesWithTotal(
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
    final total = (data['total'] as num?)?.toInt() ??
        (data['count'] as num?)?.toInt() ??
        list.length;

    final matches = list
        .map((item) => MatchRecordModel.fromJson(item as Map<String, dynamic>))
        .toList();

    return UserMatchesResult(
      matches: matches,
      totalCount: total,
    );
  }

  /// Fetches matches played by a user
  Future<List<MatchRecordModel>> getUserMatches(
    String userId, {
    int limit = 20,
    int offset = 0,
  }) async {
    final result = await getUserMatchesWithTotal(userId, limit: limit, offset: offset);
    return result.matches;
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

  /// Uploads or resolves a match replay to obtain a shareable code and URL.
  Future<Map<String, dynamic>> shareReplay(MatchRecordModel match) async {
    final response = await _client.dio.post(
      ApiConstants.shareMatchReplay,
      data: {
        'match': match.toJson(),
      },
    );
    return response.data as Map<String, dynamic>;
  }
}
