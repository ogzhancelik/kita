import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import '../constants/api_constants.dart';
import '../feedback/toast_service.dart';
import '../storage/secure_storage_service.dart';

class ApiClient {
  static String? currentToken;

  static ApiClient? _instance;

  late final Dio dio;
  final SecureStorageService _storage;
  void Function()? onUnauthorized;

  ApiClient._internal({
    SecureStorageService? storage,
    this.onUnauthorized,
  }) : _storage = storage ?? SecureStorageService() {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.addAll([
      _AuthInterceptor(_storage),
      _ErrorInterceptor(_storage, onUnauthorized: () => onUnauthorized?.call()),
    ]);
  }

  /// Returns the shared singleton instance.
  /// [onUnauthorized] is only used during the first creation.
  factory ApiClient({
    SecureStorageService? storage,
    void Function()? onUnauthorized,
  }) {
    _instance ??= ApiClient._internal(
      storage: storage,
      onUnauthorized: onUnauthorized,
    );
    if (onUnauthorized != null) {
      _instance!.onUnauthorized = onUnauthorized;
    }
    return _instance!;
  }

  /// The shared singleton instance (same as calling the factory).
  static ApiClient get instance => ApiClient();

  void updateBaseUrl(String newUrl) {
    String clean = newUrl.trim();
    while (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    if (!clean.startsWith('http://') && !clean.startsWith('https://')) {
      clean = 'https://$clean';
    }
    ApiConstants.baseUrl = clean;
    dio.options.baseUrl = clean;
  }
}

class _AuthInterceptor extends Interceptor {
  final SecureStorageService _storage;

  _AuthInterceptor(this._storage);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    String? token = ApiClient.currentToken;
    if (token == null || token.isEmpty) {
      token = await _storage.getToken();
      if (token != null && token.isNotEmpty) {
        ApiClient.currentToken = token;
      }
    }
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    return handler.next(options);
  }
}

class _ErrorInterceptor extends Interceptor {
  final SecureStorageService _storage;
  final void Function()? onUnauthorized;

  _ErrorInterceptor(this._storage, {this.onUnauthorized});

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    String messageKey = 'errUnknown';

    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError) {
      messageKey = 'errNetworkError';
    } else if (err.response != null) {
      final statusCode = err.response?.statusCode;
      final data = err.response?.data;

      if (data is Map<String, dynamic> && data.containsKey('code')) {
        final code = data['code']?.toString() ?? '';
        messageKey = _mapErrorCodeToKey(code);
      } else if (statusCode == 401) {
        messageKey = 'errUnauthorized';
      } else if (statusCode == 404) {
        messageKey = 'errNotFound';
      } else if (statusCode != null && statusCode >= 500) {
        messageKey = 'errInternalServer';
      }

      if (statusCode == 401) {
        ApiClient.currentToken = null;
        _storage.deleteToken();
        _storage.deleteUser();
        onUnauthorized?.call();
      }
    }

    // Attempt translation via easy_localization
    String translated;
    try {
      translated = messageKey.tr();
    } catch (_) {
      translated = messageKey;
    }

    // Show floating toast if not marked silent and not an unauthorized / session error
    final isSilent = err.requestOptions.extra['silent'] == true;
    final isAuthError = messageKey == 'errUnauthorized' || messageKey == 'errTokenExpired';
    if (!isSilent && !isAuthError) {
      KitaToast.error(translated);
    }

    return handler.next(err);
  }

  String _mapErrorCodeToKey(String code) {
    switch (code) {
      case 'ERR_VALIDATION_FAILED':
        return 'errValidationFailed';
      case 'ERR_MISSING_FIELD':
        return 'errMissingField';
      case 'ERR_INVALID_FORMAT':
        return 'errInvalidFormat';
      case 'ERR_UNAUTHORIZED':
        return 'errUnauthorized';
      case 'ERR_INVALID_CREDENTIALS':
        return 'errInvalidCredentials';
      case 'ERR_TOKEN_EXPIRED':
        return 'errTokenExpired';
      case 'ERR_USER_ALREADY_EXISTS':
        return 'errUserAlreadyExists';
      case 'ERR_NOT_FOUND':
        return 'errNotFound';
      case 'ERR_MATCH_NOT_FOUND':
        return 'errMatchNotFound';
      case 'ERR_ALREADY_IN_MATCH':
        return 'errAlreadyInMatch';
      case 'ERR_ALREADY_IN_QUEUE':
        return 'errAlreadyInQueue';
      case 'ERR_INVALID_MOVE':
        return 'errInvalidMove';
      case 'ERR_NOT_YOUR_TURN':
        return 'errNotYourTurn';
      case 'ERR_INVALID_MESSAGE':
        return 'errInvalidMessage';
      case 'ERR_INTERNAL_SERVER':
        return 'errInternalServer';
      case 'ERR_UNKNOWN_MESSAGE':
        return 'errUnknownMessage';
      default:
        return 'errUnknown';
    }
  }
}
