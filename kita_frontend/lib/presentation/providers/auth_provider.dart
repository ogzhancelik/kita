import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/connectivity_service.dart';
import '../../core/storage/secure_storage_service.dart';
import '../../data/models/user_model.dart';
import '../../data/services/auth_api_service.dart';
import '../../data/services/user_api_service.dart';
import '../../data/services/websocket_service.dart';
import '../widgets/common/guest_guard_dialog.dart';

enum AuthState {
  initial,
  checking,
  offline,
  authenticated,
  guest,
  unauthenticated,
}

class AuthProvider extends ChangeNotifier with WidgetsBindingObserver {
  final AuthApiService _apiService;
  final UserApiService _userApiService;
  final SecureStorageService _storage;
  final ConnectivityService _connectivity;

  AuthState _state = AuthState.initial;
  bool _isLoading = false;
  UserProfile? _currentUser;
  GuestProfile? _guestProfile;
  String? _token;

  bool _isOffline = false;
  bool _isServerDown = false;
  bool _isRetryingConnection = false;
  bool _isAppInBackground = false;
  StreamSubscription<bool>? _connectivitySubscription;

  AuthProvider({
    AuthApiService? apiService,
    UserApiService? userApiService,
    SecureStorageService? storage,
    ConnectivityService? connectivity,
  })  : _apiService = apiService ?? AuthApiService(),
        _userApiService = userApiService ?? UserApiService(),
        _storage = storage ?? SecureStorageService(),
        _connectivity = connectivity ?? ConnectivityService() {
    WidgetsBinding.instance.addObserver(this);
    _initReachabilityListeners();
  }

  void _initReachabilityListeners() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((hasNet) async {
      if (_isAppInBackground) {
        // Suppress background OS network drops from mutating UI while hidden
        return;
      }
      if (!hasNet) {
        _isOffline = true;
        _isServerDown = false;
        notifyListeners();
      } else {
        _isOffline = false;
        final isHealthy = await ConnectivityService.checkApiHealth(ApiConstants.baseUrl);
        _isServerDown = !isHealthy;
        notifyListeners();
      }
    });

    ApiClient.onServerStatusChanged = (down) {
      if (_isAppInBackground) {
        return;
      }
      if (down) {
        _connectivity.hasInternet().then((hasNet) {
          if (hasNet) {
            setServerDown(true);
          } else {
            setIsOffline(true);
          }
        });
      } else {
        setServerDown(false);
      }
    };

    WebSocketService.instance.onConnectionFailed = () async {
      if (_isAppInBackground) {
        return;
      }
      final hasNet = await _connectivity.hasInternet();
      if (hasNet) {
        final isHealthy = await ConnectivityService.checkApiHealth(ApiConstants.baseUrl);
        if (!isHealthy) {
          setServerDown(true);
        }
      } else {
        setIsOffline(true);
      }
    };

    WebSocketService.instance.onConnected = () {
      setServerDown(false);
    };
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  bool get isAppInBackground => _isAppInBackground;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isBg = state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive;

    if (isBg) {
      _isAppInBackground = true;
      debugPrint('[AuthProvider] App moved to background/hidden ($state)');
    } else if (state == AppLifecycleState.resumed) {
      final wasBg = _isAppInBackground;
      _isAppInBackground = false;
      debugPrint('[AuthProvider] App resumed to foreground');
      if (wasBg) {
        _handleAppResumed();
      }
    }
  }

  Future<void> _handleAppResumed() async {
    // If user was offline intentionally or in unauthenticated welcome screen, leave as is.
    if (_state == AuthState.offline || _state == AuthState.unauthenticated) {
      return;
    }

    // Default optimistic: Keep online UI layout, don't flash offline menu
    _isOffline = false;
    _isServerDown = false;
    notifyListeners();

    // 1. Proactively reconnect WebSocket immediately (don't wait for dormant backoff timers)
    WebSocketService.instance.reconnectNow();

    // 2. Gentle network interface check
    final hasNet = await _connectivity.hasInternet();
    if (!hasNet) {
      _isOffline = true;
      notifyListeners();
      return;
    }

    // 3. Silent health / profile refresh
    if (isAuthenticated && _token != null) {
      refreshProfile();
    }
  }

  AuthState get state => _state;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _state == AuthState.authenticated;
  bool get isGuest => _state == AuthState.guest;
  bool get isOffline => _isOffline || _state == AuthState.offline;
  bool get isServerDown => _isServerDown;
  bool get isOnlineUnavailable => isOffline || _isServerDown;
  bool get isRetryingConnection => _isRetryingConnection;

  void setServerDown(bool value) {
    if (_isServerDown != value) {
      _isServerDown = value;
      notifyListeners();
    }
  }

  void setIsOffline(bool value) {
    if (_isOffline != value) {
      _isOffline = value;
      notifyListeners();
    }
  }

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
    if (_currentUser != null) {
      return _currentUser!.avatarIndex;
    }
    return 0;
  }

  Future<void> setAvatarIndex(int index) async {
    if (isGuest && _guestProfile != null) {
      _guestProfile = GuestProfile(
        nickname: _guestProfile!.nickname,
        avatarIndex: index,
      );
      try {
        await _storage.saveGuestProfile(_guestProfile!.nickname, index);
      } catch (_) {}
      notifyListeners();
    } else if (isAuthenticated && _currentUser != null) {
      _currentUser = _currentUser!.copyWith(avatarIndex: index);
      notifyListeners();
      try {
        await _storage.saveUser(_currentUser!);
      } catch (_) {}

      try {
        final updated = await _userApiService.updateAvatar(index);
        _currentUser = updated;
        await _storage.saveUser(updated);
        notifyListeners();
      } catch (e) {
        debugPrint('[AuthProvider] Failed to persist avatar update: $e');
      }
    }
  }

  int _initCheckGeneration = 0;

  // --- Step 1 & 2 & 3 Initialization Flow ---
  Future<void> checkInitialState() async {
    final currentGen = ++_initCheckGeneration;
    _state = AuthState.checking;
    notifyListeners();

    // 1. Connectivity check
    final hasNet = await _connectivity.hasInternet();
    if (_initCheckGeneration != currentGen) return;
    _isOffline = !hasNet;

    // 1b. Server reachability check
    if (!hasNet) {
      _isServerDown = false;
    } else {
      final isHealthy = await ConnectivityService.checkApiHealth(ApiConstants.baseUrl);
      if (_initCheckGeneration != currentGen) return;
      _isServerDown = !isHealthy;
    }

    // 2. Token / Session check
    final storedToken = await _storage.getToken();
    if (_initCheckGeneration != currentGen) return;
    if (storedToken != null && storedToken.isNotEmpty) {
      _token = storedToken;
      ApiClient.currentToken = storedToken;
      if (hasNet && !_isServerDown) {
        try {
          final profile = await _apiService.getMe(silent: true);
          if (_initCheckGeneration != currentGen) return;
          _currentUser = profile;
          await _storage.saveUser(profile);
          _state = AuthState.authenticated;
          _isServerDown = false;
          notifyListeners();
          return;
        } catch (e) {
          if (_initCheckGeneration != currentGen) return;
          final isUnauthorized = e is DioException && (e.response?.statusCode == 401);
          if (!isUnauthorized) {
            _isServerDown = true;
            final cached = await _storage.getUser();
            if (_initCheckGeneration != currentGen) return;
            if (cached != null) {
              _currentUser = cached;
              _state = AuthState.authenticated;
              notifyListeners();
              return;
            }
          } else {
            await _storage.deleteToken();
            await _storage.deleteUser();
            _token = null;
            _currentUser = null;
            ApiClient.currentToken = null;
          }
        }
      } else {
        // Offline or server down with token: load cached user profile if available
        final cached = await _storage.getUser();
        if (_initCheckGeneration != currentGen) return;
        if (cached != null) {
          _currentUser = cached;
          _state = AuthState.authenticated;
          notifyListeners();
          return;
        }
      }
    }

    if (_initCheckGeneration != currentGen) return;

    // 3. Check if a guest profile exists in storage (load for later if user chooses "Continue as Guest")
    try {
      final savedGuest = await _storage.getGuestProfile();
      if (_initCheckGeneration != currentGen) return;
      if (savedGuest != null) {
        _guestProfile = savedGuest;
      }
    } catch (_) {}

    if (_initCheckGeneration != currentGen) return;

    // 4. Not logged in (whether online or offline) -> Welcome screen (Sign in / Register / Guest)
    _state = AuthState.unauthenticated;
    notifyListeners();
  }

  // --- Continue Offline Directly ---
  Future<void> continueOffline() async {
    final currentGen = ++_initCheckGeneration;
    _isOffline = true;
    _isServerDown = false;

    // Check if token and cached user exist
    final storedToken = await _storage.getToken();
    if (_initCheckGeneration != currentGen) return;
    if (storedToken != null && storedToken.isNotEmpty) {
      final cached = await _storage.getUser();
      if (_initCheckGeneration != currentGen) return;
      if (cached != null) {
        _token = storedToken;
        ApiClient.currentToken = storedToken;
        _currentUser = cached;
        _state = AuthState.authenticated;
        notifyListeners();
        return;
      }
    }

    // Check if guest profile exists
    try {
      final savedGuest = await _storage.getGuestProfile();
      if (_initCheckGeneration != currentGen) return;
      if (savedGuest != null) {
        _guestProfile = savedGuest;
        _state = AuthState.guest;
        notifyListeners();
        return;
      }
    } catch (_) {}

    if (_initCheckGeneration != currentGen) return;

    // Fallback default guest profile
    _guestProfile = const GuestProfile(nickname: 'Guest', avatarIndex: 0);
    _state = AuthState.guest;
    notifyListeners();
  }

  // --- Manual Retry Connection ---
  Future<bool> retryConnection() async {
    _isRetryingConnection = true;
    notifyListeners();

    final hasNet = await _connectivity.hasInternet();
    _isOffline = !hasNet;

    if (!hasNet) {
      _isServerDown = false;
      _isRetryingConnection = false;
      notifyListeners();
      return false;
    }

    final isHealthy = await ConnectivityService.checkApiHealth(ApiConstants.baseUrl);
    _isServerDown = !isHealthy;

    if (!isHealthy) {
      _isRetryingConnection = false;
      notifyListeners();
      return false;
    }

    // Backend is reachable and internet is available!
    if (_state == AuthState.guest) {
      _isRetryingConnection = false;
      notifyListeners();
      return true;
    }

    await checkInitialState();
    _isRetryingConnection = false;
    notifyListeners();
    return true;
  }

  // --- Refresh Profile ---
  Future<void> refreshProfile() async {
    if (!isAuthenticated || _token == null) return;
    try {
      final profile = await _apiService.getMe();
      _currentUser = profile;
      await _storage.saveUser(profile);
      _isServerDown = false;
      notifyListeners();
    } catch (e) {
      if (e is DioException && (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          (e.response?.statusCode != null && e.response!.statusCode! >= 500))) {
        final hasNet = await _connectivity.hasInternet();
        if (hasNet) {
          _isServerDown = true;
          notifyListeners();
        }
      }
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
    await _storage.deleteToken();
    await _storage.deleteUser();
    try {
      await _storage.saveGuestProfile(guest.nickname, guest.avatarIndex);
    } catch (_) {}
    _state = AuthState.guest;
    notifyListeners();
  }

  // --- Logout ---
  Future<void> logout() async {
    _setLoading(true);
    WebSocketService.instance.disconnect();
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
