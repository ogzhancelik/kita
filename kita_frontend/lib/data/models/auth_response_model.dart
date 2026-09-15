import 'user_model.dart';

class AuthResponse {
  final String token;
  final UserProfile user;

  const AuthResponse({
    required this.token,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'] as String? ?? '',
      user: UserProfile.fromJson(json['user'] as Map<String, dynamic>? ?? {}),
    );
  }
}
