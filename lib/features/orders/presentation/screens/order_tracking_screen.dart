import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../providers/orders_provider.dart';

class OrderTrackingScreen extends ConsumerStatefulWidget {
  const OrderTrackingScreen({super.key, required this.orderId});
  final String orderId;

  @override
  ConsumerState<OrderTrackingScreen> createState() =>
      _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends ConsumerState<OrderTrackingScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Auto-refresh every 20 s for live updates
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      ref.invalidate(orderDetailProvider(widget.orderId));
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(orderDetailProvider(widget.orderId));

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
        title: Text('Track Order',
            style: GoogleFonts.syne(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: AppColors.textMuted, size: 20),
            onPressed: () =>
                ref.invalidate(orderDetailProvider(widget.orderId)),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: detailAsync.when(
        data: (detail) => _TrackingBody(order: detail.order),
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
            Text('Could not load tracking info',
                style: GoogleFonts.syne(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted)),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () =>
                  ref.invalidate(orderDetailProvider(widget.orderId)),
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

// ── Timeline step data ────────────────────────────────────────────────────────

const _allSteps = [
  _TrackStep(
    status: 'pending',
    label: 'Order Placed',
    description: 'Your order has been received',
    icon: Icons.receipt_rounded,
  ),
  _TrackStep(
    status: 'confirmed',
    label: 'Confirmed',
    description: 'Restaurant accepted your order',
    icon: Icons.thumb_up_rounded,
  ),
  _TrackStep(
    status: 'preparing',
    label: 'Preparing',
    description: 'Being freshly cooked in the kitchen',
    icon: Icons.soup_kitchen_rounded,
  ),
  _TrackStep(
    status: 'ready',
    label: 'Ready',
    description: 'Order is ready for pickup / dispatch',
    icon: Icons.check_circle_rounded,
  ),
  _TrackStep(
    status: 'out_for_delivery',
    label: 'On the Way',
    description: 'Your delivery is heading to you',
    icon: Icons.delivery_dining_rounded,
  ),
  _TrackStep(
    status: 'delivered',
    label: 'Delivered',
    description: 'Enjoy your meal!',
    icon: Icons.celebration_rounded,
  ),
];

class _TrackStep {
  const _TrackStep({
    required this.status,
    required this.label,
    required this.description,
    required this.icon,
  });
  final String status;
  final String label;
  final String description;
  final IconData icon;
}

// ── Tracking body ─────────────────────────────────────────────────────────────

class _TrackingBody extends StatelessWidget {
  const _TrackingBody({required this.order});
  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    if (order.isCancelled) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cancel_rounded, color: AppColors.error, size: 64),
          const SizedBox(height: 16),
          Text('Order Cancelled',
              style: GoogleFonts.syne(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text('This order has been cancelled.',
              style:
                  GoogleFonts.dmSans(fontSize: 13, color: AppColors.textMuted)),
        ]).animate().fadeIn(),
      );
    }

    final currentStep = order.statusStep;
    final relevantSteps = order.isDineIn
        ? _allSteps.where((s) => s.status != 'out_for_delivery').toList()
        : _allSteps;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        // ── Status hero ────────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.15),
                AppColors.surface,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Column(children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primaryTint,
                shape: BoxShape.circle,
                border:
                    Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
              ),
              child: Icon(_currentIcon(order.status),
                  color: AppColors.primary, size: 28),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(end: 1.08, duration: 900.ms),
            const SizedBox(height: 16),
            Text(_currentLabel(order.status),
                style: GoogleFonts.syne(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            Text(_currentDescription(order.status),
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                    fontSize: 13, color: AppColors.textMuted, height: 1.5)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('Order #${order.shortId}',
                  style: GoogleFonts.syne(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                      letterSpacing: 0.5)),
            ),
          ]),
        ).animate().fadeIn().slideY(begin: -0.06),

        const SizedBox(height: 16),

        // ── ETA card (shown when admin has set an ETA) ─────────────────
        if (order.eta != null)
          _EtaCard(eta: order.eta!, isDineIn: order.isDineIn)
              .animate()
              .fadeIn(delay: 100.ms)
              .slideY(begin: 0.04),

        if (order.eta != null) const SizedBox(height: 16),

        // ── Rider card (shown when delivery + rider assigned) ──────────
        if (order.isDelivery && order.hasRider)
          _RiderCard(order: order)
              .animate()
              .fadeIn(delay: 150.ms)
              .slideY(begin: 0.04),

        if (order.isDelivery && order.hasRider) const SizedBox(height: 16),

        // ── Timeline ───────────────────────────────────────────────────
        Text('Order Timeline',
            style: GoogleFonts.syne(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
                letterSpacing: 0.5)),
        const SizedBox(height: 16),

        ...relevantSteps.asMap().entries.map((e) {
          final idx = e.key;
          final step = e.value;
          final isDone = idx <= currentStep;
          final isCurrent = idx == currentStep;
          final isLast = idx == relevantSteps.length - 1;

          return _TimelineStep(
            step: step,
            isDone: isDone,
            isCurrent: isCurrent,
            isLast: isLast,
          )
              .animate()
              .fadeIn(delay: (idx * 80).ms)
              .slideX(begin: -0.04, delay: (idx * 80).ms);
        }),
      ]),
    );
  }

  IconData _currentIcon(String status) => switch (status) {
        'pending' => Icons.hourglass_empty_rounded,
        'confirmed' => Icons.thumb_up_rounded,
        'preparing' => Icons.soup_kitchen_rounded,
        'ready' => Icons.check_circle_rounded,
        'out_for_delivery' => Icons.delivery_dining_rounded,
        'delivered' => Icons.celebration_rounded,
        _ => Icons.info_outline_rounded,
      };

  String _currentLabel(String status) => switch (status) {
        'pending' => 'Order Placed',
        'confirmed' => 'Order Confirmed',
        'preparing' => 'Being Prepared',
        'ready' => 'Ready for Pickup',
        'out_for_delivery' => 'Out for Delivery',
        'delivered' => 'Delivered!',
        _ => status,
      };

  String _currentDescription(String status) => switch (status) {
        'pending' => 'Waiting for restaurant to confirm...',
        'confirmed' => 'Your order has been accepted!',
        'preparing' => 'The chef is cooking your food now',
        'ready' => 'Your order is packed and ready',
        'out_for_delivery' => 'Your delivery partner is on the way',
        'delivered' => 'We hope you enjoy your meal!',
        _ => '',
      };
}

// ── ETA card ──────────────────────────────────────────────────────────────────

class _EtaCard extends StatelessWidget {
  const _EtaCard({required this.eta, required this.isDineIn});
  final DateTime eta;
  final bool isDineIn;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final diff = eta.difference(now);
    final isPast = diff.isNegative;

    final label = isDineIn ? 'Est. Table Time' : 'Est. Delivery Time';
    final minutesLeft = diff.inMinutes.abs();

    String etaText;
    if (isPast) {
      etaText = 'Should be arriving any moment';
    } else if (minutesLeft < 60) {
      etaText = 'About $minutesLeft min${minutesLeft == 1 ? '' : 's'} away';
    } else {
      final h = diff.inHours;
      final m = minutesLeft % 60;
      etaText = m > 0 ? '$h hr ${m}m' : '$h hr';
    }

    final timeStr = _formatTime(eta.toLocal());

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.access_time_rounded,
              color: AppColors.success, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                    letterSpacing: 0.5)),
            const SizedBox(height: 2),
            Text(etaText,
                style: GoogleFonts.syne(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            Text('by $timeStr',
                style: GoogleFonts.dmSans(
                    fontSize: 11, color: AppColors.textMuted)),
          ]),
        ),
      ]),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour > 12
        ? dt.hour - 12
        : dt.hour == 0
            ? 12
            : dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }
}

// ── Rider card ────────────────────────────────────────────────────────────────

class _RiderCard extends StatelessWidget {
  const _RiderCard({required this.order});
  final OrderModel order;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.info.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.info.withValues(alpha: 0.25)),
        ),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.delivery_dining_rounded,
                color: AppColors.info, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Delivery Partner Assigned',
                  style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.info,
                      letterSpacing: 0.5)),
              const SizedBox(height: 2),
              Text('Your order has been assigned to a rider',
                  style: GoogleFonts.syne(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              Text('They will pick up your order shortly',
                  style: GoogleFonts.dmSans(
                      fontSize: 11, color: AppColors.textMuted)),
            ]),
          ),
          // Live pulse dot
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: AppColors.info,
              shape: BoxShape.circle,
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(end: 1.5, duration: 800.ms),
        ]),
      );
}

// ── Timeline step widget ──────────────────────────────────────────────────────

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.step,
    required this.isDone,
    required this.isCurrent,
    required this.isLast,
  });
  final _TrackStep step;
  final bool isDone;
  final bool isCurrent;
  final bool isLast;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Icon + connector line
          Column(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDone ? AppColors.primary : AppColors.surfaceAlt,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDone ? AppColors.primary : AppColors.border,
                  width: isCurrent ? 2 : 1,
                ),
                boxShadow: isCurrent
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 12,
                          spreadRadius: 2,
                        )
                      ]
                    : null,
              ),
              child: Icon(
                step.icon,
                size: 18,
                color: isDone ? Colors.white : AppColors.textDisabled,
              ),
            ),
            if (!isLast)
              Expanded(
                child: Container(
                  width: 2,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: isDone
                      ? AppColors.primary.withValues(alpha: 0.4)
                      : AppColors.border,
                ),
              ),
          ]),
          const SizedBox(width: 16),
          // Text
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 8, bottom: isLast ? 0 : 24),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(step.label,
                        style: GoogleFonts.syne(
                            fontSize: 14,
                            fontWeight:
                                isCurrent ? FontWeight.w800 : FontWeight.w600,
                            color: isDone
                                ? AppColors.textPrimary
                                : AppColors.textDisabled)),
                    const SizedBox(height: 2),
                    Text(step.description,
                        style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: isDone
                                ? AppColors.textMuted
                                : AppColors.textDisabled,
                            height: 1.4)),
                  ]),
            ),
          ),
        ]),
      );
}
