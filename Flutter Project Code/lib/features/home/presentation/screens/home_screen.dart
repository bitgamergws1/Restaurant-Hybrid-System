import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../../../orders/presentation/providers/orders_provider.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// HomeScreen
/// Restaurant landing dashboard shown after login.
/// ─────────────────────────────────────────────────────────────────────────────
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(
      authNotifierProvider
          .select((s) => s is AuthAuthenticated ? s.user : null),
    );
    final cartCount =
        ref.watch(cartProvider).fold<int>(0, (s, i) => s + i.quantity);
    final recentOrders = ref.watch(userOrdersProvider);

    final greeting = _greeting();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(context, cartCount),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero greeting ────────────────────────────────────────────
            _HeroSection(
              greeting: greeting,
              userName: user?.name.split(' ').first ?? '',
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08),

            const SizedBox(height: 28),

            // ── Quick actions ────────────────────────────────────────────
            const _SectionLabel(label: 'Quick Actions')
                .animate()
                .fadeIn(delay: 120.ms),
            const SizedBox(height: 14),

            _QuickActionsRow(context: context)
                .animate()
                .fadeIn(delay: 160.ms)
                .slideY(begin: 0.08, delay: 160.ms),

            const SizedBox(height: 32),

            // ── Dining mode cards ────────────────────────────────────────
            const _SectionLabel(label: 'How Are You Dining?')
                .animate()
                .fadeIn(delay: 200.ms),
            const SizedBox(height: 14),

            _DiningModeCards(context: context).animate().fadeIn(delay: 240.ms),

            const SizedBox(height: 32),

            // ── Recent orders ────────────────────────────────────────────
            const _SectionLabel(label: 'Recent Orders')
                .animate()
                .fadeIn(delay: 280.ms),
            const SizedBox(height: 14),

            recentOrders.when(
              loading: () => const _OrdersShimmer(),
              error: (_, __) => const _EmptyOrdersCard(),
              data: (orders) => orders.isEmpty
                  ? const _EmptyOrdersCard().animate().fadeIn(delay: 320.ms)
                  : _RecentOrdersList(orders: orders.take(3).toList())
                      .animate()
                      .fadeIn(delay: 320.ms),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, int cartCount) {
    return AppBar(
      backgroundColor: AppColors.background,
      scrolledUnderElevation: 0,
      titleSpacing: 20,
      title: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
              color: AppColors.surfaceAlt,
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              'assets/images/route.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.restaurant_rounded,
                color: AppColors.primary,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Spice Route',
            style: GoogleFonts.syne(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
      actions: [
        if (cartCount > 0) _CartBadge(count: cartCount, context: context),
        const SizedBox(width: 8),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: AppColors.border),
      ),
    );
  }

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }
}

// ── Hero ──────────────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.greeting, required this.userName});
  final String greeting;
  final String userName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.14),
            AppColors.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$greeting${userName.isNotEmpty ? ", $userName" : ""}',
            style: GoogleFonts.dmSans(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Ready to order? Browse the menu or ask our AI Waiter.',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: AppColors.textTertiary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          // CTA row
          Row(
            children: [
              _HeroCta(
                label: 'Browse Menu',
                icon: Icons.restaurant_menu_rounded,
                onTap: () => context.goNamed(RouteNames.menu),
              ),
              const SizedBox(width: 10),
              _HeroCta(
                label: 'AI Waiter',
                icon: Icons.auto_awesome_rounded,
                secondary: true,
                onTap: () => context.goNamed(RouteNames.aiChat),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroCta extends StatelessWidget {
  const _HeroCta({
    required this.label,
    required this.icon,
    required this.onTap,
    this.secondary = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: secondary ? null : AppColors.primaryGradient,
          color: secondary ? AppColors.surfaceAlt : null,
          borderRadius: BorderRadius.circular(10),
          border: secondary ? Border.all(color: AppColors.border) : null,
          boxShadow: secondary
              ? null
              : [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: secondary ? AppColors.textMuted : Colors.white,
                size: 15),
            const SizedBox(width: 7),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: secondary ? AppColors.textTertiary : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          label.toUpperCase(),
          style: GoogleFonts.dmSans(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.textDisabled,
            letterSpacing: 2,
          ),
        ),
      );
}

// ── Quick actions ─────────────────────────────────────────────────────────────

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({required this.context});
  final BuildContext context;

  static const _actions = [
    (
      icon: Icons.restaurant_menu_rounded,
      label: 'Menu',
      route: RouteNames.menu,
    ),
    (
      icon: Icons.receipt_long_rounded,
      label: 'Orders',
      route: RouteNames.orders,
    ),
    (
      icon: Icons.auto_awesome_rounded,
      label: 'AI Chef',
      route: RouteNames.aiChat,
    ),
    (
      icon: Icons.person_rounded,
      label: 'Profile',
      route: RouteNames.profile,
    ),
  ];

  @override
  Widget build(BuildContext ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: _actions
              .asMap()
              .entries
              .map(
                (e) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: e.key == 0 ? 0 : 8,
                    ),
                    child: _QuickActionTile(
                      icon: e.value.icon,
                      label: e.value.label,
                      isAccent: e.value.label == 'AI Chef',
                      onTap: () => ctx.goNamed(e.value.route),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      );
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isAccent = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isAccent;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isAccent ? AppColors.primaryTint : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isAccent
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : AppColors.border,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isAccent ? AppColors.primary : AppColors.textMuted,
                size: 22,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isAccent ? AppColors.primary : AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      );
}

// ── Dining mode ───────────────────────────────────────────────────────────────

class _DiningModeCards extends StatelessWidget {
  const _DiningModeCards({required this.context});
  final BuildContext context;

  @override
  Widget build(BuildContext ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: _ModeCard(
                icon: Icons.table_restaurant_rounded,
                title: 'Dine In',
                subtitle: 'Reserve a table and order at the restaurant',
                accentColor: AppColors.primary,
                onTap: () => ctx.goNamed(RouteNames.menu),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ModeCard(
                icon: Icons.delivery_dining_rounded,
                title: 'Delivery',
                subtitle: 'Get food delivered to your doorstep',
                accentColor: AppColors.info,
                onTap: () => ctx.goNamed(RouteNames.menu),
              ),
            ),
          ],
        ),
      );
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
}

// ── Cart badge ────────────────────────────────────────────────────────────────

class _CartBadge extends StatelessWidget {
  const _CartBadge({required this.count, required this.context});
  final int count;
  final BuildContext context;

  @override
  Widget build(BuildContext ctx) => GestureDetector(
        onTap: () => ctx.pushNamed(RouteNames.cart),
        child: Container(
          margin: const EdgeInsets.only(right: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primaryTint,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.shopping_cart_rounded,
                  color: AppColors.primary, size: 15),
              const SizedBox(width: 5),
              Text(
                '$count',
                style: GoogleFonts.syne(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      );
}

// ── Recent orders ─────────────────────────────────────────────────────────────

class _RecentOrdersList extends ConsumerWidget {
  const _RecentOrdersList({required this.orders});
  final List<dynamic> orders;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
        children: orders
            .asMap()
            .entries
            .map(
              (e) => Padding(
                padding:
                    EdgeInsets.only(bottom: e.key < orders.length - 1 ? 10 : 0),
                child: _OrderTile(order: e.value, context: context),
              ),
            )
            .toList(),
      );
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order, required this.context});
  final dynamic order;
  final BuildContext context;

  Color _statusColor(String status) {
    return switch (status) {
      'delivered' => AppColors.success,
      'cancelled' => AppColors.error,
      'out_for_delivery' => AppColors.info,
      'preparing' || 'confirmed' => AppColors.warning,
      _ => AppColors.textMuted,
    };
  }

  String _statusLabel(String status) {
    return switch (status) {
      'pending' => 'Pending',
      'confirmed' => 'Confirmed',
      'preparing' => 'Preparing',
      'ready' => 'Ready',
      'out_for_delivery' => 'On the Way',
      'delivered' => 'Delivered',
      'cancelled' => 'Cancelled',
      _ => status,
    };
  }

  @override
  Widget build(BuildContext ctx) {
    final id = order.id as String;
    final status = order.status as String;
    final total = order.totalAmount as double;
    final type = order.orderType as String;
    final color = _statusColor(status);

    return GestureDetector(
      onTap: () => ctx.goNamed(
        RouteNames.orderDetail,
        pathParameters: {'id': id},
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                type == 'dine_in'
                    ? Icons.table_restaurant_rounded
                    : Icons.delivery_dining_rounded,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#${id.substring(0, 8).toUpperCase()}',
                    style: GoogleFonts.syne(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    type == 'dine_in' ? 'Dine In' : 'Delivery',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Rs. ${total.toStringAsFixed(2)}',
                  style: GoogleFonts.syne(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyOrdersCard extends StatelessWidget {
  const _EmptyOrdersCard();

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              color: AppColors.textDisabled,
              size: 36,
            ),
            const SizedBox(height: 12),
            Text(
              'No orders yet',
              style: GoogleFonts.syne(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your recent orders will appear here.',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: AppColors.textDisabled,
              ),
            ),
          ],
        ),
      );
}

class _OrdersShimmer extends StatelessWidget {
  const _OrdersShimmer();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: List.generate(
            2,
            (_) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              height: 74,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
            ),
          ),
        ),
      );
}
