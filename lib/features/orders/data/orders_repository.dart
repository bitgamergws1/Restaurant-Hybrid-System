import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/providers/shared_preferences_provider.dart';
import '../domain/models/order_model.dart';

final class OrdersRepository {
  const OrdersRepository(this._client);
  final ApiClient _client;

  // ── Create order ────────────────────────────────────────────────────────────

  Future<({bool success, OrderModel? order, String? error})> createOrder({
    required String orderType,
    required List<Map<String, dynamic>> items,
    String? tableId,
    String? pincode,
    String? addressLine,
    Map<String, double>? coordinates,
    String? specialInstructions,
  }) async {
    try {
      final body = <String, dynamic>{
        'order_type': orderType,
        'items': items,
        if (tableId != null) 'table_id': tableId,
        if (pincode != null) 'pincode': pincode,
        if (addressLine != null) 'address_line': addressLine,
        if (coordinates != null) 'coordinates': coordinates,
        if (specialInstructions != null && specialInstructions.isNotEmpty)
          'special_instructions': specialInstructions,
      };
      final data = await _client.post(ApiEndpoints.orders, data: body);
      final order = OrderModel.fromJson(data['order'] as Map<String, dynamic>);
      return (success: true, order: order, error: null);
    } on ApiException catch (e) {
      return (success: false, order: null, error: e.message);
    } catch (_) {
      return (
        success: false,
        order: null,
        error: 'Could not place order. Please try again.'
      );
    }
  }

  // ── Get single order ────────────────────────────────────────────────────────

  Future<
      ({
        bool success,
        OrderModel? order,
        List<OrderItemModel> items,
        String? error
      })> getOrder(String orderId) async {
    try {
      final data = await _client.get(ApiEndpoints.order(orderId));

      final order = OrderModel.fromJson(data['order'] as Map<String, dynamic>);

      final items = (data['items'] as List<dynamic>? ?? [])
          .map((e) => OrderItemModel.fromJson(e as Map<String, dynamic>))
          .toList();

      return (
        success: true,
        order: order,
        items: items,
        error: null,
      );
    } on ApiException catch (e) {
      return (
        success: false,
        order: null,
        items: <OrderItemModel>[],
        error: e.message,
      );
    } catch (_) {
      return (
        success: false,
        order: null,
        items: <OrderItemModel>[],
        error: 'Could not load order.',
      );
    }
  }

  // ── Get user orders ─────────────────────────────────────────────────────────

  Future<List<OrderModel>> getUserOrders(String userId) async {
    final data = await _client.get(ApiEndpoints.userOrders(userId));
    return (data['orders'] as List<dynamic>? ?? [])
        .map((e) => OrderModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Send invoice ────────────────────────────────────────────────────────────

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

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  return OrdersRepository(ref.watch(apiClientProvider));
});
