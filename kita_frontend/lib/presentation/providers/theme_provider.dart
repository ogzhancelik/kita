import 'package:flutter/material.dart';
import '../../core/storage/secure_storage_service.dart';

class ThemeProvider extends ChangeNotifier {
  final SecureStorageService _storage;
  ThemeMode _themeMode = ThemeMode.dark;

  ThemeProvider([SecureStorageService? storage])
      : _storage = storage ?? SecureStorageService() {
    _loadTheme();
  }

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> _loadTheme() async {
    final saved = await _storage.getThemeMode();
    if (saved != null) {
      if (saved == 'light') {
        _themeMode = ThemeMode.light;
      } else if (saved == 'system') {
        _themeMode = ThemeMode.system;
      } else {
        _themeMode = ThemeMode.dark;
      }
      notifyListeners();
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    String val = 'dark';
    if (mode == ThemeMode.light) val = 'light';
    if (mode == ThemeMode.system) val = 'system';
    await _storage.saveThemeMode(val);
  }

  Future<void> toggleTheme() async {
    if (_themeMode == ThemeMode.dark) {
      await setThemeMode(ThemeMode.light);
    } else {
      await setThemeMode(ThemeMode.dark);
    }
  }
}
