import 'package:flutter/material.dart';
import '../../core/feedback/haptic_service.dart';
import '../../core/feedback/sound_service.dart';
import '../../core/storage/secure_storage_service.dart';
import '../widgets/game/kita_board_theme.dart';

/// Provider for in-match board presentation & gameplay settings:
/// - Board Theme (emerald, amber_sunset, ocean_azure, cyber_purple, slate_monochrome, minecraft)
/// - Board Orientation (horizontal, vertical)
/// - Flip Direction (auto, white, black)
/// - Audio / Sound Effects (enabled / disabled)
/// - Haptic Feedback (enabled / disabled)
/// - 2P Local Coop: Auto-rotate pieces on turn switch (enabled / disabled)
/// - 2P Local Coop: Default piece orientation ('vertical' = 0°, 'horizontal' = 90°)
/// - Swap tile colors for 1 and 3 (1s lighter, 3s darker)
class GameSettingsProvider extends ChangeNotifier {
  final SecureStorageService _storage;

  String _boardTheme = 'amber_sunset';
  String _boardOrientation = 'horizontal';
  String _flipDirection = 'auto';
  bool _soundEnabled = true;
  bool _hapticsEnabled = true;
  bool _localCoopAutoRotate = true;
  String _localCoopDefaultRotation = 'vertical';
  bool _swapTileColors = false;
  String _lastMoveIndicator = 'line'; // 'line', 'highlight', 'off'
  String _boardTileStyle = 'rounded'; // 'rounded', 'flat'

  static const String _themeStorageKey = 'kita_board_theme';
  static const String _orientationStorageKey = 'kita_board_orientation';
  static const String _flipStorageKey = 'kita_flip_direction';
  static const String _soundStorageKey = 'kita_sound_enabled';
  static const String _hapticsStorageKey = 'kita_haptics_enabled';
  static const String _localCoopAutoRotateKey = 'kita_local_coop_auto_rotate';
  static const String _localCoopDefaultRotationKey = 'kita_local_coop_default_rotation';
  static const String _swapTileColorsKey = 'kita_swap_tile_colors';
  static const String _lastMoveIndicatorKey = 'kita_last_move_indicator';
  static const String _boardTileStyleKey = 'kita_board_tile_style';

  GameSettingsProvider([SecureStorageService? storage])
      : _storage = storage ?? SecureStorageService() {
    _loadSettings();
  }

  String get boardTheme => _boardTheme;
  String get boardOrientation => _boardOrientation;
  String get flipDirection => _flipDirection;
  bool get soundEnabled => _soundEnabled;
  bool get hapticsEnabled => _hapticsEnabled;
  bool get localCoopAutoRotate => _localCoopAutoRotate;
  String get localCoopDefaultRotation => _localCoopDefaultRotation;
  bool get isLocalCoopHorizontal => _localCoopDefaultRotation == 'horizontal';
  bool get swapTileColors => _swapTileColors;
  String get lastMoveIndicator => _lastMoveIndicator;
  bool get isLastMoveHighlight => _lastMoveIndicator == 'highlight';
  bool get isLastMoveLine => _lastMoveIndicator == 'line';
  bool get isLastMoveOff => _lastMoveIndicator == 'off';
  String get boardTileStyle => _boardTileStyle;
  bool get isFlatTiles => _boardTileStyle == 'flat';

  bool get isHorizontal => _boardOrientation == 'horizontal';

  Future<void> _loadSettings() async {
    try {
      final results = await Future.wait([
        _storage.readString(_themeStorageKey),
        _storage.readString(_orientationStorageKey),
        _storage.readString(_flipStorageKey),
        _storage.readString(_soundStorageKey),
        _storage.readString(_hapticsStorageKey),
        _storage.readString(_localCoopAutoRotateKey),
        _storage.readString(_localCoopDefaultRotationKey),
        _storage.readString(_swapTileColorsKey),
        _storage.readString(_lastMoveIndicatorKey),
        _storage.readString(_boardTileStyleKey),
      ]);

      final savedTheme = results[0];
      if (savedTheme != null && savedTheme.isNotEmpty) {
        _boardTheme = savedTheme;
      }

      final savedOrientation = results[1];
      if (savedOrientation != null && savedOrientation.isNotEmpty) {
        _boardOrientation = savedOrientation;
      }

      final savedFlip = results[2];
      if (savedFlip != null && savedFlip.isNotEmpty) {
        _flipDirection = savedFlip;
      }

      final savedSound = results[3];
      if (savedSound != null && savedSound.isNotEmpty) {
        _soundEnabled = savedSound == 'true';
        SoundService.instance.enabled = _soundEnabled;
      }

      final savedHaptics = results[4];
      if (savedHaptics != null && savedHaptics.isNotEmpty) {
        _hapticsEnabled = savedHaptics == 'true';
        HapticService.instance.enabled = _hapticsEnabled;
      }

      final savedAutoRotate = results[5];
      if (savedAutoRotate != null && savedAutoRotate.isNotEmpty) {
        _localCoopAutoRotate = savedAutoRotate == 'true';
      }

      final savedDefaultRotation = results[6];
      if (savedDefaultRotation != null && savedDefaultRotation.isNotEmpty) {
        _localCoopDefaultRotation = savedDefaultRotation;
      }

      final savedSwapTileColors = results[7];
      if (savedSwapTileColors != null && savedSwapTileColors.isNotEmpty) {
        _swapTileColors = savedSwapTileColors == 'true';
      }

      final savedLastMoveIndicator = results[8];
      if (savedLastMoveIndicator != null && savedLastMoveIndicator.isNotEmpty) {
        _lastMoveIndicator = savedLastMoveIndicator;
      }

      final savedBoardTileStyle = results[9];
      if (savedBoardTileStyle != null && savedBoardTileStyle.isNotEmpty) {
        _boardTileStyle = savedBoardTileStyle;
      }

      notifyListeners();
    } catch (_) {}
  }

  Future<void> setBoardTileStyle(String style) async {
    if (_boardTileStyle == style) return;
    _boardTileStyle = style;
    notifyListeners();
    await _storage.writeString(_boardTileStyleKey, style);
  }

  Future<void> setLastMoveIndicator(String mode) async {
    if (_lastMoveIndicator == mode) return;
    _lastMoveIndicator = mode;
    notifyListeners();
    await _storage.writeString(_lastMoveIndicatorKey, mode);
  }

  Future<void> setBoardTheme(String theme) async {
    if (_boardTheme == theme) return;
    _boardTheme = theme;
    notifyListeners();
    await _storage.writeString(_themeStorageKey, theme);
  }

  Future<void> setBoardOrientation(String orientation) async {
    if (_boardOrientation == orientation) return;
    _boardOrientation = orientation;
    notifyListeners();
    await _storage.writeString(_orientationStorageKey, orientation);
  }

  Future<void> toggleOrientation() async {
    _boardOrientation = _boardOrientation == 'horizontal' ? 'vertical' : 'horizontal';
    notifyListeners();
    await _storage.writeString(_orientationStorageKey, _boardOrientation);
  }

  Future<void> setFlipDirection(String flip) async {
    if (_flipDirection == flip) return;
    _flipDirection = flip;
    notifyListeners();
    await _storage.writeString(_flipStorageKey, flip);
  }

  Future<void> cycleFlipDirection() async {
    if (_flipDirection == 'auto') {
      await setFlipDirection('white');
    } else if (_flipDirection == 'white') {
      await setFlipDirection('black');
    } else {
      await setFlipDirection('auto');
    }
  }

  Future<void> setSoundEnabled(bool enabled) async {
    if (_soundEnabled == enabled) return;
    _soundEnabled = enabled;
    SoundService.instance.enabled = enabled;
    notifyListeners();
    await _storage.writeString(_soundStorageKey, enabled.toString());
  }

  Future<void> toggleSound() async {
    await setSoundEnabled(!_soundEnabled);
  }

  Future<void> setHapticsEnabled(bool enabled) async {
    if (_hapticsEnabled == enabled) return;
    _hapticsEnabled = enabled;
    HapticService.instance.enabled = enabled;
    notifyListeners();
    await _storage.writeString(_hapticsStorageKey, enabled.toString());
  }

  Future<void> toggleHaptics() async {
    await setHapticsEnabled(!_hapticsEnabled);
  }

  Future<void> setLocalCoopAutoRotate(bool autoRotate) async {
    if (_localCoopAutoRotate == autoRotate) return;
    _localCoopAutoRotate = autoRotate;
    notifyListeners();
    await _storage.writeString(_localCoopAutoRotateKey, autoRotate.toString());
  }

  Future<void> setLocalCoopDefaultRotation(String rotation) async {
    if (_localCoopDefaultRotation == rotation) return;
    _localCoopDefaultRotation = rotation;
    notifyListeners();
    await _storage.writeString(_localCoopDefaultRotationKey, rotation);
  }

  Future<void> setSwapTileColors(bool swap) async {
    if (_swapTileColors == swap) return;
    _swapTileColors = swap;
    notifyListeners();
    await _storage.writeString(_swapTileColorsKey, swap.toString());
  }

  /// Returns the corresponding [KitaBoardTheme] for current selection,
  /// with tile colors 1 and 3 swapped if [_swapTileColors] is enabled,
  /// and flat tile style applied if [_boardTileStyle] is 'flat'.
  KitaBoardTheme currentBoardTheme(bool isDark) {
    final base = _resolveThemeByKey(_boardTheme, isDark);
    final withSwap = base.withSwappedColors(_swapTileColors);
    return withSwap.asFlatTiles(isFlatTiles);
  }

  /// Returns a preview [KitaBoardTheme] by key with tile swap applied
  /// and flat tile style applied if [_boardTileStyle] is 'flat'.
  KitaBoardTheme previewTheme(String themeKey, bool isDark) {
    final base = _resolveThemeByKey(themeKey, isDark);
    final withSwap = base.withSwappedColors(_swapTileColors);
    return withSwap.asFlatTiles(isFlatTiles);
  }

  KitaBoardTheme _resolveThemeByKey(String key, bool isDark) {
    switch (key) {
      case 'emerald':
        return KitaBoardTheme.emerald(isDark);
      case 'ocean_azure':
      case 'oceanAzure':
        return KitaBoardTheme.oceanAzure();
      case 'cyber_purple':
      case 'cyberPurple':
        return KitaBoardTheme.cyberPurple();
      case 'slate_monochrome':
      case 'slateMonochrome':
        return KitaBoardTheme.slateMonochrome();
      case 'minecraft':
        return KitaBoardTheme.minecraft();
      case 'amber_sunset':
      case 'amberSunset':
      default:
        return KitaBoardTheme.amberSunset();
    }
  }

  /// Evaluates whether the board should be flipped (180deg) for the player.
  bool shouldFlipBoard(String playerTeam) {
    if (_flipDirection == 'black') return true;
    if (_flipDirection == 'white') return false;
    // 'auto': Black player viewpoint has board flipped so their pieces start at bottom
    return playerTeam.toLowerCase() == 'black';
  }
}
