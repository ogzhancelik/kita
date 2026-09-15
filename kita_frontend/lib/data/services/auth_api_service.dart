import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../models/auth_response_model.dart';
import '../models/user_model.dart';

class AuthApiService {
  final ApiClient _client;

  AuthApiService([ApiClient? client]) : _client = client ?? ApiClient();

  Future<AuthResponse> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final response = await _client.dio.post(
      ApiConstants.register,
      data: {
        'username': username.trim(),
        'email': email.trim().toLowerCase(),
        'password': password,
      },
    );

    return AuthResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AuthResponse> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    final response = await _client.dio.post(
      ApiConstants.login,
      data: {
        'username_or_email': usernameOrEmail.trim(),
        'password': password,
      },
    );

    return AuthResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<UserProfile> getMe() async {
    final response = await _client.dio.get(ApiConstants.me);
    return UserProfile.fromJson(response.data as Map<String, dynamic>);
  }
}
