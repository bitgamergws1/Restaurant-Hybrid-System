import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/route_names.dart';
import '../providers/admin_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DashboardScreen
// Overview tiles pulling from /admin/analytics + live order counts.
// ─────────────────────────────────────────────────────────────────────────────

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(adminAnalyticsProvider);
    final ordersAsync = ref.watch(adminOrdersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: () async {
          await ref.read(adminAnalyticsProvider.notifier).refresh();
          await ref.read(adminOrdersProvider.notifier).refresh();
        },
        child: CustomScrollView(
          slivers: [
            // ── Header ──────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dashboard',
                          style: GoogleFonts.syne(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Overview of your restaurant',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    _RefreshButton(
                      onTap: () {
                        ref.read(adminAnalyticsProvider.notifier).refresh();
                        ref.read(adminOrdersProvider.notifier).refresh();
                      },
                    ),
                  ],
                ),
              ),
            ),

            // ── Analytics summary tiles ──────────────────────────────────────
            analyticsAsync.when(
              loading: () => const SliverToBoxAdapter(
                child: _LoadingSection(label: 'Loading analytics…'),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: _ErrorSection(message: e.toString()),
              ),
              data: (analytics) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionLabel('Revenue & Orders'),
                      const SizedBox(height: 10),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.6,
                        children: [
                          _StatTile(
                            label: 'Total Revenue',
                            value:
                                '₹${analytics.summary.totalRevenue.toStringAsFixed(0)}',
                            icon: Icons.currency_rupee_rounded,
                            color: AppColors.primary,
                          ),
                          _StatTile(
                            label: 'Total Orders',
                            value: analytics.summary.totalOrders.toString(),
                            icon: Icons.receipt_long_rounded,
                            color: AppColors.info,
                          ),
                          _StatTile(
                            label: 'Avg Order Value',
                            value:
                                '₹${analytics.summary.averageOrderValue.toStringAsFixed(0)}',
                            icon: Icons.trending_up_rounded,
                            color: AppColors.success,
                          ),
                          _StatTile(
                            label: 'Cancelled',
                            value: analytics.summary.cancelledOrders.toString(),
                            icon: Icons.cancel_outlined,
                            color: AppColors.error,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const _SectionLabel('Order Types'),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _StatTile(
                              label: 'Dine-In',
                              value: analytics.summary.dineInOrders.toString(),
                              icon: Icons.table_restaurant_rounded,
                              color: AppColors.warning,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _StatTile(
                              label: 'Delivery',
                              value:
                                  analytics.summary.deliveryOrders.toString(),
                              icon: Icons.delivery_dining_rounded,
                              color: AppColors.info,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const _SectionLabel('Menu'),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _StatTile(
                              label: 'Total Items',
                              value: analytics.menuTotal.toString(),
                              icon: Icons.restaurant_menu_rounded,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _StatTile(
                              label: 'Available',
                              value: analytics.menuAvailable.toString(),
                              icon: Icons.check_circle_outline_rounded,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Quick actions ────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionLabel('Quick Actions'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _QuickAction(
                          label: 'View Orders',
                          icon: Icons.receipt_long_outlined,
                          onTap: () => context.go(RoutePaths.adminOrders),
                        ),
                        const SizedBox(width: 10),
                        _QuickAction(
                          label: 'Manage Menu',
                          icon: Icons.restaurant_menu_outlined,
                          onTap: () => context.go(RoutePaths.adminMenu),
                        ),
                        const SizedBox(width: 10),
                        _QuickAction(
                          label: 'Analytics',
                          icon: Icons.bar_chart_rounded,
                          onTap: () => context.go(RoutePaths.adminAnalytics),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Live orders preview ──────────────────────────────────────────
            ordersAsync.when(
              loading: () => const SliverToBoxAdapter(
                child: _LoadingSection(label: 'Loading orders…'),
              ),
              error: (_, __) => const SliverToBoxAdapter(child: SizedBox()),
              data: (orders) {
                final active = orders.where((o) => o.isActive).take(5).toList();
                if (active.isEmpty) {
                  return const SliverToBoxAdapter(child: SizedBox());
                }
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const _SectionLabel('Active Orders'),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => context.go(RoutePaths.adminOrders),
                              child: Text(
                                'View all',
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...active.map((order) => _OrderRow(order: order)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widgets ──────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted,
          letterSpacing: 0.8,
        ),
      );
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, size: 18, color: color),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.syne(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Icon(icon, size: 20, color: AppColors.primary),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order});
  final AdminOrderModel order;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Text(
              '#${order.shortId}',
              style: GoogleFonts.dmMono(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 10),
            _StatusChip(status: order.status),
            const Spacer(),
            Text(
              order.isDineIn ? 'Dine-In' : 'Delivery',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '₹${order.totalAmount.toStringAsFixed(0)}',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  Color get _color {
    return switch (status) {
      'pending' => AppColors.warning,
      'confirmed' => AppColors.info,
      'preparing' => AppColors.primary,
      'ready' => AppColors.success,
      'out_for_delivery' => AppColors.info,
      'delivered' => AppColors.success,
      'cancelled' => AppColors.error,
      _ => AppColors.textMuted,
    };
  }

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
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: _color,
          ),
        ),
      );
}

class _RefreshButton extends StatelessWidget {
  const _RefreshButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: const Icon(
            Icons.refresh_rounded,
            size: 18,
            color: AppColors.textMuted,
          ),
        ),
      );
}

class _LoadingSection extends StatelessWidget {
  const _LoadingSection({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              const CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2,
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      );
}

class _ErrorSection extends StatelessWidget {
  const _ErrorSection({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.errorTint,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
