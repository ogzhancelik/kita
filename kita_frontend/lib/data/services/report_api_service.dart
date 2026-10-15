import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';

class ReportApiService {
  final ApiClient _client;

  ReportApiService([ApiClient? client]) : _client = client ?? ApiClient();

  /// Submits an in-game or system-wide moderation report.
  Future<void> submitReport({
    required String reason,
    String? description,
    String? matchId,
    String? reportedUsername,
  }) async {
    await _client.dio.post(
      ApiConstants.reports,
      data: {
        'reason': reason,
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
        if (matchId != null && matchId.trim().isNotEmpty)
          'match_id': matchId.trim(),
        if (reportedUsername != null && reportedUsername.trim().isNotEmpty)
          'reported_username': reportedUsername.trim(),
      },
    );
  }
}
