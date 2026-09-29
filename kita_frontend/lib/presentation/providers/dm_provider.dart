import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import '../../data/models/dm_models.dart';
import '../../data/models/ws_message_models.dart';
import '../../data/services/dm_api_service.dart';
import '../../data/services/websocket_service.dart';

/// Manages all DM state: conversation list, per-conversation message history,
/// real-time delivery via WebSocket, unread badge counts, and shared match cards.
class DmProvider extends ChangeNotifier {
  final DmApiService _apiService;
  StreamSubscription<WsMessage>? _wsSub;

  DmProvider([DmApiService? apiService])
      : _apiService = apiService ?? DmApiService();

  // ─── State ──────────────────────────────────────────────────────────

  /// Last message per conversation (preview list).
  final Map<String, DmMessage> _previews = {};

  /// Full message list per conversationId.
  final Map<String, List<DmMessage>> _history = {};

  /// Loading state for history fetch.
  bool _historyLoading = false;

  /// conversationId of the currently open chat (null when not in chat screen).
  String? _activeConversationId;

  /// Unread message count per conversationId (cleared when user opens that chat).
  final Map<String, int> _unread = {};

  // ─── Shared Match Cards ──────────────────────────────────────────────

  /// MatchChatCards keyed by conversationId (the two player IDs sorted + joined).
  final Map<String, List<MatchChatCard>> _matchCards = {};

  /// In-game messages keyed by matchId. Null = not yet loaded.
  final Map<String, List<InGameMessage>?> _inGameMessages = {};

  /// Loading state per matchId for in-game chat expansion.
  final Map<String, bool> _inGameLoading = {};

  // ─── Getters ────────────────────────────────────────────────────────

  List<DmMessage> get previews {
    final list = _previews.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  List<DmMessage> messagesFor(String conversationId) =>
      _history[conversationId] ?? [];

  bool get isHistoryLoading => _historyLoading;

  int unreadFor(String conversationId) => _unread[conversationId] ?? 0;

  int get totalUnread =>
      _unread.values.fold(0, (sum, count) => sum + count);

  /// Returns match cards for a conversation, sorted oldest → newest.
  List<MatchChatCard> matchCardsFor(String conversationId) =>
      (_matchCards[conversationId] ?? [])
        ..sort((a, b) => a.playedAt.compareTo(b.playedAt));

  /// Returns in-game messages for a match (null = not loaded yet).
  List<InGameMessage>? inGameMessagesFor(String matchId) =>
      _inGameMessages[matchId];

  bool isInGameLoading(String matchId) => _inGameLoading[matchId] ?? false;

  // ─── Lifecycle ──────────────────────────────────────────────────────

  /// Call once after authentication to start listening for incoming DMs.
  void startListening() {
    _wsSub?.cancel();
    _wsSub = WebSocketService.instance.messages.listen(_onWsMessage);
    _loadPreviews();
  }

  /// Mark a conversation as active (clears its unread count).
  void setActiveConversation(String? conversationId) {
    _activeConversationId = conversationId;
    if (conversationId != null) {
      _unread.remove(conversationId);
      notifyListeners();
    }
  }

  void stopListening() {
    _wsSub?.cancel();
    _wsSub = null;
  }

  /// Call on logout to wipe all DM state.
  void clear() {
    _previews.clear();
    _history.clear();
    _unread.clear();
    _matchCards.clear();
    _inGameMessages.clear();
    _inGameLoading.clear();
    _activeConversationId = null;
    _wsSub?.cancel();
    _wsSub = null;
    notifyListeners();
  }

  // ─── Load ────────────────────────────────────────────────────────────

  Future<void> _loadPreviews() async {
    if (ApiClient.currentToken == null || ApiClient.currentToken!.isEmpty) {
      return;
    }
    try {
      final list = await _apiService.getConversationPreviews();
      for (final msg in list) {
        _previews[msg.conversationId] = msg;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[DmProvider] Failed to load previews: $e');
    }
  }

  /// Loads (or paginates) history for a given conversation.
  Future<void> loadHistory(String conversationId, {bool refresh = false}) async {
    final existing = _history[conversationId];
    if (existing != null && !refresh) return;

    _historyLoading = true;
    notifyListeners();

    try {
      final msgs = await _apiService.getHistory(conversationId);
      _history[conversationId] = msgs;
      // Seed preview if missing
      if (msgs.isNotEmpty && !_previews.containsKey(conversationId)) {
        _previews[conversationId] = msgs.last;
      }
    } catch (e) {
      debugPrint('[DmProvider] Failed to load history: $e');
    } finally {
      _historyLoading = false;
      notifyListeners();
    }
  }

  /// Loads the shared match cards between [myUserId] and [friendId].
  /// Only loads once per conversation unless [refresh] is true.
  Future<void> loadSharedMatches(
    String conversationId,
    String myUserId,
    String friendId, {
    bool refresh = false,
  }) async {
    if (_matchCards.containsKey(conversationId) && !refresh) return;
    try {
      final cards = await _apiService.fetchSharedMatches(myUserId, friendId);
      _matchCards[conversationId] = cards;
      notifyListeners();
    } catch (e) {
      debugPrint('[DmProvider] Failed to load shared matches: $e');
    }
  }

  /// Loads in-game chat for a specific match. Idempotent (loads once).
  Future<void> loadInGameMessages(String matchId) async {
    if (_inGameMessages.containsKey(matchId)) return; // already loaded
    _inGameLoading[matchId] = true;
    notifyListeners();

    try {
      final msgs = await _apiService.fetchMatchMessages(matchId);
      _inGameMessages[matchId] = msgs;
    } catch (e) {
      debugPrint('[DmProvider] Failed to load in-game messages for $matchId: $e');
      _inGameMessages[matchId] = [];
    } finally {
      _inGameLoading[matchId] = false;
      notifyListeners();
    }
  }

  // ─── Send ────────────────────────────────────────────────────────────

  /// Sends a DM over WebSocket. The echo (dm_broadcast) from the server will
  /// append the message to history — no optimistic update needed since the WS
  /// round-trip is near-instant on LAN/cloud.
  void sendDm({required String recipientId, required String content}) {
    WebSocketService.instance.send(WsClientType.dmSend, {
      'recipient_id': recipientId,
      'content': content,
    });
  }

  // ─── WS Listener ─────────────────────────────────────────────────────

  void _onWsMessage(WsMessage msg) {
    if (msg.type != WsServerType.dmBroadcast) return;
    final payload = msg.payload;
    if (payload == null) return;

    final dm = DmMessage.fromJson(payload);

    // Append to history if it's loaded
    final conv = _history[dm.conversationId];
    if (conv != null) {
      _history[dm.conversationId] = [...conv, dm];
    }

    // Update preview
    _previews[dm.conversationId] = dm;

    // Increment unread if this conversation is not currently active
    if (_activeConversationId != dm.conversationId) {
      _unread[dm.conversationId] =
          (_unread[dm.conversationId] ?? 0) + 1;
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    super.dispose();
  }
}
