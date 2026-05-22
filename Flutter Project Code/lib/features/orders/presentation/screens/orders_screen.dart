import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/route_names.dart';
import '../providers/orders_provider.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(userOrdersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: AppColors.background,
            floating: true,
            snap: true,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Text('My Orders',
                style: GoogleFonts.syne(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded,
                    color: AppColors.textMuted, size: 20),
                onPressed: () => ref.invalidate(userOrdersProvider),
              ),
            ],
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1, color: AppColors.border),
            ),
          ),
          ordersAsync.when(
            data: (orders) {
              if (orders.isEmpty) {
                return SliverFillRemaining(
                  child: _EmptyOrders(
                      onBrowse: () => context.goNamed(RouteNames.menu)),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _OrderCard(
                        order: orders[i],
                        onTap: () => context.goNamed(
                          RouteNames.orderDetail,
                          pathParameters: {'id': orders[i].id},
                        ),
                      )
                          .animate()
                          .fadeIn(delay: (i * 50).ms)
                          .slideY(begin: 0.06),
                    ),
                    childCount: orders.length,
                  ),
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(AppColors.primary),
                    strokeWidth: 2),
              ),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.wifi_off_rounded,
                      color: AppColors.textDisabled, size: 48),
                  const SizedBox(height: 12),
                  Text('Could not load orders',
                      style: GoogleFonts.syne(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted)),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () => ref.invalidate(userOrdersProvider),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Retry'),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary),
                  ),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders({required this.onBrowse});
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
                color: AppColors.surfaceAlt, shape: BoxShape.circle),
            child: const Icon(Icons.receipt_long_outlined,
                color: AppColors.textDisabled, size: 36),
          ),
          const SizedBox(height: 20),
          Text('No orders yet',
              style: GoogleFonts.syne(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text('Your order history will appear here',
              style:
                  GoogleFonts.dmSans(fontSize: 13, color: AppColors.textMuted)),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: onBrowse,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12)),
              child: Text('Explore Menu',
                  style: GoogleFonts.syne(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ),
        ]).animate().fadeIn().slideY(begin: 0.1),
      );
}

// ── Order card ────────────────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});
  final OrderModel order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusInfo = _statusInfo(order.status);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header row
          Row(children: [
            // Order type badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: order.isDineIn
                    ? AppColors.primaryTint
                    : AppColors.info.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: order.isDineIn
                      ? AppColors.primary.withValues(alpha: 0.3)
                      : AppColors.info.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                order.isDineIn ? 'DINE-IN' : 'DELIVERY',
                style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: order.isDineIn ? AppColors.primary : AppColors.info),
              ),
            ),
            const Spacer(),
            // Status chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusInfo.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(statusInfo.label,
                  style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: statusInfo.color)),
            ),
          ]),
          const SizedBox(height: 12),
          // Order ID + date
          Row(children: [
            Text('#${order.shortId}',
                style: GoogleFonts.syne(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3)),
            const Spacer(),
            Text(_formatDate(order.createdAt),
                style: GoogleFonts.dmSans(
                    fontSize: 11, color: AppColors.textMuted)),
          ]),
          const SizedBox(height: 4),
          Text('Rs. ${order.totalAmount.toStringAsFixed(2)}',
              style: GoogleFonts.syne(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary)),
          const Divider(color: AppColors.border, height: 20),
          // Payment status + arrow
          Row(children: [
            Icon(
              order.isPaid ? Icons.check_circle_rounded : Icons.pending_rounded,
              size: 14,
              color: order.isPaid ? AppColors.success : AppColors.warning,
            ),
            const SizedBox(width: 6),
            Text(
              order.isPaid ? 'Paid' : 'Payment Pending',
              style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: order.isPaid ? AppColors.success : AppColors.warning,
                  fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Text('View Details',
                style: GoogleFonts.dmSans(
                    fontSize: 12, color: AppColors.textMuted)),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 12, color: AppColors.textDisabled),
          ]),
        ]),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]}, ${dt.year}';
  }

  ({String label, Color color}) _statusInfo(String status) => switch (status) {
        'pending' => (label: 'PENDING', color: AppColors.warning),
        'confirmed' => (label: 'CONFIRMED', color: AppColors.info),
        'preparing' => (label: 'PREPARING', color: AppColors.primary),
        'ready' => (label: 'READY', color: AppColors.success),
        'out_for_delivery' => (label: 'ON THE WAY', color: AppColors.info),
        'delivered' => (label: 'DELIVERED', color: AppColors.success),
        'cancelled' => (label: 'CANCELLED', color: AppColors.error),
        _ => (label: status.toUpperCase(), color: AppColors.textMuted),
      };
}
