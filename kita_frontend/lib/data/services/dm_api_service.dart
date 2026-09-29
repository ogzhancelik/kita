import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../models/dm_models.dart';


class DmApiService {
  final ApiClient _client;

  DmApiService([ApiClient? client]) : _client = client ?? ApiClient();

  /// Returns the last message preview for each conversation the current user participates in.
  Future<List<DmMessage>> getConversationPreviews() async {
    final response = await _client.dio.get(
      ApiConstants.dmConversations,
      options: Options(extra: {'silent': true}),
    );
    final data = response.data as Map<String, dynamic>;
    final list = data['conversations'] as List<dynamic>? ?? [];
    return list
        .map((e) => DmMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Returns paginated message history for a conversation.
  Future<List<DmMessage>> getHistory(
    String conversationId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _client.dio.get(
      ApiConstants.dmConversationHistory(conversationId),
      queryParameters: {'limit': limit, 'offset': offset},
      options: Options(extra: {'silent': true}),
    );
    final data = response.data as Map<String, dynamic>;
    final list = data['messages'] as List<dynamic>? ?? [];
    return list
        .map((e) => DmMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Returns matches that user played against [friendId], used to build
  /// MatchChatCards in the DM conversation timeline.
  Future<List<MatchChatCard>> fetchSharedMatches(
    String myUserId,
    String friendId,
  ) async {
    // Fetch my recent matches and filter by opponent.
    final response = await _client.dio.get(
      ApiConstants.userMatches(myUserId),
      queryParameters: {'limit': 50},
      options: Options(extra: {'silent': true}),
    );
    final data = response.data as Map<String, dynamic>;
    final list = (data['matches'] as List<dynamic>? ?? []);
    return list
        .map((e) => MatchChatCard.fromJson(e as Map<String, dynamic>))
        .where((m) =>
            (m.whitePlayerId == myUserId || m.blackPlayerId == myUserId) &&
            (m.whitePlayerId == friendId || m.blackPlayerId == friendId))
        .toList();
  }

  /// Fetches the in-game chat messages for a specific match.
  Future<List<InGameMessage>> fetchMatchMessages(String matchId) async {
    final response = await _client.dio.get(
      ApiConstants.matchMessages(matchId),
      options: Options(extra: {'silent': true}),
    );
    final data = response.data as Map<String, dynamic>;
    final list = data['messages'] as List<dynamic>? ?? [];
    return list
        .map((e) => InGameMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
