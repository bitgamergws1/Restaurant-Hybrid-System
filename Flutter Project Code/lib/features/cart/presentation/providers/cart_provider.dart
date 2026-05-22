import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../menu/domain/models/menu_item_model.dart';

// ── CartItem ─────────────────────────────────────────────────────────────────

final class CartItem {
  const CartItem({
    required this.menuItemId,
    required this.name,
    required this.unitPrice,
    required this.quantity,
    this.imageUrl,
    this.category = '',
  });

  final String menuItemId;
  final String name;
  final double unitPrice;
  final int quantity;
  final String? imageUrl;
  final String category;

  double get itemTotal => unitPrice * quantity;

  CartItem copyWith({int? quantity}) => CartItem(
        menuItemId: menuItemId,
        name: name,
        unitPrice: unitPrice,
        quantity: quantity ?? this.quantity,
        imageUrl: imageUrl,
        category: category,
      );

  @override
  bool operator ==(Object other) =>
      other is CartItem && other.menuItemId == menuItemId;

  @override
  int get hashCode => menuItemId.hashCode;
}

// ── CartNotifier ──────────────────────────────────────────────────────────────

final class CartNotifier extends Notifier<List<CartItem>> {
  @override
  List<CartItem> build() => [];

  void add(MenuItemModel item) {
    final idx = state.indexWhere((c) => c.menuItemId == item.id);
    if (idx >= 0) {
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == idx)
            state[i].copyWith(quantity: state[i].quantity + 1)
          else
            state[i],
      ];
    } else {
      state = [
        ...state,
        CartItem(
          menuItemId: item.id,
          name: item.name,
          unitPrice: item.price,
          quantity: 1,
          imageUrl: item.imageUrl,
          category: item.category,
        ),
      ];
    }
  }

  void remove(String menuItemId) {
    final idx = state.indexWhere((c) => c.menuItemId == menuItemId);
    if (idx < 0) return;
    final item = state[idx];
    if (item.quantity <= 1) {
      state = state.where((c) => c.menuItemId != menuItemId).toList();
    } else {
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == idx)
            state[i].copyWith(quantity: state[i].quantity - 1)
          else
            state[i],
      ];
    }
  }

  void removeAll(String menuItemId) {
    state = state.where((c) => c.menuItemId != menuItemId).toList();
  }

  void clear() => state = [];
}

final cartProvider = NotifierProvider<CartNotifier, List<CartItem>>(
  CartNotifier.new,
);

// ── Derived providers ─────────────────────────────────────────────────────────

final cartSubtotalProvider = Provider<double>((ref) {
  return ref.watch(cartProvider).fold(0.0, (sum, i) => sum + i.itemTotal);
});

final cartGstProvider = Provider<double>((ref) {
  return ref.watch(cartSubtotalProvider) * 0.18;
});

final cartTotalProvider = Provider<double>((ref) {
  final sub = ref.watch(cartSubtotalProvider);
  final gst = ref.watch(cartGstProvider);
  return sub + gst;
});

final cartItemCountProvider = Provider<int>((ref) {
  return ref.watch(cartProvider).fold(0, (s, i) => s + i.quantity);
});
