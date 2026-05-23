import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/orders_repository.dart';
import '../../domain/models/order_model.dart';

export '../../domain/models/order_model.dart';

// ── User orders list ──────────────────────────────────────────────────────────

final userOrdersProvider =
    FutureProvider.autoDispose<List<OrderModel>>((ref) async {
  final auth = ref.watch(authNotifierProvider);
  if (auth is! AuthAuthenticated) return [];
  return ref.watch(ordersRepositoryProvider).getUserOrders(auth.user.id);
});

// ── Single order + items ──────────────────────────────────────────────────────

typedef OrderDetail = ({
  OrderModel order,
  List<OrderItemModel> items,
});

final orderDetailProvider =
    FutureProvider.autoDispose.family<OrderDetail, String>((ref, id) async {
  final result = await ref.watch(ordersRepositoryProvider).getOrder(id);
  if (!result.success || result.order == null) {
    throw Exception(result.error ?? 'Order not found');
  }
  return (order: result.order!, items: result.items);
});

// ── Create order state ────────────────────────────────────────────────────────

sealed class CreateOrderState {
  const CreateOrderState();
}

class CreateOrderIdle extends CreateOrderState {
  const CreateOrderIdle();
}

class CreateOrderLoading extends CreateOrderState {
  const CreateOrderLoading();
}

class CreateOrderSuccess extends CreateOrderState {
  const CreateOrderSuccess(this.order);
  final OrderModel order;
}

class CreateOrderError extends CreateOrderState {
  const CreateOrderError(this.message);
  final String message;
}

final class CreateOrderNotifier extends AutoDisposeNotifier<CreateOrderState> {
  @override
  CreateOrderState build() => const CreateOrderIdle();

  Future<void> placeOrder({
    required String orderType,
    required List<Map<String, dynamic>> items,
    String? tableId,
    String? pincode,
    String? addressLine,
    Map<String, double>? coordinates,
    String? specialInstructions,
  }) async {
    state = const CreateOrderLoading();
    final result = await ref.read(ordersRepositoryProvider).createOrder(
          orderType: orderType,
          items: items,
          tableId: tableId,
          pincode: pincode,
          addressLine: addressLine,
          coordinates: coordinates,
          specialInstructions: specialInstructions,
        );
    if (result.success && result.order != null) {
      state = CreateOrderSuccess(result.order!);
    } else {
      state = CreateOrderError(result.error ?? 'Failed to place order');
    }
  }

  void reset() => state = const CreateOrderIdle();
}

final createOrderProvider =
    AutoDisposeNotifierProvider<CreateOrderNotifier, CreateOrderState>(
  CreateOrderNotifier.new,
);

// ── Cancel order state ────────────────────────────────────────────────────────
// Used by order_detail_screen to show cancel button state.
// Auto-disposed so each detail screen gets fresh state.

sealed class CancelOrderState {
  const CancelOrderState();
}

class CancelOrderIdle extends CancelOrderState {
  const CancelOrderIdle();
}

class CancelOrderLoading extends CancelOrderState {
  const CancelOrderLoading();
}

class CancelOrderSuccess extends CancelOrderState {
  const CancelOrderSuccess(this.order);
  final OrderModel order;
}

class CancelOrderError extends CancelOrderState {
  const CancelOrderError(this.message);
  final String message;
}

final class CancelOrderNotifier
    extends AutoDisposeFamilyNotifier<CancelOrderState, String> {
  @override
  CancelOrderState build(String orderId) => const CancelOrderIdle();

  Future<void> cancel() async {
    if (state is CancelOrderLoading) return;
    state = const CancelOrderLoading();

    final result = await ref.read(ordersRepositoryProvider).cancelOrder(arg);

    if (result.success && result.order != null) {
      // Invalidate the detail provider so the UI refreshes with new status.
      ref.invalidate(orderDetailProvider(arg));
      // Also refresh the orders list if it's alive.
      ref.invalidate(userOrdersProvider);
      state = CancelOrderSuccess(result.order!);
    } else {
      state = CancelOrderError(result.error ?? 'Failed to cancel order');
    }
  }

  void reset() => state = const CancelOrderIdle();
}

/// Family provider — one instance per order ID.
final cancelOrderProvider = NotifierProvider.autoDispose
    .family<CancelOrderNotifier, CancelOrderState, String>(
  CancelOrderNotifier.new,
);
