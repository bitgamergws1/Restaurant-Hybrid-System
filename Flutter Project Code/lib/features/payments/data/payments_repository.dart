import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/providers/shared_preferences_provider.dart';

final class PaymentsRepository {
  const PaymentsRepository(this._client);
  final ApiClient _client;

  Future<({bool success, String? error, Map<String, dynamic>? payment})>
      verifyPayment({
    required String orderId,
    required String razorpayPaymentId,
    required String razorpayOrderId,
  }) async {
    try {
      final data = await _client.post(ApiEndpoints.paymentVerify, data: {
        'order_id': orderId,
        'razorpay_payment_id': razorpayPaymentId,
        'razorpay_order_id': razorpayOrderId,
      });
      return (
        success: true,
        error: null,
        payment: data['payment'] as Map<String, dynamic>?
      );
    } on ApiException catch (e) {
      return (success: false, error: e.message, payment: null);
    } catch (_) {
      return (
        success: false,
        error: 'Payment verification failed. Please try again.',
        payment: null,
      );
    }
  }

  Future<({bool success, String? error})> sendInvoice(String orderId) async {
    try {
      await _client.post(ApiEndpoints.invoice(orderId));
      return (success: true, error: null);
    } on ApiException catch (e) {
      return (success: false, error: e.message);
    } catch (_) {
      return (success: false, error: 'Could not send invoice.');
    }
  }
}

final paymentsRepositoryProvider = Provider<PaymentsRepository>((ref) {
  return PaymentsRepository(ref.watch(apiClientProvider));
});
