import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/network/connectivity_service.dart';
import '../../core/storage/secure_storage_service.dart';
import '../../data/models/user_model.dart';
import '../../data/services/auth_api_service.dart';
import '../widgets/common/guest_guard_dialog.dart';

enum AuthState {
  initial,
  checking,
  offline,
  authenticated,
  guest,
  unauthenticated,
}

class AuthProvider extends ChangeNotifier {
  final AuthApiService _apiService;
  final SecureStorageService _storage;
  final ConnectivityService _connectivity;

  AuthState _state = AuthState.initial;
  bool _isLoading = false;
  UserProfile? _currentUser;
  GuestProfile? _guestProfile;
  String? _token;

  AuthProvider({
    AuthApiService? apiService,
    SecureStorageService? storage,
    ConnectivityService? connectivity,
  })  : _apiService = apiService ?? AuthApiService(),
        _storage = storage ?? SecureStorageService(),
        _connectivity = connectivity ?? ConnectivityService();

  AuthState get state => _state;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _state == AuthState.authenticated;
  bool get isGuest => _state == AuthState.guest;
  bool get isOffline => _state == AuthState.offline;

  UserProfile? get currentUser => _currentUser;
  GuestProfile? get guestProfile => _guestProfile;
  String? get token => _token;

  String get displayName {
    if (isAuthenticated && _currentUser != null) {
      return _currentUser!.username;
    }
    if (isGuest && _guestProfile != null) {
      return _guestProfile!.nickname;
    }
    return 'Player';
  }

  int get avatarIndex {
    if (isGuest && _guestProfile != null) {
      return _guestProfile!.avatarIndex;
    }
    return 0;
  }

  // --- Step 1 & 2 & 3 Initialization Flow ---
  Future<void> checkInitialState() async {
    _state = AuthState.checking;
    notifyListeners();

    // 1. Connectivity check
    final hasNet = await _connectivity.hasInternet();
    if (!hasNet) {
      _state = AuthState.offline;
      notifyListeners();
      return;
    }

    // 2. Token / Session check
    final storedToken = await _storage.getToken();
    if (storedToken != null && storedToken.isNotEmpty) {
      _token = storedToken;
      ApiClient.currentToken = storedToken;
      try {
        final profile = await _apiService.getMe();
        _currentUser = profile;
        await _storage.saveUser(profile);
        _state = AuthState.authenticated;
        notifyListeners();
        return;
      } catch (e) {
        // If 401 or token invalid, clear it
        final cached = await _storage.getUser();
        if (cached != null) {
          _currentUser = cached;
          _state = AuthState.authenticated;
          notifyListeners();
          return;
        }
        await _storage.deleteToken();
        ApiClient.currentToken = null;
      }
    }

    // 3. Guest profile check
    try {
      final savedGuest = await _storage.getGuestProfile();
      if (savedGuest != null) {
        _guestProfile = savedGuest;
        _state = AuthState.guest;
        notifyListeners();
        return;
      }
    } catch (_) {}

    // 4. No active token or guest -> Welcome screen (Sign in / Register / Guest)
    _state = AuthState.unauthenticated;
    notifyListeners();
  }

  // --- Refresh Profile ---
  Future<void> refreshProfile() async {
    if (!isAuthenticated || _token == null) return;
    try {
      final profile = await _apiService.getMe();
      _currentUser = profile;
      await _storage.saveUser(profile);
      notifyListeners();
    } catch (e) {
      debugPrint('[AuthProvider] Failed to refresh profile: $e');
    }
  }

  // --- Login ---
  Future<bool> login(String usernameOrEmail, String password) async {
    _setLoading(true);
    try {
      final res = await _apiService.login(
        usernameOrEmail: usernameOrEmail,
        password: password,
      );
      _token = res.token;
      ApiClient.currentToken = res.token;
      _currentUser = res.user;
      _guestProfile = null;
      await _storage.saveToken(res.token);
      await _storage.saveUser(res.user);
      await _storage.deleteGuestProfile();

      _state = AuthState.authenticated;
      _setLoading(false);
      return true;
    } catch (_) {
      _setLoading(false);
      return false;
    }
  }

  // --- Register ---
  Future<bool> register(String username, String email, String password) async {
    _setLoading(true);
    try {
      final res = await _apiService.register(
        username: username,
        email: email,
        password: password,
      );
      _token = res.token;
      ApiClient.currentToken = res.token;
      _currentUser = res.user;
      _guestProfile = null;
      await _storage.saveToken(res.token);
      await _storage.saveUser(res.user);
      await _storage.deleteGuestProfile();

      _state = AuthState.authenticated;
      _setLoading(false);
      return true;
    } catch (_) {
      _setLoading(false);
      return false;
    }
  }

  // --- Continue as Guest (Gartic Phone style) ---
  Future<void> continueAsGuest(String nickname, int avatarIndex) async {
    final guest = GuestProfile(
      nickname: nickname.trim().isEmpty ? 'Guest${DateTime.now().millisecondsSinceEpoch % 10000}' : nickname.trim(),
      avatarIndex: avatarIndex,
    );
    _guestProfile = guest;
    _currentUser = null;
    _token = null;
    ApiClient.currentToken = null;
    try {
      await _storage.saveGuestProfile(guest.nickname, guest.avatarIndex);
    } catch (_) {}
    _state = AuthState.guest;
    notifyListeners();
  }

  // --- Logout ---
  Future<void> logout() async {
    _setLoading(true);
    ApiClient.currentToken = null;
    await _storage.deleteToken();
    await _storage.deleteUser();
    await _storage.deleteGuestProfile();
    _currentUser = null;
    _guestProfile = null;
    _token = null;
    _state = AuthState.unauthenticated;
    _setLoading(false);
  }

  // --- Feature Guard for Guests ---
  // Blocks guests from performing actions like sending friend requests or direct match invites
  void guardAction(BuildContext context, VoidCallback onAllowed) {
    if (isGuest) {
      showDialog(
        context: context,
        builder: (ctx) => const GuestGuardDialog(),
      );
    } else {
      onAllowed();
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
