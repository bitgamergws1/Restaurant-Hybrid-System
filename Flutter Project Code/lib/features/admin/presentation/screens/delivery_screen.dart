import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../providers/admin_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DeliveryScreen — delivery orders only, with rider assignment flow.
// ─────────────────────────────────────────────────────────────────────────────

class DeliveryScreen extends ConsumerStatefulWidget {
  const DeliveryScreen({super.key});

  @override
  ConsumerState<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends ConsumerState<DeliveryScreen> {
  String _statusFilter = '';

  @override
  void initState() {
    super.initState();
    // Load delivery orders and riders in parallel
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(adminOrdersProvider.notifier)
          .refresh(orderType: 'delivery', status: _statusFilter);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(adminOrdersProvider);
    final ridersAsync = ref.watch(adminRidersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
            child: Row(
              children: [
                Text(
                  'Delivery',
                  style: GoogleFonts.syne(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded,
                      color: AppColors.textMuted, size: 20),
                  onPressed: () => ref
                      .read(adminOrdersProvider.notifier)
                      .refresh(orderType: 'delivery', status: _statusFilter),
                ),
              ],
            ),
          ),

          // ── Status filter ─────────────────────────────────────────────
          SizedBox(
            height: 40,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              children: [
                _Chip(
                  label: 'All',
                  isActive: _statusFilter.isEmpty,
                  onTap: () => _applyFilter(''),
                ),
                _Chip(
                  label: 'Needs Rider',
                  isActive: _statusFilter == 'needs_rider',
                  onTap: () => _applyFilter('needs_rider'),
                  color: AppColors.warning,
                ),
                _Chip(
                  label: 'Out for Delivery',
                  isActive: _statusFilter == 'out_for_delivery',
                  onTap: () => _applyFilter('out_for_delivery'),
                  color: AppColors.info,
                ),
                _Chip(
                  label: 'Delivered',
                  isActive: _statusFilter == 'delivered',
                  onTap: () => _applyFilter('delivered'),
                  color: AppColors.success,
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── List ──────────────────────────────────────────────────────
          Expanded(
            child: ordersAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2),
              ),
              error: (e, _) => Center(
                child: Text('Error: $e',
                    style: GoogleFonts.dmSans(color: AppColors.error)),
              ),
              data: (all) {
                List<AdminOrderModel> orders =
                    all.where((o) => o.isDelivery).toList();

                if (_statusFilter == 'needs_rider') {
                  orders = orders.where((o) => o.needsRider).toList();
                } else if (_statusFilter.isNotEmpty) {
                  orders =
                      orders.where((o) => o.status == _statusFilter).toList();
                }

                if (orders.isEmpty) {
                  return Center(
                    child: Text('No delivery orders',
                        style: GoogleFonts.dmSans(color: AppColors.textMuted)),
                  );
                }

                return ridersAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary, strokeWidth: 2),
                  ),
                  error: (_, __) => ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: orders.length,
                    itemBuilder: (_, i) => _DeliveryCard(
                      order: orders[i],
                      riders: const [],
                      onAssign: (_, __) {},
                      onStatusUpdate: (s) => ref
                          .read(adminOrdersProvider.notifier)
                          .updateStatus(orders[i].id, s),
                    ),
                  ),
                  data: (riders) => ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: orders.length,
                    itemBuilder: (_, i) => _DeliveryCard(
                      order: orders[i],
                      riders: riders.where((r) => r.isActive).toList(),
                      onAssign: (orderId, riderId) => ref
                          .read(adminOrdersProvider.notifier)
                          .assignRider(orderId, riderId),
                      onStatusUpdate: (s) => ref
                          .read(adminOrdersProvider.notifier)
                          .updateStatus(orders[i].id, s),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _applyFilter(String f) {
    setState(() => _statusFilter = f);
    if (f == 'needs_rider') {
      ref.read(adminOrdersProvider.notifier).refresh(orderType: 'delivery');
    } else {
      ref
          .read(adminOrdersProvider.notifier)
          .refresh(orderType: 'delivery', status: f);
    }
  }
}

// ── Widgets ──────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.color = AppColors.primary,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? color.withValues(alpha: 0.15) : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive ? color.withValues(alpha: 0.5) : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: isActive ? color : AppColors.textTertiary,
            ),
          ),
        ),
      );
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({
    required this.order,
    required this.riders,
    required this.onAssign,
    required this.onStatusUpdate,
  });

  final AdminOrderModel order;
  final List<RiderModel> riders;
  final void Function(String orderId, String riderId) onAssign;
  final ValueChanged<String> onStatusUpdate;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: order.needsRider
                ? AppColors.warning.withValues(alpha: 0.4)
                : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '#${order.shortId}',
                  style: GoogleFonts.dmMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                _Badge(status: order.status),
                const Spacer(),
                Text(
                  '₹${order.totalAmount.toStringAsFixed(0)}',
                  style: GoogleFonts.syne(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            if (order.deliveryAddress != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 12, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      order.deliveryAddressLine,
                      style: GoogleFonts.dmSans(
                          fontSize: 11, color: AppColors.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (order.rider != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.two_wheeler_rounded,
                      size: 12, color: AppColors.info),
                  const SizedBox(width: 4),
                  Text(
                    '${order.rider!.name} · ${order.rider!.phone}',
                    style:
                        GoogleFonts.dmSans(fontSize: 11, color: AppColors.info),
                  ),
                ],
              ),
            ],
            if (order.needsRider && riders.isNotEmpty) ...[
              const SizedBox(height: 10),
              _AssignRiderButton(
                order: order,
                riders: riders,
                onAssign: onAssign,
              ),
            ],
            if (order.status == 'ready' && order.hasRider) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => onStatusUpdate('out_for_delivery'),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.info.withValues(alpha: 0.1),
                    foregroundColor: AppColors.info,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                      side: BorderSide(
                          color: AppColors.info.withValues(alpha: 0.3)),
                    ),
                  ),
                  child: Text(
                    'Mark Out for Delivery',
                    style: GoogleFonts.dmSans(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
}

class _AssignRiderButton extends StatelessWidget {
  const _AssignRiderButton({
    required this.order,
    required this.riders,
    required this.onAssign,
  });

  final AdminOrderModel order;
  final List<RiderModel> riders;
  final void Function(String orderId, String riderId) onAssign;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => showModalBottomSheet(
            context: context,
            backgroundColor: AppColors.surface,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            builder: (_) => _RiderPickerSheet(
              riders: riders,
              onPick: (riderId) {
                Navigator.pop(context);
                onAssign(order.id, riderId);
              },
            ),
          ),
          icon: const Icon(Icons.two_wheeler_rounded, size: 14),
          label: Text(
            'Assign Rider',
            style:
                GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.warning,
            side: BorderSide(color: AppColors.warning.withValues(alpha: 0.4)),
            padding: const EdgeInsets.symmetric(vertical: 8),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ),
      );
}

class _RiderPickerSheet extends StatelessWidget {
  const _RiderPickerSheet({required this.riders, required this.onPick});

  final List<RiderModel> riders;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Select Rider',
              style: GoogleFonts.syne(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          ...riders.map(
            (r) => ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primaryTint,
                child: Text(
                  r.name[0].toUpperCase(),
                  style: GoogleFonts.syne(
                      color: AppColors.primary, fontWeight: FontWeight.w700),
                ),
              ),
              title: Text(r.name,
                  style: GoogleFonts.dmSans(color: AppColors.textPrimary)),
              subtitle: Text(r.phone,
                  style: GoogleFonts.dmSans(
                      color: AppColors.textMuted, fontSize: 12)),
              onTap: () => onPick(r.id),
            ),
          ),
          const SizedBox(height: 16),
        ],
      );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.status});
  final String status;

  Color get _color => switch (status) {
        'pending' => AppColors.warning,
        'confirmed' => AppColors.info,
        'preparing' => AppColors.primary,
        'ready' => AppColors.success,
        'out_for_delivery' => AppColors.info,
        'delivered' => AppColors.success,
        'cancelled' => AppColors.error,
        _ => AppColors.textMuted,
      };

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          status.replaceAll('_', ' '),
          style: GoogleFonts.dmSans(
              fontSize: 10, fontWeight: FontWeight.w600, color: _color),
        ),
      );
}
