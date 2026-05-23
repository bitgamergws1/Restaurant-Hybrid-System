import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/models/menu_item_model.dart';
import '../../../cart/presentation/providers/cart_provider.dart';

class MenuItemCard extends ConsumerWidget {
  const MenuItemCard({
    super.key,
    required this.item,
    this.compact = false,
    this.horizontal = false, // ← NEW: horizontal layout for narrow screens
  });
  final MenuItemModel item;
  final bool compact;
  final bool horizontal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartItems = ref.watch(cartProvider);
    final inCart = cartItems.where((c) => c.menuItemId == item.id);
    final qty = inCart.isEmpty ? 0 : inCart.first.quantity;

    if (horizontal) return _HorizontalCard(item: item, qty: qty, ref: ref);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: qty > 0
              ? AppColors.primary.withValues(alpha: 0.4)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            child: AspectRatio(
              aspectRatio: compact ? 16 / 9 : 4 / 3,
              child: _ItemImage(item: item),
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tags row
                  Row(children: [
                    if (item.isVeg)
                      const _TagBadge(label: 'VEG', color: AppColors.success),
                    if (item.isSpicy) ...[
                      if (item.isVeg) const SizedBox(width: 4),
                      const _TagBadge(label: 'SPICY', color: AppColors.warning),
                    ],
                    const Spacer(),
                    Text(
                      item.category.toUpperCase(),
                      style: GoogleFonts.dmSans(
                          fontSize: 9,
                          color: AppColors.textDisabled,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w600),
                    ),
                  ]),

                  const SizedBox(height: 4),

                  // Name
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.syne(
                      fontSize: compact ? 12 : 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.2,
                    ),
                  ),

                  if (!compact && item.description != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      item.description!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                          fontSize: 10,
                          color: AppColors.textMuted,
                          height: 1.3),
                    ),
                  ],

                  const Spacer(),

                  // Price + Add button
                  Row(
                    children: [
                      Text(
                        'Rs. ${item.price.toStringAsFixed(0)}',
                        style: GoogleFonts.syne(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      const Spacer(),
                      qty == 0
                          ? _AddButton(
                              onTap: () =>
                                  ref.read(cartProvider.notifier).add(item))
                          : _QtyControl(
                              qty: qty,
                              onInc: () =>
                                  ref.read(cartProvider.notifier).add(item),
                              onDec: () => ref
                                  .read(cartProvider.notifier)
                                  .remove(item.id),
                            ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Horizontal card (single-column / narrow screens) ─────────────────────────
class _HorizontalCard extends StatelessWidget {
  const _HorizontalCard(
      {required this.item, required this.qty, required this.ref});
  final MenuItemModel item;
  final int qty;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: qty > 0
              ? AppColors.primary.withValues(alpha: 0.4)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          // ── Left: square image ────────────────────────────────────────────
          ClipRRect(
            borderRadius:
                const BorderRadius.horizontal(left: Radius.circular(13)),
            child: SizedBox(
              width: 100,
              height: 100,
              child: _ItemImage(item: item),
            ),
          ),

          // ── Right: content ────────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top: tags + category
                  Row(children: [
                    if (item.isVeg)
                      const _TagBadge(
                          label: 'VEG', color: AppColors.success, tiny: true),
                    if (item.isSpicy) ...[
                      if (item.isVeg) const SizedBox(width: 3),
                      const _TagBadge(
                          label: 'SPICY', color: AppColors.warning, tiny: true),
                    ],
                    const Spacer(),
                    Text(
                      item.category.toUpperCase(),
                      style: GoogleFonts.dmSans(
                          fontSize: 8,
                          color: AppColors.textDisabled,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w600),
                    ),
                  ]),

                  // Name
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.syne(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),

                  // Description (if exists)
                  if (item.description != null)
                    Text(
                      item.description!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                          fontSize: 10, color: AppColors.textMuted),
                    ),

                  // Bottom: price + button
                  Row(
                    children: [
                      Text(
                        'Rs. ${item.price.toStringAsFixed(0)}',
                        style: GoogleFonts.syne(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      const Spacer(),
                      qty == 0
                          ? _AddButton(
                              onTap: () =>
                                  ref.read(cartProvider.notifier).add(item),
                              small: true,
                            )
                          : _QtyControl(
                              qty: qty,
                              onInc: () =>
                                  ref.read(cartProvider.notifier).add(item),
                              onDec: () => ref
                                  .read(cartProvider.notifier)
                                  .remove(item.id),
                              small: true,
                            ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared image widget (uses CachedNetworkImage) ─────────────────────────────
class _ItemImage extends StatelessWidget {
  const _ItemImage({required this.item});
  final MenuItemModel item;

  @override
  Widget build(BuildContext context) {
    if (item.imageUrl == null || item.imageUrl!.isEmpty) {
      return _PlaceholderImage(item: item);
    }
    return CachedNetworkImage(
      imageUrl: item.imageUrl!,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(
        color: AppColors.surfaceAlt,
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 1.5, color: AppColors.border),
          ),
        ),
      ),
      errorWidget: (_, __, ___) => _PlaceholderImage(item: item),
    );
  }
}

class _PlaceholderImage extends StatelessWidget {
  const _PlaceholderImage({required this.item});
  final MenuItemModel item;

  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.surfaceAlt,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.restaurant_rounded,
                  color: AppColors.border, size: 28),
              const SizedBox(height: 4),
              Text(item.category,
                  style: GoogleFonts.dmSans(
                      fontSize: 9, color: AppColors.textDisabled)),
            ],
          ),
        ),
      );
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap, this.small = false});
  final VoidCallback onTap;
  final bool small;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: small ? 10 : 14, vertical: small ? 5 : 7),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('ADD',
              style: GoogleFonts.syne(
                  fontSize: small ? 10 : 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.5)),
        ),
      );
}

class _QtyControl extends StatelessWidget {
  const _QtyControl(
      {required this.qty,
      required this.onInc,
      required this.onDec,
      this.small = false});
  final int qty;
  final VoidCallback onInc;
  final VoidCallback onDec;
  final bool small;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.primaryTint,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          GestureDetector(
            onTap: onDec,
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: small ? 7 : 10, vertical: small ? 5 : 7),
              child: Icon(Icons.remove_rounded,
                  color: AppColors.primary, size: small ? 14 : 16),
            ),
          ),
          Text('$qty',
              style: GoogleFonts.syne(
                  fontSize: small ? 12 : 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary)),
          GestureDetector(
            onTap: onInc,
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: small ? 7 : 10, vertical: small ? 5 : 7),
              child: Icon(Icons.add_rounded,
                  color: AppColors.primary, size: small ? 14 : 16),
            ),
          ),
        ]),
      );
}

class _TagBadge extends StatelessWidget {
  const _TagBadge(
      {required this.label, required this.color, this.tiny = false});
  final String label;
  final Color color;
  final bool tiny;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(
            horizontal: tiny ? 4 : 6, vertical: tiny ? 1 : 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(label,
            style: GoogleFonts.dmSans(
                fontSize: tiny ? 8 : 9,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.5)),
      );
}
