import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../data/models/user_model.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage;
  static final Map<String, String> _memoryFallback = {};

  SecureStorageService([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const String _tokenKey = 'kita_jwt_token';
  static const String _userKey = 'kita_cached_user';
  static const String _guestNameKey = 'kita_guest_name';
  static const String _guestAvatarKey = 'kita_guest_avatar';
  static const String _themeKey = 'kita_theme_mode';

  Future<void> _writeSafe(String key, String value) async {
    _memoryFallback[key] = value;
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      debugPrint('SecureStorage write warning ($key): $e. Using memory fallback.');
    }
  }

  Future<String?> _readSafe(String key) async {
    try {
      final val = await _storage.read(key: key);
      if (val != null) return val;
    } catch (e) {
      debugPrint('SecureStorage read warning ($key): $e. Using memory fallback.');
    }
    return _memoryFallback[key];
  }

  Future<void> _deleteSafe(String key) async {
    _memoryFallback.remove(key);
    try {
      await _storage.delete(key: key);
    } catch (e) {
      debugPrint('SecureStorage delete warning ($key): $e.');
    }
  }

  // --- JWT Token ---
  Future<void> saveToken(String token) async {
    await _writeSafe(_tokenKey, token);
  }

  Future<String?> getToken() async {
    return await _readSafe(_tokenKey);
  }

  Future<void> deleteToken() async {
    await _deleteSafe(_tokenKey);
  }

  // --- Cached User Profile ---
  Future<void> saveUser(UserProfile user) async {
    await _writeSafe(_userKey, jsonEncode(user.toJson()));
  }

  Future<UserProfile?> getUser() async {
    final raw = await _readSafe(_userKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return UserProfile.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteUser() async {
    await _deleteSafe(_userKey);
  }

  // --- Guest Session ---
  Future<void> saveGuestProfile(String name, int avatarIndex) async {
    await _writeSafe(_guestNameKey, name);
    await _writeSafe(_guestAvatarKey, avatarIndex.toString());
  }

  Future<GuestProfile?> getGuestProfile() async {
    final name = await _readSafe(_guestNameKey);
    if (name == null || name.isEmpty) return null;
    final avatarStr = await _readSafe(_guestAvatarKey);
    final avatar = int.tryParse(avatarStr ?? '0') ?? 0;
    return GuestProfile(nickname: name, avatarIndex: avatar);
  }

  Future<void> deleteGuestProfile() async {
    await _deleteSafe(_guestNameKey);
    await _deleteSafe(_guestAvatarKey);
  }

  // --- Theme Mode ---
  Future<void> saveThemeMode(String mode) async {
    await _writeSafe(_themeKey, mode);
  }

  Future<String?> getThemeMode() async {
    return await _readSafe(_themeKey);
  }

  // Clear all credentials
  Future<void> clearAll() async {
    _memoryFallback.clear();
    try {
      await _storage.deleteAll();
    } catch (e) {
      debugPrint('SecureStorage clearAll warning: $e.');
    }
  }
}
