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

  /// Current user's ID to filter out self-messages in real-time notifications.
  String? _myUserId;

  /// Emits incoming DM message events when the conversation is not active.
  final ValueNotifier<DmMessage?> onIncomingDmReceived =
      ValueNotifier<DmMessage?>(null);

  /// Emits conversationId when a message is received for the currently active conversation.
  final ValueNotifier<String?> onActiveConversationDmReceived =
      ValueNotifier<String?>(null);

  /// Emits (userId, timestamp) for any DM sent or received to update friend interaction order.
  final ValueNotifier<({String userId, DateTime time})?> onDmInteraction =
      ValueNotifier<({String userId, DateTime time})?>(null);

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

  /// Set the current user's ID to filter out self-sent echoes.
  void setMyUserId(String? userId) {
    _myUserId = userId;
  }

  /// Call once after authentication to start listening for incoming DMs.
  void startListening({String? myUserId}) {
    if (myUserId != null) _myUserId = myUserId;
    _wsSub?.cancel();
    _wsSub = WebSocketService.instance.messages.listen(_onWsMessage);
    loadPreviews();
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
    _myUserId = null;
    onIncomingDmReceived.value = null;
    onActiveConversationDmReceived.value = null;
    onDmInteraction.value = null;
    _wsSub?.cancel();
    _wsSub = null;
    notifyListeners();
  }

  // ─── Load ────────────────────────────────────────────────────────────

  Future<void> loadPreviews() async {
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
      final current = _history[conversationId] ?? [];
      final pending = current.where((m) => m.id < 0).toList();
      _history[conversationId] = [...msgs, ...pending];
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

  /// Records a completed match card directly into the conversation's shared match cards.
  void recordMatchCard({
    required String myUserId,
    required String friendId,
    required MatchChatCard card,
  }) {
    final conversationId = dmConversationId(myUserId, friendId);
    final existing = _matchCards[conversationId] ?? [];
    if (!existing.any((c) => c.matchId == card.matchId)) {
      _matchCards[conversationId] = [...existing, card];
      notifyListeners();
    }
  }

  /// Loads the shared match cards between [myUserId] and [friendId].
  /// Refreshes in the background if cards already exist.
  Future<void> loadSharedMatches(
    String conversationId,
    String myUserId,
    String friendId, {
    bool refresh = true,
  }) async {
    if (_matchCards.containsKey(conversationId) && !refresh) return;
    try {
      final cards = await _apiService.fetchSharedMatches(myUserId, friendId);
      final existing = _matchCards[conversationId] ?? [];
      final map = <String, MatchChatCard>{};
      for (final c in existing) {
        map[c.matchId] = c;
      }
      for (final c in cards) {
        map[c.matchId] = c;
      }
      _matchCards[conversationId] = map.values.toList();
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

  /// Sends a DM over WebSocket. Optimistically appends the message to history
  /// so the chat UI updates immediately without waiting for server round-trip.
  void sendDm({
    required String recipientId,
    required String content,
    String? senderId,
    String? senderUsername,
  }) {
    final myId = senderId ?? _myUserId ?? '';
    final convId = myId.isNotEmpty ? dmConversationId(myId, recipientId) : '';

    if (convId.isNotEmpty) {
      final optimisticMsg = DmMessage(
        id: -DateTime.now().millisecondsSinceEpoch,
        conversationId: convId,
        senderId: myId,
        senderUsername: senderUsername ?? '',
        recipientId: recipientId,
        content: content,
        createdAt: DateTime.now(),
      );

      final conv = _history[convId] ?? [];
      _history[convId] = [...conv, optimisticMsg];
      _previews[convId] = optimisticMsg;
      onDmInteraction.value = (userId: recipientId, time: optimisticMsg.createdAt);
      notifyListeners();
    }

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

    // Check if the sender is ourselves (echo from server)
    final isMe = _myUserId != null && _myUserId!.isNotEmpty && dm.senderId == _myUserId;

    // Append to history or replace matching optimistic message
    final conv = _history[dm.conversationId] ?? [];
    final optIndex = conv.indexWhere(
      (m) =>
          m.id < 0 &&
          m.senderId == dm.senderId &&
          m.content == dm.content,
    );
    if (optIndex != -1) {
      final updated = List<DmMessage>.from(conv);
      updated[optIndex] = dm;
      _history[dm.conversationId] = updated;
    } else if (!conv.any((m) => m.id == dm.id)) {
      _history[dm.conversationId] = [...conv, dm];
    }

    // Update preview
    _previews[dm.conversationId] = dm;

    final otherUserId = isMe ? dm.recipientId : dm.senderId;
    if (otherUserId.isNotEmpty) {
      onDmInteraction.value = (userId: otherUserId, time: dm.createdAt);
    }

    if (!isMe) {
      // Increment unread if this conversation is not currently active
      if (_activeConversationId != dm.conversationId) {
        _unread[dm.conversationId] =
            (_unread[dm.conversationId] ?? 0) + 1;
        onIncomingDmReceived.value = dm;
      } else {
        onActiveConversationDmReceived.value = dm.conversationId;
      }
    }

    notifyListeners();
  }

  @visibleForTesting
  void handleWsMessageForTesting(WsMessage msg) => _onWsMessage(msg);

  @override
  void dispose() {
    _wsSub?.cancel();
    onIncomingDmReceived.dispose();
    onActiveConversationDmReceived.dispose();
    onDmInteraction.dispose();
    super.dispose();
  }
}
