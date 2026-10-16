import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/ws_message_models.dart';
import 'websocket_service.dart';

/// Service responsible for tracking local user inactivity across the application
/// and broadcasting AFK (Away) / Online presence state transitions over WebSocket.
class UserPresenceService {
  UserPresenceService._();
  static final UserPresenceService instance = UserPresenceService._();

  /// Default idle duration before transitioning to AFK status (3 minutes).
  static const Duration idleTimeout = Duration(minutes: 3);

  Timer? _idleTimer;
  bool _isAfk = false;
  DateTime _lastInteraction = DateTime.now();
  bool _isActive = false;

  /// ValueNotifier indicating whether the local user is currently AFK.
  final ValueNotifier<bool> isAfkNotifier = ValueNotifier<bool>(false);

  /// Whether the user is currently considered AFK.
  bool get isAfk => _isAfk;

  /// Starts or resumes inactivity monitoring.
  void start() {
    _isActive = true;
    _lastInteraction = DateTime.now();
    _resetTimer();
  }

  /// Stops monitoring and resets local AFK state.
  void stop() {
    _isActive = false;
    _idleTimer?.cancel();
    _idleTimer = null;
    if (_isAfk) {
      _setAfk(false);
    }
  }

  /// Records user interaction (touch, pointer move, click).
  ///
  /// If [isInMatch] is true, the user is never transitioned to AFK because
  /// chess clock time management and turn contemplation are active.
  void recordActivity({bool isInMatch = false}) {
    if (!_isActive) {
      start();
    }

    final now = DateTime.now();

    if (isInMatch) {
      if (_isAfk) {
        _setAfk(false);
      }
      _lastInteraction = now;
      _resetTimer();
      return;
    }

    if (_isAfk) {
      _setAfk(false);
      _lastInteraction = now;
      _resetTimer();
      return;
    }

    // Debounce timer resets during rapid continuous pointer movements
    if (now.difference(_lastInteraction) >= const Duration(seconds: 10)) {
      _lastInteraction = now;
      _resetTimer();
    }
  }

  void _resetTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(idleTimeout, _onIdleTimeout);
  }

  void _onIdleTimeout() {
    if (!_isActive || _isAfk) return;
    if (!WebSocketService.instance.isConnected) return;

    _setAfk(true);
  }

  void _setAfk(bool afk) {
    if (_isAfk == afk) return;
    _isAfk = afk;
    isAfkNotifier.value = afk;

    if (WebSocketService.instance.isConnected) {
      WebSocketService.instance.send(
        WsClientType.presenceUpdate,
        {'status': afk ? 'afk' : 'online'},
      );
      debugPrint('[UserPresence] Dispatched presence_update -> ${afk ? "afk" : "online"}');
    }
  }
}
