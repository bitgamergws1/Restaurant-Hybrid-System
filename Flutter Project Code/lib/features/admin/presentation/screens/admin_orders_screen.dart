import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../providers/admin_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AdminOrdersScreen
// All orders with filter bar + status update actions.
//
// Features:
//   1. Confirmation dialog before every status change.
//   2. SnackBar on success and failure.
//   3. Per-card loading indicator while update is in-flight.
//   4. Admin Cancel with reason — sends email to customer via POST /admin/orders/{id}/cancel.
//   5. Notify Delay — sends delay notification email with message + optional ETA.
// ─────────────────────────────────────────────────────────────────────────────

class AdminOrdersScreen extends ConsumerStatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  ConsumerState<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends ConsumerState<AdminOrdersScreen> {
  String _statusFilter = '';
  String _typeFilter = '';

  // Tracks which order is currently being updated so its card shows a spinner.
  String? _updatingOrderId;

  static const _statuses = [
    '',
    'pending',
    'confirmed',
    'preparing',
    'ready',
    'out_for_delivery',
    'delivered',
    'cancelled',
  ];

  static const _types = ['', 'dine_in', 'delivery'];

  // ── Status update ────────────────────────────────────────────────────────

  Future<void> _handleStatusUpdate(
    BuildContext context,
    String orderId,
    String shortId,
    String newStatus,
  ) async {
    // Route cancel through the admin cancel endpoint (sends reason email).
    if (newStatus == 'cancelled') {
      await _handleAdminCancel(context, orderId, shortId);
      return;
    }

    final confirmed = await _showConfirmDialog(context, shortId, newStatus);
    if (!confirmed) return;
    if (!context.mounted) return;

    setState(() => _updatingOrderId = orderId);

    try {
      await ref
          .read(adminOrdersProvider.notifier)
          .updateStatus(orderId, newStatus);

      if (!context.mounted) return;
      _showSnackBar(
        context,
        'Order #$shortId marked as ${_formatStatus(newStatus)}',
        isError: false,
      );
    } catch (_) {
      if (!context.mounted) return;
      _showSnackBar(
        context,
        'Failed to update order #$shortId. Try again.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _updatingOrderId = null);
    }
  }

  // ── Admin Cancel with reason ─────────────────────────────────────────────

  Future<void> _handleAdminCancel(
    BuildContext context,
    String orderId,
    String shortId,
  ) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Row(children: [
          const Icon(Icons.cancel_outlined, size: 20, color: AppColors.error),
          const SizedBox(width: 10),
          Text(
            'Cancel Order #$shortId?',
            style: GoogleFonts.syne(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will cancel the order and notify the customer via email.',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Reason (optional)',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: AppColors.textMuted,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: reasonCtrl,
              maxLines: 2,
              maxLength: 200,
              style: GoogleFonts.dmSans(
                  fontSize: 13, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'e.g. Out of stock, kitchen issue…',
                hintStyle: GoogleFonts.dmSans(
                    fontSize: 13, color: AppColors.textDisabled),
                filled: true,
                fillColor: AppColors.surfaceAlt,
                contentPadding: const EdgeInsets.all(12),
                counterStyle: GoogleFonts.dmSans(
                    fontSize: 10, color: AppColors.textDisabled),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: AppColors.error, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
            child: Text('Back', style: GoogleFonts.dmSans(fontSize: 13)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: Text('Cancel Order',
                style: GoogleFonts.dmSans(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    final reason = reasonCtrl.text.trim();
    reasonCtrl.dispose();

    if (confirmed != true) return;
    if (!context.mounted) return;

    setState(() => _updatingOrderId = orderId);

    try {
      await ref
          .read(adminOrdersProvider.notifier)
          .adminCancel(orderId, reason: reason.isEmpty ? null : reason);

      if (!context.mounted) return;
      _showSnackBar(
        context,
        'Order #$shortId cancelled. Customer notified.',
        isError: false,
      );
    } catch (_) {
      if (!context.mounted) return;
      _showSnackBar(
        context,
        'Failed to cancel order #$shortId. Try again.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _updatingOrderId = null);
    }
  }

  // ── Notify Delay ─────────────────────────────────────────────────────────

  Future<void> _handleNotifyDelay(
    BuildContext context,
    String orderId,
    String shortId,
  ) async {
    final messageCtrl = TextEditingController();
    final etaCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Row(children: [
          const Icon(Icons.schedule_rounded,
              size: 20, color: AppColors.warning),
          const SizedBox(width: 10),
          Text(
            'Notify Delay — #$shortId',
            style: GoogleFonts.syne(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Send a delay notification email to the customer.',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Message *',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: AppColors.textMuted,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: messageCtrl,
              maxLines: 3,
              maxLength: 300,
              style: GoogleFonts.dmSans(
                  fontSize: 13, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText:
                    'e.g. Sorry, the kitchen is running behind on your order…',
                hintStyle: GoogleFonts.dmSans(
                    fontSize: 12, color: AppColors.textDisabled),
                filled: true,
                fillColor: AppColors.surfaceAlt,
                contentPadding: const EdgeInsets.all(12),
                counterStyle: GoogleFonts.dmSans(
                    fontSize: 10, color: AppColors.textDisabled),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: AppColors.warning, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Updated ETA (minutes, optional)',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: AppColors.textMuted,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: etaCtrl,
              keyboardType: TextInputType.number,
              style: GoogleFonts.dmSans(
                  fontSize: 13, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'e.g. 30',
                hintStyle: GoogleFonts.dmSans(
                    fontSize: 13, color: AppColors.textDisabled),
                filled: true,
                fillColor: AppColors.surfaceAlt,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: AppColors.warning, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
            child: Text('Cancel', style: GoogleFonts.dmSans(fontSize: 13)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: Text('Send Notification',
                style: GoogleFonts.dmSans(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    final message = messageCtrl.text.trim();
    final etaText = etaCtrl.text.trim();
    messageCtrl.dispose();
    etaCtrl.dispose();

    if (confirmed != true) return;
    if (!context.mounted) return;

    if (message.isEmpty) {
      _showSnackBar(context, 'Please enter a message.', isError: true);
      return;
    }

    final etaMinutes = etaText.isNotEmpty ? int.tryParse(etaText) : null;

    try {
      await ref.read(adminOrdersProvider.notifier).notifyDelay(
            orderId,
            message,
            etaMinutes: etaMinutes,
          );

      if (!context.mounted) return;
      _showSnackBar(
        context,
        'Delay notification sent for order #$shortId.',
        isError: false,
      );
    } catch (_) {
      if (!context.mounted) return;
      _showSnackBar(
        context,
        'Failed to send notification. Try again.',
        isError: true,
      );
    }
  }

  // ── Confirm dialog (non-cancel status changes) ───────────────────────────

  Future<bool> _showConfirmDialog(
    BuildContext context,
    String shortId,
    String newStatus,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              size: 20,
              color: AppColors.primary,
            ),
            const SizedBox(width: 10),
            Text(
              'Update Status?',
              style: GoogleFonts.syne(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            children: [
              const TextSpan(text: 'Order '),
              TextSpan(
                text: '#$shortId',
                style: GoogleFonts.dmMono(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              const TextSpan(text: ' will be marked as '),
              TextSpan(
                text: _formatStatus(newStatus),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const TextSpan(text: '.'),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textMuted,
            ),
            child: Text(
              'Cancel',
              style: GoogleFonts.dmSans(fontSize: 13),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: Text(
              'Confirm',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showSnackBar(
    BuildContext context,
    String message, {
    required bool isError,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                size: 16,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.dmSans(fontSize: 13, color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: isError ? AppColors.error : const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  // ── Refresh ──────────────────────────────────────────────────────────────

  void _refresh() {
    ref.read(adminOrdersProvider.notifier).refresh(
          status: _statusFilter,
          orderType: _typeFilter,
        );
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(adminOrdersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Header ───────────────────────────────────────────────────────
          _Header(onRefresh: _refresh),

          // ── Filter bar ───────────────────────────────────────────────────
          _FilterBar(
            statusFilter: _statusFilter,
            typeFilter: _typeFilter,
            statuses: _statuses,
            types: _types,
            onStatusChanged: (v) {
              setState(() => _statusFilter = v);
              ref.read(adminOrdersProvider.notifier).refresh(
                    status: v,
                    orderType: _typeFilter,
                  );
            },
            onTypeChanged: (v) {
              setState(() => _typeFilter = v);
              ref.read(adminOrdersProvider.notifier).refresh(
                    status: _statusFilter,
                    orderType: v,
                  );
            },
          ),

          // ── List ─────────────────────────────────────────────────────────
          Expanded(
            child: ordersAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2,
                ),
              ),
              error: (e, _) =>
                  _ErrorView(message: e.toString(), onRetry: _refresh),
              data: (orders) {
                if (orders.isEmpty) {
                  return _EmptyView(filter: _statusFilter);
                }
                return RefreshIndicator(
                  color: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  onRefresh: () async => _refresh(),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: orders.length,
                    itemBuilder: (_, i) {
                      final order = orders[i];
                      return _OrderCard(
                        order: order,
                        isUpdating: _updatingOrderId == order.id,
                        onStatusUpdate: (newStatus) => _handleStatusUpdate(
                          context,
                          order.id,
                          order.shortId,
                          newStatus,
                        ),
                        onNotifyDelay: () => _handleNotifyDelay(
                          context,
                          order.id,
                          order.shortId,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.onRefresh});
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 16, 8),
        child: Row(
          children: [
            Text(
              'Orders',
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
              tooltip: 'Refresh',
              onPressed: onRefresh,
            ),
          ],
        ),
      );
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.statusFilter,
    required this.typeFilter,
    required this.statuses,
    required this.types,
    required this.onStatusChanged,
    required this.onTypeChanged,
  });

  final String statusFilter;
  final String typeFilter;
  final List<String> statuses;
  final List<String> types;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onTypeChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 40,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          children: [
            ...statuses.map(
              (s) => _Chip(
                label: s.isEmpty ? 'All' : _formatStatus(s),
                isActive: statusFilter == s,
                onTap: () => onStatusChanged(s),
              ),
            ),
            const SizedBox(width: 8),
            Container(
                width: 1,
                color: AppColors.border,
                margin: const EdgeInsets.symmetric(vertical: 8)),
            const SizedBox(width: 8),
            ...types.map(
              (t) => _Chip(
                label: t.isEmpty ? 'All Types' : t.replaceAll('_', ' '),
                isActive: typeFilter == t,
                onTap: () => onTypeChanged(t),
                color: AppColors.info,
              ),
            ),
          ],
        ),
      );
}

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
          margin: const EdgeInsets.only(right: 6),
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

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.isUpdating,
    required this.onStatusUpdate,
    required this.onNotifyDelay,
  });

  final AdminOrderModel order;
  final bool isUpdating;
  final ValueChanged<String> onStatusUpdate;
  final VoidCallback onNotifyDelay;

  // Mirrors backend VALID_STATUS_TRANSITIONS — admin can jump to any allowed state,
  // including skipping straight to 'delivered' from any active stage.
  static const _allowedTransitions = <String, List<String>>{
    'pending': ['confirmed', 'delivered', 'cancelled'],
    'confirmed': ['preparing', 'delivered', 'cancelled'],
    'preparing': ['ready', 'delivered'],
    'ready': ['out_for_delivery', 'delivered'],
    'out_for_delivery': ['delivered'],
  };

  // Active orders can receive delay notifications
  static const _delayableStatuses = {
    'pending',
    'confirmed',
    'preparing',
    'ready',
    'out_for_delivery',
  };

  @override
  Widget build(BuildContext context) {
    final transitions = _allowedTransitions[order.status] ?? [];
    final canNotifyDelay = _delayableStatuses.contains(order.status);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUpdating
              ? AppColors.primary.withValues(alpha: 0.4)
              : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          // ── Card body ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: ID + status badge + type badge
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
                    _StatusBadge(status: order.status),
                    const Spacer(),
                    _TypeBadge(isDineIn: order.isDineIn),
                  ],
                ),

                const SizedBox(height: 8),

                // Row 2: time + amount
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded,
                        size: 12, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      _formatTime(order.createdAt),
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '₹${order.totalAmount.toStringAsFixed(2)}',
                      style: GoogleFonts.syne(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),

                // Rider row (if assigned)
                if (order.rider != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.two_wheeler_rounded,
                          size: 12, color: AppColors.info),
                      const SizedBox(width: 4),
                      Text(
                        order.rider!.name,
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: AppColors.info,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // ── Actions ──────────────────────────────────────────
          if (isUpdating)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Updating…',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            )
          else ...[
            // Status update popup
            if (transitions.isNotEmpty)
              Container(
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: PopupMenuButton<String>(
                  onSelected: onStatusUpdate,
                  color: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  offset: const Offset(0, -8),
                  itemBuilder: (_) => transitions.map((status) {
                    final isCancel = status == 'cancelled';
                    final isSkip = status == 'delivered' &&
                        order.status != 'out_for_delivery';
                    final color = isCancel
                        ? AppColors.error
                        : isSkip
                            ? AppColors.success
                            : AppColors.textPrimary;
                    return PopupMenuItem<String>(
                      value: status,
                      child: Row(children: [
                        Icon(_statusIcon(status), size: 16, color: color),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isCancel
                                    ? 'Cancel Order'
                                    : _formatStatus(status),
                                style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: color,
                                ),
                              ),
                              if (isCancel)
                                Text(
                                  'Sends email with reason',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 10,
                                    color: AppColors.textMuted,
                                  ),
                                )
                              else if (isSkip)
                                Text(
                                  'Skip intermediate steps',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 10,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ]),
                    );
                  }).toList(),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.25)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.swap_horiz_rounded,
                          size: 15, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Update Status',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${transitions.length} option${transitions.length > 1 ? "s" : ""}',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.expand_more_rounded,
                          size: 16, color: AppColors.primary),
                    ]),
                  ),
                ),
              ),

            // Notify Delay button — shown for all active orders
            if (canNotifyDelay)
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: transitions.isNotEmpty
                          ? AppColors.border.withValues(alpha: 0.5)
                          : AppColors.border,
                    ),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: GestureDetector(
                  onTap: onNotifyDelay,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.25)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.schedule_send_rounded,
                          size: 15, color: AppColors.warning),
                      const SizedBox(width: 8),
                      Text(
                        'Notify Delay',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.warning,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Email customer',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}';
  }

  IconData _statusIcon(String status) => switch (status) {
        'confirmed' => Icons.thumb_up_outlined,
        'preparing' => Icons.restaurant_rounded,
        'ready' => Icons.done_all_rounded,
        'out_for_delivery' => Icons.two_wheeler_rounded,
        'delivered' => Icons.check_circle_outline_rounded,
        'cancelled' => Icons.cancel_outlined,
        _ => Icons.arrow_forward_rounded,
      };
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
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
          _formatStatus(status),
          style: GoogleFonts.dmSans(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: _color,
          ),
        ),
      );
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.isDineIn});
  final bool isDineIn;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isDineIn
              ? AppColors.warning.withValues(alpha: 0.12)
              : AppColors.info.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          isDineIn ? 'Dine-In' : 'Delivery',
          style: GoogleFonts.dmSans(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isDineIn ? AppColors.warning : AppColors.info,
          ),
        ),
      );
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.filter});
  final String filter;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: AppColors.textDisabled,
            ),
            const SizedBox(height: 12),
            Text(
              filter.isEmpty
                  ? 'No orders yet'
                  : 'No ${_formatStatus(filter)} orders',
              style: GoogleFonts.syne(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              filter.isEmpty
                  ? 'Orders will appear here once placed.'
                  : 'Try a different filter.',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: AppColors.textDisabled,
              ),
            ),
          ],
        ),
      );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded,
                  size: 40, color: AppColors.textDisabled),
              const SizedBox(height: 12),
              Text(
                'Could not load orders',
                style: GoogleFonts.syne(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                message,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: AppColors.textDisabled,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.primary,
                  elevation: 0,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _formatStatus(String s) => s.replaceAll('_', ' ').split(' ').map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + w.substring(1);
    }).join(' ');
