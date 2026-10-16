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

  /// Set of conversationIds whose full history has been fetched from the API.
  final Set<String> _historyLoaded = {};

  /// Set of conversationIds currently fetching history from the API.
  final Set<String> _loadingConversations = {};

  /// Set of conversationIds currently fetching older paginated history.
  final Set<String> _loadingMoreConversations = {};

  /// Tracks whether more older history exists for a conversation.
  final Map<String, bool> _hasMoreHistory = {};

  /// Loading state for history fetch.
  bool _historyLoading = false;

  /// conversationId of the currently open chat (null when not in chat screen).
  String? _activeConversationId;

  /// Current user's ID to filter out self-messages in real-time notifications.
  String? _myUserId;

  /// Emits incoming DM message events when the conversation is not active.
  final ValueNotifier<DmMessage?> onIncomingDmReceived =
      ValueNotifier<DmMessage?>(null);

  int _activeDmSeq = 0;

  /// Emits ({conversationId, senderId, int seq}) when a message is received for the currently active conversation.
  final ValueNotifier<({String conversationId, String senderId, int seq})?>
      onActiveConversationDmReceived = ValueNotifier(null);

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
      clearUnread(conversationId);
    }
  }

  /// Clears unread count for a conversation or user across all matching keys.
  void clearUnread(String conversationId, {String? userId}) {
    bool changed = false;
    if (conversationId.isNotEmpty && _unread.remove(conversationId) != null) {
      changed = true;
    }
    if (userId != null && userId.isNotEmpty && _myUserId != null && _myUserId!.isNotEmpty) {
      final computed = dmConversationId(_myUserId!, userId);
      if (_unread.remove(computed) != null) {
        changed = true;
      }
    }
    // Clean up any remaining matching conversation keys
    final keysToRemove = _unread.keys.where((k) {
      if (conversationId.isNotEmpty && (k == conversationId || k.contains(conversationId))) return true;
      if (userId != null && userId.isNotEmpty && (k.contains(userId) || k == userId)) return true;
      return false;
    }).toList();
    for (final k in keysToRemove) {
      _unread.remove(k);
      changed = true;
    }
    if (changed) {
      notifyListeners();
    }
  }

  /// Synchronizes unread conversations from pending chat notifications.
  void syncUnreadFromNotifications(List<({String conversationId, String? actorId})> pendingChats) {
    bool changed = false;
    final validConvIds = <String>{};

    for (final item in pendingChats) {
      String convId = item.conversationId;
      if (convId.isEmpty && item.actorId != null && item.actorId!.isNotEmpty && _myUserId != null && _myUserId!.isNotEmpty) {
        convId = dmConversationId(_myUserId!, item.actorId!);
      }
      if (convId.isNotEmpty) {
        validConvIds.add(convId);
        // Do not mark unread if this conversation is currently open
        if (_activeConversationId != convId) {
          if ((_unread[convId] ?? 0) == 0) {
            _unread[convId] = 1;
            changed = true;
          }
        }
      }
    }

    if (changed) {
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
    _historyLoaded.clear();
    _loadingConversations.clear();
    _loadingMoreConversations.clear();
    _hasMoreHistory.clear();
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

  bool isHistoryLoaded(String conversationId) =>
      _historyLoaded.contains(conversationId);

  bool isHistoryLoadingFor(String conversationId) =>
      _loadingConversations.contains(conversationId);

  bool hasMoreHistoryFor(String conversationId) =>
      _hasMoreHistory[conversationId] ?? true;

  bool isLoadingMoreFor(String conversationId) =>
      _loadingMoreConversations.contains(conversationId);

  /// Loads (or refreshes) the latest history batch for a given conversation.
  Future<void> loadHistory(String conversationId, {bool refresh = false}) async {
    if (conversationId.isEmpty) return;
    if (_loadingConversations.contains(conversationId)) return;
    if (_historyLoaded.contains(conversationId) && !refresh) return;

    _loadingConversations.add(conversationId);
    _historyLoading = true;
    notifyListeners();

    try {
      final msgs = await _apiService.getHistory(conversationId);
      final current = _history[conversationId] ?? [];
      final pending = current.where((m) => m.id < 0).toList();
      List<DmMessage> combined;
      if (refresh) {
        combined = [...msgs, ...pending]
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      } else {
        final apiIds = msgs.map((m) => m.id).toSet();
        final extra = current.where((m) => !apiIds.contains(m.id)).toList();
        combined = [...msgs, ...extra]
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      }
      _history[conversationId] = combined;
      _historyLoaded.add(conversationId);
      _hasMoreHistory[conversationId] = msgs.length >= 50;

      // Seed preview if missing
      if (combined.isNotEmpty && !_previews.containsKey(conversationId)) {
        _previews[conversationId] = combined.last;
      }
    } catch (e) {
      debugPrint('[DmProvider] Failed to load history: $e');
    } finally {
      _loadingConversations.remove(conversationId);
      _historyLoading = _loadingConversations.isNotEmpty;
      notifyListeners();
    }
  }

  /// Fetches older paginated history when scrolling up.
  Future<void> loadMoreHistory(String conversationId) async {
    if (conversationId.isEmpty) return;
    if (_loadingMoreConversations.contains(conversationId)) return;
    if (_hasMoreHistory[conversationId] == false) return;

    final current = _history[conversationId] ?? [];
    final apiCount = current.where((m) => m.id > 0).length;
    if (apiCount == 0) return;

    _loadingMoreConversations.add(conversationId);
    notifyListeners();

    try {
      final older = await _apiService.getHistory(
        conversationId,
        offset: apiCount,
        limit: 50,
      );
      if (older.isEmpty ||
          older.length < 50 ||
          older.every((m) => current.any((c) => c.id == m.id))) {
        _hasMoreHistory[conversationId] = false;
      }
      if (older.isNotEmpty) {
        final map = {for (final m in current) m.id: m};
        for (final m in older) {
          map[m.id] = m;
        }
        final combined = map.values.toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        _history[conversationId] = combined;
      }
    } catch (e) {
      debugPrint('[DmProvider] Failed to load more history: $e');
    } finally {
      _loadingMoreConversations.remove(conversationId);
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
    String? recipientUsername,
    int? senderAvatarIndex,
    int? recipientAvatarIndex,
  }) {
    final myId = senderId ?? _myUserId ?? '';
    final convId = myId.isNotEmpty ? dmConversationId(myId, recipientId) : '';

    if (convId.isNotEmpty) {
      final optimisticMsg = DmMessage(
        id: -DateTime.now().millisecondsSinceEpoch,
        conversationId: convId,
        senderId: myId,
        senderUsername: senderUsername ?? '',
        senderAvatarIndex: senderAvatarIndex ?? 0,
        recipientId: recipientId,
        recipientUsername: recipientUsername ?? '',
        recipientAvatarIndex: recipientAvatarIndex ?? 0,
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
        onActiveConversationDmReceived.value = (
          conversationId: dm.conversationId,
          senderId: dm.senderId,
          seq: ++_activeDmSeq,
        );
      }
    }

    notifyListeners();
  }

  @visibleForTesting
  void handleWsMessageForTesting(WsMessage msg) => _onWsMessage(msg);

  bool _disposed = false;

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _wsSub?.cancel();
    onIncomingDmReceived.dispose();
    onActiveConversationDmReceived.dispose();
    onDmInteraction.dispose();
    super.dispose();
  }
}
