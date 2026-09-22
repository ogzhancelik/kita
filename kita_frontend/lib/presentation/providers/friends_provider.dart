import 'package:flutter/foundation.dart';

import '../../data/models/friend_models.dart';
import '../../data/services/friend_api_service.dart';

class FriendsProvider extends ChangeNotifier {
  final FriendApiService _apiService;

  FriendsProvider([FriendApiService? apiService])
      : _apiService = apiService ?? FriendApiService();

  List<FriendItemModel> _friends = [];
  List<FriendItemModel> _pendingRequests = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<FriendItemModel> get friends => _friends;
  List<FriendItemModel> get pendingRequests => _pendingRequests;
  List<FriendItemModel> get incomingRequests =>
      _pendingRequests.where((r) => r.direction == 'incoming').toList();
  List<FriendItemModel> get outgoingRequests =>
      _pendingRequests.where((r) => r.direction == 'outgoing').toList();

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get pendingIncomingCount => incomingRequests.length;

  Future<void> loadAll() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _apiService.getFriends(),
        _apiService.getPendingRequests(),
      ]);
      _friends = results[0];
      _pendingRequests = results[1];
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> sendRequest(String username) async {
    try {
      await _apiService.sendFriendRequest(username);
      await loadAll();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> acceptRequest(String friendshipId) async {
    try {
      await _apiService.acceptFriendRequest(friendshipId);
      await loadAll();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> declineRequest(String friendshipId) async {
    try {
      await _apiService.declineFriendRequest(friendshipId);
      await loadAll();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeFriend(String friendId) async {
    try {
      await _apiService.removeFriend(friendId);
      await loadAll();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
