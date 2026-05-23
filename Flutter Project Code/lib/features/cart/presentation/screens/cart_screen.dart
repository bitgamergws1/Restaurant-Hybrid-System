import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/route_names.dart';
import '../providers/cart_provider.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(cartProvider);
    final subtotal = ref.watch(cartSubtotalProvider);
    final gst = ref.watch(cartGstProvider);
    final total = ref.watch(cartTotalProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 18),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Your Cart',
          style: GoogleFonts.syne(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary),
        ),
        actions: [
          if (items.isNotEmpty)
            TextButton(
              onPressed: () => ref.read(cartProvider.notifier).clear(),
              child: Text('Clear',
                  style:
                      GoogleFonts.dmSans(fontSize: 13, color: AppColors.error)),
            ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: items.isEmpty
          ? _EmptyCart(onBrowse: () => context.goNamed(RouteNames.menu))
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) => _CartItemTile(
                      item: items[i],
                      onInc: () => ref
                          .read(cartProvider.notifier)
                          .add(_mockMenuItem(items[i])),
                      onDec: () => ref
                          .read(cartProvider.notifier)
                          .remove(items[i].menuItemId),
                      onRemove: () => ref
                          .read(cartProvider.notifier)
                          .removeAll(items[i].menuItemId),
                    ).animate().fadeIn(delay: (i * 50).ms).slideX(begin: -0.05),
                  ),
                ),
                _BillSummary(
                  subtotal: subtotal,
                  gst: gst,
                  total: total,
                  onCheckout: () => context.pushNamed(RouteNames.checkout),
                ),
              ],
            ),
    );
  }

  // We only need id + name + price + imageUrl + category to re-add
  dynamic _mockMenuItem(CartItem item) {
    // CartNotifier.add takes MenuItemModel; we call remove+add by menuItemId
    // so for increment we pass a lightweight adapter
    return _CartMenuItemAdapter(item);
  }
}

// Lightweight adapter so CartNotifier.add works from CartScreen
class _CartMenuItemAdapter {
  const _CartMenuItemAdapter(this._item);
  final CartItem _item;
  String get id => _item.menuItemId;
  String get name => _item.name;
  double get price => _item.unitPrice;
  String? get imageUrl => _item.imageUrl;
  String get category => _item.category;
  String? get description => null;
  bool get isAvailable => true;
  List<String> get tags => [];
  int get sortOrder => 0;
  String? get subcategory => null;
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyCart extends StatelessWidget {
  const _EmptyCart({required this.onBrowse});
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: AppColors.surfaceAlt,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shopping_cart_outlined,
                color: AppColors.textDisabled, size: 36),
          ),
          const SizedBox(height: 20),
          Text('Your cart is empty',
              style: GoogleFonts.syne(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text('Add dishes from the menu to get started',
              style:
                  GoogleFonts.dmSans(fontSize: 13, color: AppColors.textMuted)),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: onBrowse,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('Browse Menu',
                  style: GoogleFonts.syne(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ),
        ]).animate().fadeIn().slideY(begin: 0.1),
      );
}

// ── Cart item tile ────────────────────────────────────────────────────────────

class _CartItemTile extends StatelessWidget {
  const _CartItemTile({
    required this.item,
    required this.onInc,
    required this.onDec,
    required this.onRemove,
  });
  final CartItem item;
  final VoidCallback onInc;
  final VoidCallback onDec;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 60,
              height: 60,
              child: item.imageUrl != null
                  ? Image.network(item.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imgPlaceholder())
                  : _imgPlaceholder(),
            ),
          ),
          const SizedBox(width: 14),
          // Name + price
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.syne(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text('Rs. ${item.unitPrice.toStringAsFixed(0)} each',
                  style: GoogleFonts.dmSans(
                      fontSize: 11, color: AppColors.textMuted)),
            ]),
          ),
          const SizedBox(width: 12),
          // Controls
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            // Remove
            GestureDetector(
              onTap: onRemove,
              child: const Icon(Icons.close_rounded,
                  color: AppColors.textDisabled, size: 16),
            ),
            const SizedBox(height: 8),
            // Qty stepper
            Container(
              decoration: BoxDecoration(
                color: AppColors.primaryTint,
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                GestureDetector(
                  onTap: onDec,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    child: Icon(Icons.remove_rounded,
                        color: AppColors.primary, size: 14),
                  ),
                ),
                Text('${item.quantity}',
                    style: GoogleFonts.syne(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary)),
                GestureDetector(
                  onTap: onInc,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    child: Icon(Icons.add_rounded,
                        color: AppColors.primary, size: 14),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 6),
            Text('Rs. ${item.itemTotal.toStringAsFixed(0)}',
                style: GoogleFonts.syne(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
          ]),
        ]),
      );

  Widget _imgPlaceholder() => Container(
        color: AppColors.surfaceAlt,
        child: const Icon(Icons.restaurant_rounded,
            color: AppColors.border, size: 24),
      );
}

// ── Bill summary + checkout CTA ───────────────────────────────────────────────

class _BillSummary extends StatelessWidget {
  const _BillSummary({
    required this.subtotal,
    required this.gst,
    required this.total,
    required this.onCheckout,
  });
  final double subtotal;
  final double gst;
  final double total;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Column(children: [
            _row('Subtotal', 'Rs. ${subtotal.toStringAsFixed(2)}',
                AppColors.textSecondary),
            const SizedBox(height: 8),
            _row('GST (18%)', 'Rs. ${gst.toStringAsFixed(2)}',
                AppColors.textMuted),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(color: AppColors.border, height: 1),
            ),
            Row(children: [
              Text('Total',
                  style: GoogleFonts.syne(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
              const Spacer(),
              Text('Rs. ${total.toStringAsFixed(2)}',
                  style: GoogleFonts.syne(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary)),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: onCheckout,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text('Proceed to Checkout',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.syne(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
            ),
          ]),
        ),
      );

  Widget _row(String label, String value, Color valueColor) => Row(
        children: [
          Text(label,
              style:
                  GoogleFonts.dmSans(fontSize: 13, color: AppColors.textMuted)),
          const Spacer(),
          Text(value,
              style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: valueColor)),
        ],
      );
}
