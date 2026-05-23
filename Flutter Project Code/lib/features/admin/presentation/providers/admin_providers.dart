import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/admin_repository.dart';
import '../../../menu/domain/models/menu_item_model.dart';

export '../../data/admin_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Analytics
// ─────────────────────────────────────────────────────────────────────────────

final adminAnalyticsProvider =
    AsyncNotifierProvider<AdminAnalyticsNotifier, AnalyticsData>(
  AdminAnalyticsNotifier.new,
);

final class AdminAnalyticsNotifier extends AsyncNotifier<AnalyticsData> {
  @override
  Future<AnalyticsData> build() => _repo.fetchAnalytics();

  AdminRepository get _repo => ref.read(adminRepositoryProvider);

  Future<void> refresh({String? from, String? to}) async {
    state = const AsyncLoading();
    state =
        await AsyncValue.guard(() => _repo.fetchAnalytics(from: from, to: to));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Admin Orders
// ─────────────────────────────────────────────────────────────────────────────

final adminOrdersProvider =
    AsyncNotifierProvider<AdminOrdersNotifier, List<AdminOrderModel>>(
  AdminOrdersNotifier.new,
);

final class AdminOrdersNotifier extends AsyncNotifier<List<AdminOrderModel>> {
  @override
  Future<List<AdminOrderModel>> build() => _repo.fetchAllOrders();

  AdminRepository get _repo => ref.read(adminRepositoryProvider);

  Future<void> refresh({String? status, String? orderType}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repo.fetchAllOrders(status: status, orderType: orderType),
    );
  }

  Future<void> updateStatus(String orderId, String newStatus) async {
    await _repo.updateOrderStatus(orderId, newStatus);
    state = await AsyncValue.guard(() => _repo.fetchAllOrders());
  }

  /// Admin cancel with optional reason — triggers email to customer.
  Future<void> adminCancel(String orderId, {String? reason}) async {
    await _repo.adminCancelOrder(orderId, reason: reason);
    state = await AsyncValue.guard(() => _repo.fetchAllOrders());
  }

  /// Sends a delay notification email to the customer.
  Future<void> notifyDelay(
    String orderId,
    String message, {
    int? etaMinutes,
  }) async {
    await _repo.notifyDelay(orderId, message, etaMinutes: etaMinutes);
  }

  Future<void> assignRider(String orderId, String riderId) async {
    await _repo.assignRider(orderId, riderId);
    state = await AsyncValue.guard(() => _repo.fetchAllOrders());
  }

  Future<void> setEta(String orderId, int minutes) async {
    await _repo.setEtaMinutes(orderId: orderId, minutes: minutes);
    state = await AsyncValue.guard(() => _repo.fetchAllOrders());
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Menu (admin)
// ─────────────────────────────────────────────────────────────────────────────

final adminMenuProvider =
    AsyncNotifierProvider<AdminMenuNotifier, List<MenuItemModel>>(
  AdminMenuNotifier.new,
);

final class AdminMenuNotifier extends AsyncNotifier<List<MenuItemModel>> {
  @override
  Future<List<MenuItemModel>> build() => _repo.fetchAllMenuItems();

  AdminRepository get _repo => ref.read(adminRepositoryProvider);

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repo.fetchAllMenuItems);
  }

  Future<void> createItem(Map<String, dynamic> payload) async {
    await _repo.createMenuItem(payload);
    state = await AsyncValue.guard(_repo.fetchAllMenuItems);
  }

  Future<void> updateItem(String id, Map<String, dynamic> payload) async {
    await _repo.updateMenuItem(id, payload);
    state = await AsyncValue.guard(_repo.fetchAllMenuItems);
  }

  Future<void> deleteItem(String id) async {
    await _repo.deleteMenuItem(id);
    state = await AsyncValue.guard(_repo.fetchAllMenuItems);
  }

  Future<void> toggleAvailability(MenuItemModel item) async {
    await _repo.updateMenuItem(item.id, {'is_available': !item.isAvailable});
    state = await AsyncValue.guard(_repo.fetchAllMenuItems);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tables
// ─────────────────────────────────────────────────────────────────────────────

final adminTablesProvider =
    AsyncNotifierProvider<AdminTablesNotifier, List<RestaurantTableModel>>(
  AdminTablesNotifier.new,
);

final class AdminTablesNotifier
    extends AsyncNotifier<List<RestaurantTableModel>> {
  @override
  Future<List<RestaurantTableModel>> build() => _repo.fetchTables();

  AdminRepository get _repo => ref.read(adminRepositoryProvider);

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repo.fetchTables);
  }

  Future<void> createTable(Map<String, dynamic> payload) async {
    await _repo.createTable(payload);
    state = await AsyncValue.guard(_repo.fetchTables);
  }

  Future<void> updateTable(String id, Map<String, dynamic> payload) async {
    await _repo.updateTable(id, payload);
    state = await AsyncValue.guard(_repo.fetchTables);
  }

  Future<void> deleteTable(String id) async {
    await _repo.deleteTable(id);
    state = await AsyncValue.guard(_repo.fetchTables);
  }

  Future<void> regenerateQr(String id) async {
    await _repo.regenerateQr(id);
    state = await AsyncValue.guard(_repo.fetchTables);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Riders
// ─────────────────────────────────────────────────────────────────────────────

final adminRidersProvider =
    AsyncNotifierProvider<AdminRidersNotifier, List<RiderModel>>(
  AdminRidersNotifier.new,
);

final class AdminRidersNotifier extends AsyncNotifier<List<RiderModel>> {
  @override
  Future<List<RiderModel>> build() => _repo.fetchRiders();

  AdminRepository get _repo => ref.read(adminRepositoryProvider);

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repo.fetchRiders);
  }

  Future<void> createRider(Map<String, dynamic> payload) async {
    await _repo.createRider(payload);
    state = await AsyncValue.guard(_repo.fetchRiders);
  }

  Future<void> updateRider(String id, Map<String, dynamic> payload) async {
    await _repo.updateRider(id, payload);
    state = await AsyncValue.guard(_repo.fetchRiders);
  }

  Future<void> deleteRider(String id) async {
    await _repo.deleteRider(id);
    state = await AsyncValue.guard(_repo.fetchRiders);
  }

  Future<void> toggleActive(RiderModel rider) async {
    await _repo.updateRider(rider.id, {'is_active': !rider.isActive});
    state = await AsyncValue.guard(_repo.fetchRiders);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Complaints
// ─────────────────────────────────────────────────────────────────────────────

final adminComplaintsProvider =
    AsyncNotifierProvider<AdminComplaintsNotifier, List<ComplaintModel>>(
  AdminComplaintsNotifier.new,
);

final class AdminComplaintsNotifier
    extends AsyncNotifier<List<ComplaintModel>> {
  @override
  Future<List<ComplaintModel>> build() => _repo.fetchComplaints();

  AdminRepository get _repo => ref.read(adminRepositoryProvider);

  Future<void> refresh({String? status, String? priority}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repo.fetchComplaints(status: status, priority: priority),
    );
  }

  Future<void> updateStatus(String id, String newStatus) async {
    await _repo.updateComplaintStatus(id, newStatus);
    state = await AsyncValue.guard(_repo.fetchComplaints);
  }

  /// Resolves a complaint and sends a resolution email to the customer.
  Future<void> resolveComplaint(
    String id,
    String resolutionMessage, {
    String status = 'resolved',
  }) async {
    await _repo.resolveComplaint(id, resolutionMessage, status: status);
    state = await AsyncValue.guard(_repo.fetchComplaints);
  }
}
