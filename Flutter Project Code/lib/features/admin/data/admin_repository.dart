import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/providers/shared_preferences_provider.dart';
import '../domain/models/admin_order_model.dart';
import '../domain/models/analytics_model.dart';
import '../domain/models/complaint_model.dart';
import '../domain/models/restaurant_table_model.dart';
import '../../menu/domain/models/menu_item_model.dart';

// Re-export domain models so screens can import from one place
export '../domain/models/admin_order_model.dart';
export '../domain/models/analytics_model.dart';
export '../domain/models/complaint_model.dart';
export '../domain/models/restaurant_table_model.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AdminRepository(ApiClient(prefs));
});

// ── Repository ────────────────────────────────────────────────────────────────

final class AdminRepository {
  const AdminRepository(this._client);

  final ApiClient _client;

  // ── Analytics ──────────────────────────────────────────────────────────────

  Future<AnalyticsData> fetchAnalytics({String? from, String? to}) async {
    final params = <String, dynamic>{};
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    final data = await _client.get(
      ApiEndpoints.analytics,
      queryParams: params.isEmpty ? null : params,
    );
    return AnalyticsData.fromJson(data);
  }

  // ── Admin Orders ───────────────────────────────────────────────────────────

  Future<List<AdminOrderModel>> fetchAllOrders({
    String? status,
    String? orderType,
    int limit = 100,
  }) async {
    final params = <String, dynamic>{'limit': limit.toString()};
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (orderType != null && orderType.isNotEmpty) params['type'] = orderType;

    final data = await _client.get(
      ApiEndpoints.adminOrders,
      queryParams: params,
    );
    final list = data['orders'] as List<dynamic>? ?? [];
    return list
        .map((e) => AdminOrderModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    await _client.patch(
      ApiEndpoints.orderStatus(orderId),
      data: {'status': newStatus},
    );
  }

  /// Admin cancels an order with an optional reason — sends cancellation email.
  /// Uses POST /admin/orders/{id}/cancel (different from the status PATCH).
  Future<void> adminCancelOrder(String orderId, {String? reason}) async {
    await _client.post(
      ApiEndpoints.adminCancelOrder(orderId),
      data: {
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
  }

  /// Sends a delay notification email to the customer.
  Future<void> notifyDelay(
    String orderId,
    String message, {
    int? etaMinutes,
  }) async {
    await _client.post(
      ApiEndpoints.notifyDelay(orderId),
      data: {
        'message': message.trim(),
        if (etaMinutes != null) 'eta_minutes': etaMinutes,
      },
    );
  }

  /// Assigns a rider to a delivery order via PATCH /orders/:id/assign-rider
  Future<void> assignRider(String orderId, String riderId) async {
    await _client.patch(
      ApiEndpoints.orderAssignRider(orderId),
      data: {'rider_id': riderId},
    );
  }

  Future<void> setEtaMinutes({
    required String orderId,
    required int minutes,
  }) async {
    await _client.patch(
      ApiEndpoints.orderEta(orderId),
      data: {'eta_minutes': minutes},
    );
  }

  Future<void> setEstimatedTimes({
    required String orderId,
    DateTime? estimatedDeliveryTime,
    DateTime? estimatedTableTime,
  }) async {
    final payload = <String, dynamic>{};
    if (estimatedDeliveryTime != null) {
      payload['estimated_delivery_time'] =
          estimatedDeliveryTime.toUtc().toIso8601String();
    }
    if (estimatedTableTime != null) {
      payload['estimated_table_time'] =
          estimatedTableTime.toUtc().toIso8601String();
    }
    if (payload.isNotEmpty) {
      await _client.patch(ApiEndpoints.orderEta(orderId), data: payload);
    }
  }

  // ── Menu ───────────────────────────────────────────────────────────────────

  Future<List<MenuItemModel>> fetchAllMenuItems() async {
    final data = await _client.get(
      ApiEndpoints.menu,
      queryParams: {'available': 'false'},
    );
    final list = data['items'] as List<dynamic>? ?? [];
    return list
        .map((e) => MenuItemModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<MenuItemModel> createMenuItem(Map<String, dynamic> payload) async {
    final data = await _client.post(ApiEndpoints.menu, data: payload);
    return MenuItemModel.fromJson(data['item'] as Map<String, dynamic>);
  }

  Future<MenuItemModel> updateMenuItem(
      String id, Map<String, dynamic> payload) async {
    final data = await _client.patch(ApiEndpoints.menuItem(id), data: payload);
    return MenuItemModel.fromJson(data['item'] as Map<String, dynamic>);
  }

  Future<void> deleteMenuItem(String id) async {
    await _client.delete(ApiEndpoints.menuItem(id));
  }

  // ── Tables ─────────────────────────────────────────────────────────────────

  Future<List<RestaurantTableModel>> fetchTables() async {
    final data = await _client.get(ApiEndpoints.tables);
    final list = data['tables'] as List<dynamic>? ?? [];
    return list
        .map((e) => RestaurantTableModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<RestaurantTableModel> createTable(Map<String, dynamic> payload) async {
    final data = await _client.post(ApiEndpoints.tables, data: payload);
    return RestaurantTableModel.fromJson(data['table'] as Map<String, dynamic>);
  }

  Future<RestaurantTableModel> updateTable(
      String id, Map<String, dynamic> payload) async {
    final data = await _client.patch(ApiEndpoints.table(id), data: payload);
    return RestaurantTableModel.fromJson(data['table'] as Map<String, dynamic>);
  }

  Future<void> deleteTable(String id) async {
    await _client.delete(ApiEndpoints.table(id));
  }

  Future<RestaurantTableModel> regenerateQr(String id) async {
    final data = await _client.post(ApiEndpoints.tableRegenerateQr(id));
    return RestaurantTableModel.fromJson(data['table'] as Map<String, dynamic>);
  }

  // ── Riders ─────────────────────────────────────────────────────────────────

  Future<List<RiderModel>> fetchRiders({bool activeOnly = false}) async {
    final data = await _client.get(
      ApiEndpoints.riders,
      queryParams: activeOnly ? {'active': 'true'} : null,
    );
    final list = data['riders'] as List<dynamic>? ?? [];
    return list
        .map((e) => RiderModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<RiderModel> createRider(Map<String, dynamic> payload) async {
    final data = await _client.post(ApiEndpoints.riders, data: payload);
    return RiderModel.fromJson(data['rider'] as Map<String, dynamic>);
  }

  Future<RiderModel> updateRider(
      String id, Map<String, dynamic> payload) async {
    final data = await _client.patch(ApiEndpoints.rider(id), data: payload);
    return RiderModel.fromJson(data['rider'] as Map<String, dynamic>);
  }

  Future<void> deleteRider(String id) async {
    await _client.delete(ApiEndpoints.rider(id));
  }

  // ── Complaints ─────────────────────────────────────────────────────────────

  Future<List<ComplaintModel>> fetchComplaints({
    String? status,
    String? priority,
  }) async {
    final params = <String, dynamic>{};
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (priority != null && priority.isNotEmpty) params['priority'] = priority;

    final data = await _client.get(
      ApiEndpoints.complaints,
      queryParams: params.isEmpty ? null : params,
    );
    final list = data['complaints'] as List<dynamic>? ?? [];
    return list
        .map((e) => ComplaintModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateComplaintStatus(String id, String status) async {
    await _client.patch(
      ApiEndpoints.complaintStatus(id),
      data: {'status': status},
    );
  }

  /// Resolves a complaint and sends resolution email to the customer.
  /// [status] must be 'resolved' (default) or 'closed'.
  Future<void> resolveComplaint(
    String id,
    String resolutionMessage, {
    String status = 'resolved',
  }) async {
    await _client.post(
      ApiEndpoints.resolveComplaint(id),
      data: {
        'resolution_message': resolutionMessage.trim(),
        'status': status,
      },
    );
  }

  // ── Users ──────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchUsers() async {
    final data = await _client.get(ApiEndpoints.adminUsers);
    return List<Map<String, dynamic>>.from(data['users'] as List? ?? []);
  }
}
