import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/providers/shared_preferences_provider.dart';

final class AiRepository {
  const AiRepository(this._client);
  final ApiClient _client;

  Future<({bool success, String? recommendation, String? error})>
      getRecommendation(String prompt) async {
    try {
      final data = await _client
          .post(ApiEndpoints.aiRecommend, data: {'prompt': prompt});
      return (
        success: true,
        recommendation: data['recommendation'] as String?,
        error: null,
      );
    } on ApiException catch (e) {
      return (success: false, recommendation: null, error: e.message);
    } catch (_) {
      return (
        success: false,
        recommendation: null,
        error: 'AI service is temporarily unavailable.'
      );
    }
  }

  Future<({bool success, Map<String, dynamic>? triage, String? error})>
      triageComplaint({
    required String text,
    String? userId,
    String? orderId,
  }) async {
    try {
      final data = await _client.post(ApiEndpoints.aiTriage, data: {
        'raw_text': text,
        if (userId != null) 'user_id': userId,
        if (orderId != null) 'order_id': orderId,
      });
      return (
        success: true,
        triage: data['triage'] as Map<String, dynamic>?,
        error: null,
      );
    } on ApiException catch (e) {
      return (success: false, triage: null, error: e.message);
    } catch (_) {
      return (
        success: false,
        triage: null,
        error: 'Could not submit complaint. Please try again.'
      );
    }
  }
}

final aiRepositoryProvider = Provider<AiRepository>((ref) {
  return AiRepository(ref.watch(apiClientProvider));
});
