import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/constants/api_constants.dart';
import '../models/ws_message_models.dart';

/// WebSocket connection state enum.
enum WsConnectionState { disconnected, connecting, connected, reconnecting }

/// Singleton WebSocket service for real-time game communication.
///
/// Manages connection lifecycle, automatic reconnection with exponential
/// backoff, and provides a broadcast stream of parsed [WsMessage]s.
class WebSocketService {
  WebSocketService._();
  static final WebSocketService instance = WebSocketService._();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;

  // Broadcast stream for all incoming WS messages
  final StreamController<WsMessage> _messageController =
      StreamController<WsMessage>.broadcast();

  /// Stream of all incoming WebSocket messages. Multiple listeners supported.
  Stream<WsMessage> get messages => _messageController.stream;

  /// Current connection state. Listen to this for UI connection indicators.
  final ValueNotifier<WsConnectionState> connectionState =
      ValueNotifier(WsConnectionState.disconnected);

  /// Connected user info (set after receiving 'connected' message from server).
  final ValueNotifier<ConnectedPayload?> connectedUser = ValueNotifier(null);

  String? _token;
  String? _nickname;
  int _reconnectAttempt = 0;
  static const int _maxReconnectAttempts = 5;
  bool _intentionalDisconnect = false;
  final List<String> _pendingMessages = [];

  /// Connect to the WebSocket server.
  /// If [token] is provided, it's sent as a query parameter for authentication.
  /// If [nickname] is provided (e.g. for guests), it's sent for display name resolution.
  void connect({String? token, String? nickname}) {
    final isAlreadyActive =
        connectionState.value == WsConnectionState.connected ||
        connectionState.value == WsConnectionState.connecting;

    if (isAlreadyActive && _token == token && _nickname == nickname) {
      return;
    }

    if (isAlreadyActive) {
      _cleanup();
    }

    _token = token;
    _nickname = nickname;
    _intentionalDisconnect = false;
    _reconnectAttempt = 0;
    _doConnect();
  }

  void _doConnect() {
    connectionState.value = _reconnectAttempt == 0
        ? WsConnectionState.connecting
        : WsConnectionState.reconnecting;

    try {
      final wsUrl = _buildWsUrl();
      debugPrint('[WS] Connecting to $wsUrl (attempt ${_reconnectAttempt + 1})');

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('[WS] Connection error: $e');
      _scheduleReconnect();
    }
  }

  String _buildWsUrl() {
    var url = ApiConstants.wsUrl;
    final params = <String>[];
    if (_token != null && _token!.isNotEmpty) {
      params.add('token=$_token');
    }
    if (_nickname != null && _nickname!.isNotEmpty) {
      params.add('nickname=${Uri.encodeComponent(_nickname!)}');
    }
    if (params.isNotEmpty) {
      url += '?${params.join('&')}';
    }
    return url;
  }

  void _onMessage(dynamic data) {
    if (data is! String) return;

    // Server may batch multiple JSON messages separated by newlines
    final lines = data.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      try {
        final json = jsonDecode(trimmed) as Map<String, dynamic>;
        final msg = WsMessage.fromJson(json);

        // Handle connected message to update state
        if (msg.type == WsServerType.connected && msg.payload != null) {
          connectionState.value = WsConnectionState.connected;
          connectedUser.value = ConnectedPayload.fromJson(msg.payload!);
          _reconnectAttempt = 0;
          debugPrint('[WS] Connected as ${connectedUser.value?.username}');

          // Flush any pending messages that were queued before connection was established
          while (_pendingMessages.isNotEmpty) {
            final pending = _pendingMessages.removeAt(0);
            try {
              _channel?.sink.add(pending);
            } catch (e) {
              debugPrint('[WS] Failed to send queued message: $e');
            }
          }
        }

        _messageController.add(msg);
      } catch (e) {
        debugPrint('[WS] Message parse error: $e for data: $trimmed');
      }
    }
  }

  void _onError(dynamic error) {
    debugPrint('[WS] Stream error: $error');
  }

  void _onDone() {
    debugPrint('[WS] Connection closed');
    connectionState.value = WsConnectionState.disconnected;
    connectedUser.value = null;

    if (!_intentionalDisconnect) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_intentionalDisconnect) return;
    if (_reconnectAttempt >= _maxReconnectAttempts) {
      debugPrint('[WS] Max reconnect attempts reached. Giving up.');
      connectionState.value = WsConnectionState.disconnected;
      return;
    }

    // Exponential backoff: 1s, 2s, 4s, 8s, 16s (capped)
    final delay = Duration(
      milliseconds: min(1000 * pow(2, _reconnectAttempt).toInt(), 16000),
    );
    _reconnectAttempt++;

    debugPrint('[WS] Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempt)');
    connectionState.value = WsConnectionState.reconnecting;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      _cleanup();
      _doConnect();
    });
  }

  /// Send a typed message to the server.
  /// If not yet connected, queues the message to be sent automatically once connected.
  void send(String type, [Map<String, dynamic>? payload]) {
    final msg = <String, dynamic>{'type': type};
    if (payload != null) {
      msg['payload'] = payload;
    }
    final encoded = jsonEncode(msg);

    if (_channel == null ||
        connectionState.value != WsConnectionState.connected) {
      debugPrint('[WS] Connection pending — queued message: $type');
      _pendingMessages.add(encoded);
      if (connectionState.value == WsConnectionState.disconnected) {
        connect(token: _token, nickname: _nickname);
      }
      return;
    }

    try {
      _channel!.sink.add(encoded);
      debugPrint('[WS] Sent: $type');
    } catch (e) {
      debugPrint('[WS] Send error: $e');
    }
  }

  /// Disconnect from the WebSocket server intentionally.
  void disconnect() {
    debugPrint('[WS] Intentional disconnect');
    _intentionalDisconnect = true;
    _cleanup();
    connectionState.value = WsConnectionState.disconnected;
    connectedUser.value = null;
  }

  void _cleanup() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _subscription?.cancel();
    _subscription = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  /// Dispose the service (app shutdown).
  void dispose() {
    _intentionalDisconnect = true;
    _cleanup();
    _messageController.close();
    connectionState.dispose();
    connectedUser.dispose();
  }

  /// Whether we're currently connected.
  bool get isConnected => connectionState.value == WsConnectionState.connected;
}
