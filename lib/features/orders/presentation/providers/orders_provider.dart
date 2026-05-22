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
