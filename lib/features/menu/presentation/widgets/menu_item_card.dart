import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/models/menu_item_model.dart';
import '../../../cart/presentation/providers/cart_provider.dart';

class MenuItemCard extends ConsumerWidget {
  const MenuItemCard({super.key, required this.item, this.compact = false});
  final MenuItemModel item;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartItems = ref.watch(cartProvider);
    final inCart = cartItems.where((c) => c.menuItemId == item.id);
    final qty = inCart.isEmpty ? 0 : inCart.first.quantity;

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
              child: item.imageUrl != null
                  ? Image.network(
                      item.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _PlaceholderImage(item: item),
                    )
                  : _PlaceholderImage(item: item),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
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
                  // Category
                  Text(
                    item.category.toUpperCase(),
                    style: GoogleFonts.dmSans(
                        fontSize: 9,
                        color: AppColors.textDisabled,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600),
                  ),
                ]),

                const SizedBox(height: 6),

                // Name
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.syne(
                    fontSize: compact ? 13 : 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.2,
                  ),
                ),

                if (!compact && item.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                        fontSize: 11, color: AppColors.textMuted, height: 1.4),
                  ),
                ],

                const SizedBox(height: 10),

                // Price + Add button
                Row(
                  children: [
                    Text(
                      'Rs. ${item.price.toStringAsFixed(0)}',
                      style: GoogleFonts.syne(
                        fontSize: 16,
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
                            onDec: () =>
                                ref.read(cartProvider.notifier).remove(item.id),
                          ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
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
                  color: AppColors.border, size: 32),
              const SizedBox(height: 4),
              Text(item.category,
                  style: GoogleFonts.dmSans(
                      fontSize: 10, color: AppColors.textDisabled)),
            ],
          ),
        ),
      );
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('ADD',
              style: GoogleFonts.syne(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.5)),
        ),
      );
}

class _QtyControl extends StatelessWidget {
  const _QtyControl(
      {required this.qty, required this.onInc, required this.onDec});
  final int qty;
  final VoidCallback onInc;
  final VoidCallback onDec;

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
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Icon(Icons.remove_rounded,
                  color: AppColors.primary, size: 16),
            ),
          ),
          Text('$qty',
              style: GoogleFonts.syne(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary)),
          GestureDetector(
            onTap: onInc,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child:
                  Icon(Icons.add_rounded, color: AppColors.primary, size: 16),
            ),
          ),
        ]),
      );
}

class _TagBadge extends StatelessWidget {
  const _TagBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(label,
            style: GoogleFonts.dmSans(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.5)),
      );
}
