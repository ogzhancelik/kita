import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// Singleton service for device haptic feedback during gameplay and UI interaction.
///
/// Features high-fidelity native haptic channels on Android (subtle tick, click, heavy click)
/// and falls back gracefully to Flutter's [HapticFeedback] platform channel on iOS and other targets.
class HapticService {
  HapticService._();

  static final HapticService instance = HapticService._();

  static const MethodChannel _nativeChannel =
      MethodChannel('com.example.kita_frontend/haptics');

  /// When false, all haptic calls are immediate no-ops.
  bool enabled = true;

  bool get _useNativeAndroid => !kIsWeb && Platform.isAndroid;

  /// Subtle tactile feedback when tapping / selecting a piece or UI control.
  /// Uses a feather-light mechanical tick on modern Android (similar to chess.com).
  Future<void> selection() async {
    if (!enabled) return;
    try {
      if (_useNativeAndroid) {
        await _nativeChannel.invokeMethod('tick');
      } else {
        await HapticFeedback.selectionClick();
      }
    } catch (_) {}
  }

  /// Light tactile impact when a piece is dropped or moved to a valid tile.
  /// Uses a feather-light mechanical tick on modern Android (similar to chess.com).
  Future<void> light() async {
    if (!enabled) return;
    try {
      if (_useNativeAndroid) {
        await _nativeChannel.invokeMethod('tick');
      } else {
        await HapticFeedback.lightImpact();
      }
    } catch (_) {}
  }

  /// Medium tactile impact on king/piece captures, check threats, or urgent warnings.
  /// Uses a crisp, distinct click on modern Android.
  Future<void> medium() async {
    if (!enabled) return;
    try {
      if (_useNativeAndroid) {
        await _nativeChannel.invokeMethod('click');
      } else {
        await HapticFeedback.mediumImpact();
      }
    } catch (_) {}
  }

  /// Heavy tactile impact on match completion (win, loss, or draw).
  Future<void> heavy() async {
    if (!enabled) return;
    try {
      if (_useNativeAndroid) {
        await _nativeChannel.invokeMethod('heavyClick');
      } else {
        await HapticFeedback.heavyImpact();
      }
    } catch (_) {}
  }

  /// Full vibration pulse (e.g. urgent low-time alert, match found).
  Future<void> vibrate() async {
    if (!enabled) return;
    try {
      await HapticFeedback.vibrate();
    } catch (_) {}
  }
}
