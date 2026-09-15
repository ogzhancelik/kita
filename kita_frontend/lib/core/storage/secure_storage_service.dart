import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../data/models/user_model.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const String _tokenKey = 'kita_jwt_token';
  static const String _userKey = 'kita_cached_user';
  static const String _guestNameKey = 'kita_guest_name';
  static const String _guestAvatarKey = 'kita_guest_avatar';
  static const String _themeKey = 'kita_theme_mode';

  // --- JWT Token ---
  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }

  // --- Cached User Profile ---
  Future<void> saveUser(UserProfile user) async {
    await _storage.write(key: _userKey, value: jsonEncode(user.toJson()));
  }

  Future<UserProfile?> getUser() async {
    final raw = await _storage.read(key: _userKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return UserProfile.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteUser() async {
    await _storage.delete(key: _userKey);
  }

  // --- Guest Session ---
  Future<void> saveGuestProfile(String name, int avatarIndex) async {
    await _storage.write(key: _guestNameKey, value: name);
    await _storage.write(key: _guestAvatarKey, value: avatarIndex.toString());
  }

  Future<GuestProfile?> getGuestProfile() async {
    final name = await _storage.read(key: _guestNameKey);
    if (name == null || name.isEmpty) return null;
    final avatarStr = await _storage.read(key: _guestAvatarKey);
    final avatar = int.tryParse(avatarStr ?? '0') ?? 0;
    return GuestProfile(nickname: name, avatarIndex: avatar);
  }

  Future<void> deleteGuestProfile() async {
    await _storage.delete(key: _guestNameKey);
    await _storage.delete(key: _guestAvatarKey);
  }

  // --- Theme Mode ---
  Future<void> saveThemeMode(String mode) async {
    await _storage.write(key: _themeKey, value: mode);
  }

  Future<String?> getThemeMode() async {
    return await _storage.read(key: _themeKey);
  }

  // Clear all credentials
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
