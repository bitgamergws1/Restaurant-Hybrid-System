import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/route_names.dart';
import '../providers/orders_provider.dart';
import '../../data/orders_repository.dart';

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(orderDetailProvider(orderId));

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
        title: Text('Order Details',
            style: GoogleFonts.syne(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: detailAsync.when(
        data: (detail) => _OrderDetailBody(
          order: detail.order,
          items: detail.items,
          ref: ref,
        ),
        loading: () => const Center(
          child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(AppColors.primary),
              strokeWidth: 2),
        ),
        error: (e, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.textDisabled, size: 48),
            const SizedBox(height: 12),
            Text('Could not load order',
                style: GoogleFonts.syne(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted)),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => ref.invalidate(orderDetailProvider(orderId)),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ]),
        ),
      ),
    );
  }
}

class _OrderDetailBody extends ConsumerStatefulWidget {
  const _OrderDetailBody(
      {required this.order, required this.items, required this.ref});
  final OrderModel order;
  final List<OrderItemModel> items;
  final WidgetRef ref;

  @override
  ConsumerState<_OrderDetailBody> createState() => _OrderDetailBodyState();
}

class _OrderDetailBodyState extends ConsumerState<_OrderDetailBody> {
  bool _sendingInvoice = false;

  Future<void> _sendInvoice() async {
    setState(() => _sendingInvoice = true);
    final result =
        await ref.read(ordersRepositoryProvider).sendInvoice(widget.order.id);
    setState(() => _sendingInvoice = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result.success
          ? 'Invoice sent to your email!'
          : result.error ?? 'Failed'),
      backgroundColor: result.success ? AppColors.success : AppColors.error,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final items = widget.items;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Status hero card ────────────────────────────────────────────────
        _StatusHeroCard(order: order).animate().fadeIn().slideY(begin: -0.05),

        const SizedBox(height: 16),

        // ── Track order button (for active orders) ──────────────────────────
        if (order.isActive)
          _ActionButton(
            icon: Icons.location_on_rounded,
            label: 'Track Order',
            color: AppColors.primary,
            onTap: () => context.goNamed(
              RouteNames.orderTracking,
              pathParameters: {'id': order.id},
            ),
          ).animate().fadeIn(delay: 100.ms),

        if (order.isActive) const SizedBox(height: 10),

        // ── Pay now / Pay at counter (for unpaid orders) ─────────────────
        if (!order.isPaid && !order.isCancelled && order.isDineIn)
          _PayAtCounterBanner(amount: order.totalAmount)
              .animate()
              .fadeIn(delay: 150.ms),

        if (!order.isPaid && !order.isCancelled && !order.isDineIn)
          _ActionButton(
            icon: Icons.payment_rounded,
            label: 'Pay Now  ·  Rs. ${order.totalAmount.toStringAsFixed(2)}',
            color: AppColors.success,
            onTap: () => context.goNamed(
              RouteNames.payment,
              queryParameters: {
                'orderId': order.id,
                'total': order.totalAmount.toString(),
              },
            ),
          ).animate().fadeIn(delay: 150.ms),

        if (!order.isPaid && !order.isCancelled) const SizedBox(height: 10),

        // ── Resend receipt button (auto-sent on payment; this is a resend) ─
        if (order.isPaid)
          _ActionButton(
            icon: Icons.mark_email_read_outlined,
            label: _sendingInvoice ? 'Sending...' : 'Resend Receipt to Email',
            color: AppColors.info,
            onTap: _sendingInvoice ? null : _sendInvoice,
          ).animate().fadeIn(delay: 200.ms),

        const SizedBox(height: 20),

        // ── Order info ──────────────────────────────────────────────────────
        const _SectionHeader('Order Info'),
        const SizedBox(height: 10),
        _InfoCard(children: [
          _InfoRow('Order ID', '#${order.shortId}'),
          _InfoRow('Type', order.isDineIn ? 'Dine-In' : 'Home Delivery'),
          if (order.tableId != null)
            _InfoRow('Table', 'Table ${order.tableId}'),
          _InfoRow('Date', _formatDateTime(order.createdAt)),
          _InfoRow('Payment', order.isPaid ? 'Paid' : 'Pending',
              valueColor: order.isPaid ? AppColors.success : AppColors.warning),
        ]).animate().fadeIn(delay: 200.ms),

        // ── Delivery address ────────────────────────────────────────────────
        if (order.isDelivery && order.deliveryAddress != null) ...[
          const SizedBox(height: 16),
          const _SectionHeader('Delivery Address'),
          const SizedBox(height: 10),
          _InfoCard(children: [
            _AddressBlock(address: order.deliveryAddress!),
          ]).animate().fadeIn(delay: 250.ms),
        ],

        if (order.specialInstructions != null &&
            order.specialInstructions!.isNotEmpty) ...[
          const SizedBox(height: 16),
          const _SectionHeader('Special Instructions'),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(order.specialInstructions!,
                style: GoogleFonts.dmSans(
                    fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
          ).animate().fadeIn(delay: 250.ms),
        ],

        const SizedBox(height: 20),

        // ── Items ───────────────────────────────────────────────────────────
        const _SectionHeader('Items Ordered'),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(children: [
            ...items.asMap().entries.map((e) => Column(children: [
                  _ItemRow(item: e.value),
                  if (e.key < items.length - 1)
                    const Divider(
                        color: AppColors.border, height: 1, indent: 16),
                ])),
          ]),
        ).animate().fadeIn(delay: 300.ms),

        const SizedBox(height: 20),

        // ── Bill summary ────────────────────────────────────────────────────
        const _SectionHeader('Bill Summary'),
        const SizedBox(height: 10),
        _InfoCard(children: [
          _BillRow('Subtotal', 'Rs. ${order.subtotal.toStringAsFixed(2)}'),
          _BillRow('GST (18%)', 'Rs. ${order.gstAmount.toStringAsFixed(2)}'),
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(color: AppColors.border, height: 1)),
          _BillRow(
            'Total',
            'Rs. ${order.totalAmount.toStringAsFixed(2)}',
            isBold: true,
            valueColor: AppColors.primary,
          ),
        ]).animate().fadeIn(delay: 350.ms),
      ]),
    );
  }

  String _formatDateTime(DateTime dt) {
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
    final h = dt.hour > 12
        ? dt.hour - 12
        : dt.hour == 0
            ? 12
            : dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $h:$m $period';
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _StatusHeroCard extends StatelessWidget {
  const _StatusHeroCard({required this.order});
  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final statusInfo = _statusInfo(order.status);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusInfo.color.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(statusInfo.icon, color: statusInfo.color, size: 20),
          const SizedBox(width: 10),
          Text(statusInfo.label,
              style: GoogleFonts.syne(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: statusInfo.color)),
        ]),
        const SizedBox(height: 6),
        Text(statusInfo.description,
            style: GoogleFonts.dmSans(
                fontSize: 13, color: AppColors.textMuted, height: 1.5)),
      ]),
    );
  }

  ({String label, String description, Color color, IconData icon}) _statusInfo(
          String status) =>
      switch (status) {
        'pending' => (
            label: 'Order Placed',
            description:
                'Your order is awaiting confirmation from the restaurant.',
            color: AppColors.warning,
            icon: Icons.hourglass_empty_rounded,
          ),
        'confirmed' => (
            label: 'Order Confirmed',
            description: 'The restaurant has confirmed your order.',
            color: AppColors.info,
            icon: Icons.thumb_up_rounded,
          ),
        'preparing' => (
            label: 'Being Prepared',
            description: 'Your food is being freshly prepared in the kitchen.',
            color: AppColors.primary,
            icon: Icons.soup_kitchen_rounded,
          ),
        'ready' => (
            label: 'Ready!',
            description:
                'Your order is ready. Pick-up or delivery is being arranged.',
            color: AppColors.success,
            icon: Icons.done_all_rounded,
          ),
        'out_for_delivery' => (
            label: 'Out for Delivery',
            description: 'Your order is on its way to you!',
            color: AppColors.info,
            icon: Icons.delivery_dining_rounded,
          ),
        'delivered' => (
            label: 'Delivered',
            description: 'Your order has been delivered. Enjoy your meal!',
            color: AppColors.success,
            icon: Icons.check_circle_rounded,
          ),
        'cancelled' => (
            label: 'Cancelled',
            description: 'This order has been cancelled.',
            color: AppColors.error,
            icon: Icons.cancel_rounded,
          ),
        _ => (
            label: status,
            description: '',
            color: AppColors.textMuted,
            icon: Icons.info_outline_rounded,
          ),
      };
}

class _ActionButton extends StatelessWidget {
  const _ActionButton(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 10),
            Text(label,
                style: GoogleFonts.dmSans(
                    fontSize: 14, fontWeight: FontWeight.w600, color: color)),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color),
          ]),
        ),
      );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Text(label,
      style: GoogleFonts.syne(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
          letterSpacing: 0.5));
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value, {this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Text(label,
              style:
                  GoogleFonts.dmSans(fontSize: 13, color: AppColors.textMuted)),
          const Spacer(),
          Text(value,
              style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? AppColors.textSecondary)),
        ]),
      );
}

class _AddressBlock extends StatelessWidget {
  const _AddressBlock({required this.address});
  final Map<String, dynamic> address;

  @override
  Widget build(BuildContext context) {
    final parts = [
      address['address_line'],
      address['area'],
      address['district'],
      address['state'],
      address['pincode'],
    ].where((v) => v != null && v.toString().isNotEmpty).join(', ');

    return Text(parts,
        style: GoogleFonts.dmSans(
            fontSize: 13, color: AppColors.textSecondary, height: 1.5));
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});
  final OrderItemModel item;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.itemName,
                  style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(
                  'Rs. ${item.unitPrice.toStringAsFixed(0)} × ${item.quantity}',
                  style: GoogleFonts.dmSans(
                      fontSize: 11, color: AppColors.textMuted)),
            ]),
          ),
          Text('Rs. ${item.itemTotal.toStringAsFixed(2)}',
              style: GoogleFonts.syne(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
        ]),
      );
}

class _BillRow extends StatelessWidget {
  const _BillRow(this.label, this.value,
      {this.isBold = false, this.valueColor});
  final String label;
  final String value;
  final bool isBold;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Text(label,
              style: GoogleFonts.dmSans(
                  fontSize: isBold ? 15 : 13,
                  fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
                  color: isBold ? AppColors.textPrimary : AppColors.textMuted)),
          const Spacer(),
          Text(value,
              style: GoogleFonts.syne(
                  fontSize: isBold ? 16 : 13,
                  fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
                  color: valueColor ?? AppColors.textSecondary)),
        ]),
      );
}

// ── Pay-at-counter banner (dine-in, payment pending) ─────────────────────────
class _PayAtCounterBanner extends StatelessWidget {
  const _PayAtCounterBanner({required this.amount});
  final double amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2A1A),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.4),
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.point_of_sale_rounded,
              color: AppColors.success,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pay at Counter',
                  style: GoogleFonts.syne(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Rs. ${amount.toStringAsFixed(2)} due — pay when you\'re done',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
