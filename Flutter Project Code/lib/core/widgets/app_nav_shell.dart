import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:responsive_builder/responsive_builder.dart';
import '../constants/app_colors.dart';
import '../../features/cart/presentation/providers/cart_provider.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// AppNavShell
/// Web (>= 800 px): permanent left sidebar (220 px)
/// Mobile (< 800 px): bottom NavigationBar + fixed top-right cart button
///
/// Branch index map (matches app_router.dart):
///   0 → Home   1 → Menu   2 → Orders   3 → AI Chef   4 → Profile
/// ─────────────────────────────────────────────────────────────────────────────
class AppNavShell extends ConsumerWidget {
  const AppNavShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  static const _destinations = [
    _NavDest(
        icon: Icons.home_outlined, active: Icons.home_rounded, label: 'Home'),
    _NavDest(
        icon: Icons.restaurant_menu_outlined,
        active: Icons.restaurant_menu_rounded,
        label: 'Menu'),
    _NavDest(
        icon: Icons.receipt_long_outlined,
        active: Icons.receipt_long_rounded,
        label: 'Orders'),
    _NavDest(
        icon: Icons.auto_awesome_outlined,
        active: Icons.auto_awesome_rounded,
        label: 'AI Chef'),
    _NavDest(
        icon: Icons.person_outline_rounded,
        active: Icons.person_rounded,
        label: 'Profile'),
  ];

  void _tap(int i) =>
      shell.goBranch(i, initialLocation: i == shell.currentIndex);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartCount =
        ref.watch(cartProvider).fold<int>(0, (s, i) => s + i.quantity);

    return ResponsiveBuilder(
      builder: (ctx, sizing) => sizing.screenSize.width >= 800
          ? _WebLayout(
              shell: shell,
              dests: _destinations,
              idx: shell.currentIndex,
              onTap: _tap,
              cartCount: cartCount,
            )
          : _MobileLayout(
              shell: shell,
              dests: _destinations,
              idx: shell.currentIndex,
              onTap: _tap,
              cartCount: cartCount,
            ),
    );
  }
}

// ── Web sidebar ──────────────────────────────────────────────────────────────

class _WebLayout extends StatelessWidget {
  const _WebLayout({
    required this.shell,
    required this.dests,
    required this.idx,
    required this.onTap,
    required this.cartCount,
  });

  final StatefulNavigationShell shell;
  final List<_NavDest> dests;
  final int idx;
  final void Function(int) onTap;
  final int cartCount;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        body: Row(
          children: [
            // Sidebar
            Container(
              width: 220,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  right: BorderSide(color: AppColors.border),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                            color: AppColors.surfaceAlt,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.asset(
                            'assets/images/route.png',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.restaurant_menu_rounded,
                              color: AppColors.primary,
                              size: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            'Spice Route',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.syne(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Divider(
                      color: AppColors.border,
                      height: 28,
                    ),
                  ),

                  // Nav items
                  ...List.generate(dests.length, (i) {
                    final on = i == idx;

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 2,
                      ),
                      child: InkWell(
                        onTap: () => onTap(i),
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color:
                                on ? AppColors.primaryTint : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                on ? dests[i].active : dests[i].icon,
                                color: on
                                    ? AppColors.primary
                                    : AppColors.textMuted,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                dests[i].label,
                                style: GoogleFonts.dmSans(
                                  fontSize: 14,
                                  fontWeight:
                                      on ? FontWeight.w600 : FontWeight.w400,
                                  color: on
                                      ? AppColors.primary
                                      : AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),

                  const Spacer(),

                  if (cartCount > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: InkWell(
                        onTap: () => context.push('/cart'),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryTint,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.shopping_cart_rounded,
                                color: AppColors.primary,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Cart  ($cartCount)',
                                style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Divider(
                      color: AppColors.border,
                      height: 24,
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: Text(
                      'v1.0.0',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: AppColors.textDisabled,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(child: shell),
          ],
        ),
      );
}

// ── Mobile bottom nav ─────────────────────────────────────────────────────────

class _MobileLayout extends StatelessWidget {
  const _MobileLayout({
    required this.shell,
    required this.dests,
    required this.idx,
    required this.onTap,
    required this.cartCount,
  });

  final StatefulNavigationShell shell;
  final List<_NavDest> dests;
  final int idx;
  final void Function(int) onTap;
  final int cartCount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // ── Fixed top-right cart button ─────────────────────────────────────
      // Rendered as a Stack overlay so it appears above every screen's AppBar.
      body: Stack(
        children: [
          shell,
          // ── Floating cart button — bottom-right above bottom nav ─────────
          // Moved here (was top-right) to stop overlapping screen AppBars,
          // including the "AI Chef" shortcut on the Menu screen.
          if (cartCount > 0)
            Positioned(
              bottom: 70, // sits just above the 60 px bottom nav + safe area
              right: 16,
              child: _TopCartButton(cartCount: cartCount),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(color: AppColors.border),
          ),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 60,
            child: Row(
              children: List.generate(dests.length, (i) {
                final on = i == idx;

                return Expanded(
                  child: GestureDetector(
                    onTap: () => onTap(i),
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          on ? dests[i].active : dests[i].icon,
                          color: on ? AppColors.primary : AppColors.textMuted,
                          size: 22,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          dests[i].label,
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                            color: on ? AppColors.primary : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Fixed top-right cart button ───────────────────────────────────────────────

class _TopCartButton extends StatelessWidget {
  const _TopCartButton({required this.cartCount});
  final int cartCount;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => context.push('/cart'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.40),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.shopping_cart_rounded,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                '$cartCount',
                style: GoogleFonts.syne(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
}

class _NavDest {
  const _NavDest({
    required this.icon,
    required this.active,
    required this.label,
  });

  final IconData icon;
  final IconData active;
  final String label;
}
