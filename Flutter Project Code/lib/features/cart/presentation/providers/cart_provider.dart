import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../core/providers/shared_preferences_provider.dart';
import '../../../menu/domain/models/menu_item_model.dart';

// ── Persistence key ───────────────────────────────────────────────────────────

const _kCartKey = 'spice_route_cart_v1';

// ── CartItem ──────────────────────────────────────────────────────────────────

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

  Map<String, dynamic> toJson() => {
        'menuItemId': menuItemId,
        'name': name,
        'unitPrice': unitPrice,
        'quantity': quantity,
        'imageUrl': imageUrl,
        'category': category,
      };

  factory CartItem.fromJson(Map<String, dynamic> j) => CartItem(
        menuItemId: j['menuItemId'] as String,
        name: j['name'] as String,
        unitPrice: (j['unitPrice'] as num).toDouble(),
        quantity: j['quantity'] as int,
        imageUrl: j['imageUrl'] as String?,
        category: j['category'] as String? ?? '',
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
  List<CartItem> build() {
    // Load persisted cart on startup.
    return _load(ref.read(sharedPreferencesProvider));
  }

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  // ── Persistence helpers ─────────────────────────────────────────────────

  static List<CartItem> _load(SharedPreferences prefs) {
    final raw = prefs.getString(_kCartKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  void _save() {
    _prefs.setString(
      _kCartKey,
      jsonEncode(state.map((e) => e.toJson()).toList()),
    );
  }

  // ── Mutations ────────────────────────────────────────────────────────────

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
    _save();
  }

  /// Add by raw fields (used from AI dish cards where we have a MenuItemModel).
  void addFromModel(MenuItemModel item) => add(item);

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
    _save();
  }

  void removeAll(String menuItemId) {
    state = state.where((c) => c.menuItemId != menuItemId).toList();
    _save();
  }

  void clear() {
    state = [];
    _save();
  }
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
