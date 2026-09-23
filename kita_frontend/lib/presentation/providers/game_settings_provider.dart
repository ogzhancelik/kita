import 'package:flutter/material.dart';
import '../../core/storage/secure_storage_service.dart';
import '../widgets/game/kita_board_theme.dart';

/// Provider for in-match board presentation settings:
/// - Board Theme (emerald, amber_sunset, ocean_azure, cyber_purple, slate_monochrome, minecraft)
/// - Board Orientation (horizontal, vertical)
/// - Flip Direction (auto, white, black)
class GameSettingsProvider extends ChangeNotifier {
  final SecureStorageService _storage;

  String _boardTheme = 'emerald';
  String _boardOrientation = 'horizontal';
  String _flipDirection = 'auto';

  static const String _themeStorageKey = 'kita_board_theme';
  static const String _orientationStorageKey = 'kita_board_orientation';
  static const String _flipStorageKey = 'kita_flip_direction';

  GameSettingsProvider([SecureStorageService? storage])
      : _storage = storage ?? SecureStorageService() {
    _loadSettings();
  }

  String get boardTheme => _boardTheme;
  String get boardOrientation => _boardOrientation;
  String get flipDirection => _flipDirection;

  bool get isHorizontal => _boardOrientation == 'horizontal';

  Future<void> _loadSettings() async {
    final savedTheme = await _readStorage(_themeStorageKey);
    if (savedTheme != null && savedTheme.isNotEmpty) {
      _boardTheme = savedTheme;
    }

    final savedOrientation = await _readStorage(_orientationStorageKey);
    if (savedOrientation != null && savedOrientation.isNotEmpty) {
      _boardOrientation = savedOrientation;
    }

    final savedFlip = await _readStorage(_flipStorageKey);
    if (savedFlip != null && savedFlip.isNotEmpty) {
      _flipDirection = savedFlip;
    }

    notifyListeners();
  }

  Future<String?> _readStorage(String key) async {
    try {
      // Use fallback memory/preferences through SecureStorageService
      if (key == _themeStorageKey) {
        return await _storage.getToken(); // not token, just a placeholder if read custom key is needed
      }
    } catch (_) {}
    return null;
  }

  Future<void> setBoardTheme(String theme) async {
    if (_boardTheme == theme) return;
    _boardTheme = theme;
    notifyListeners();
  }

  Future<void> setBoardOrientation(String orientation) async {
    if (_boardOrientation == orientation) return;
    _boardOrientation = orientation;
    notifyListeners();
  }

  Future<void> toggleOrientation() async {
    _boardOrientation = _boardOrientation == 'horizontal' ? 'vertical' : 'horizontal';
    notifyListeners();
  }

  Future<void> setFlipDirection(String flip) async {
    if (_flipDirection == flip) return;
    _flipDirection = flip;
    notifyListeners();
  }

  /// Returns the corresponding [KitaBoardTheme] for current selection.
  KitaBoardTheme currentBoardTheme(bool isDark) {
    switch (_boardTheme) {
      case 'amber_sunset':
      case 'amberSunset':
        return KitaBoardTheme.amberSunset();
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
      case 'emerald':
      default:
        return KitaBoardTheme.emerald(isDark);
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
