import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../models/friend_models.dart';

class FriendApiService {
  final ApiClient _client;

  FriendApiService([ApiClient? client]) : _client = client ?? ApiClient();

  /// Fetches accepted friends
  Future<List<FriendItemModel>> getFriends() async {
    final response = await _client.dio.get(
      ApiConstants.friends,
      options: Options(extra: {'silent': true}),
    );
    final data = response.data as Map<String, dynamic>;
    final list = data['friends'] as List<dynamic>? ?? [];

    return list
        .map((item) => FriendItemModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Fetches pending friend requests (both incoming and outgoing)
  Future<List<FriendItemModel>> getPendingRequests() async {
    final response = await _client.dio.get(
      ApiConstants.friendRequests,
      options: Options(extra: {'silent': true}),
    );
    final data = response.data as Map<String, dynamic>;
    final list = data['requests'] as List<dynamic>? ?? [];

    return list
        .map((item) => FriendItemModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Sends a friend request to a target username
  Future<void> sendFriendRequest(String username) async {
    await _client.dio.post(
      ApiConstants.sendFriendRequest,
      data: {'target_username': username},
    );
  }

  /// Accepts a friend request
  Future<void> acceptFriendRequest(String friendshipId) async {
    await _client.dio.post(ApiConstants.acceptFriendRequest(friendshipId));
  }

  /// Declines or cancels a friend request
  Future<void> declineFriendRequest(String friendshipId) async {
    await _client.dio.post(ApiConstants.declineFriendRequest(friendshipId));
  }

  /// Removes an existing friend
  Future<void> removeFriend(String friendId) async {
    await _client.dio.delete(ApiConstants.removeFriend(friendId));
  }
}
