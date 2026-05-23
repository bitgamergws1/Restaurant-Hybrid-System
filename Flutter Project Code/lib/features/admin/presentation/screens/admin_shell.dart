import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/route_names.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AdminShell
// Responsive admin wrapper:
//   • Mobile  (<720 px) — BottomNavigationBar with primary 4 tabs + "More"
//                         sheet for secondary screens.
//   • Desktop (≥720 px) — permanent left sidebar.
//
// Back-button handling:
//   • On any admin screen that is NOT the dashboard, back goes to dashboard.
//   • On the dashboard itself, back exits (normal OS behaviour).
// ─────────────────────────────────────────────────────────────────────────────

class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.child});
  final Widget child;

  // All nav items — desktop sidebar shows all, mobile splits them.
  static const _allItems = <_NavItem>[
    _NavItem(
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard_rounded,
      label: 'Dashboard',
      path: RoutePaths.adminDashboard,
    ),
    _NavItem(
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long_rounded,
      label: 'Orders',
      path: RoutePaths.adminOrders,
    ),
    _NavItem(
      icon: Icons.local_shipping_outlined,
      activeIcon: Icons.local_shipping_rounded,
      label: 'Delivery',
      path: RoutePaths.adminDelivery,
    ),
    _NavItem(
      icon: Icons.restaurant_menu_outlined,
      activeIcon: Icons.restaurant_menu_rounded,
      label: 'Menu',
      path: RoutePaths.adminMenu,
    ),
    _NavItem(
      icon: Icons.table_restaurant_outlined,
      activeIcon: Icons.table_restaurant_rounded,
      label: 'Tables',
      path: RoutePaths.adminTables,
    ),
    _NavItem(
      icon: Icons.two_wheeler_outlined,
      activeIcon: Icons.two_wheeler_rounded,
      label: 'Riders',
      path: RoutePaths.adminRiders,
    ),
    _NavItem(
      icon: Icons.bar_chart_outlined,
      activeIcon: Icons.bar_chart_rounded,
      label: 'Analytics',
      path: RoutePaths.adminAnalytics,
    ),
    _NavItem(
      icon: Icons.chat_bubble_outline_rounded,
      activeIcon: Icons.chat_bubble_rounded,
      label: 'Complaints',
      path: RoutePaths.adminComplaints,
    ),
  ];

  // Bottom-nav primary items (mobile). The rest go into the "More" sheet.
  static const _primaryIndices = [
    0,
    1,
    2,
    3
  ]; // Dashboard, Orders, Delivery, Menu

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = GoRouterState.of(context).matchedLocation;
    final authState = ref.watch(authNotifierProvider);
    final userName =
        authState is AuthAuthenticated ? authState.user.name : 'Admin';
    final isMobile = MediaQuery.sizeOf(context).width < 720;

    // ── Back-button: any non-dashboard admin screen → go to dashboard ────────
    final wrappedChild = PopScope(
      canPop: loc == RoutePaths.adminDashboard,
      onPopInvokedWithResult: (didPop, _) {
        // Run after the current frame so GoRouter state is fully settled
        // before we issue a new navigation command.
        if (!didPop && loc != RoutePaths.adminDashboard) {
          Future.microtask(() {
            if (context.mounted) context.go(RoutePaths.adminDashboard);
          });
        }
      },
      child: child,
    );

    if (isMobile) {
      return _MobileShell(
        allItems: _allItems,
        primaryIndices: _primaryIndices,
        loc: loc,
        userName: userName,
        ref: ref,
        child: wrappedChild,
      );
    }

    return _DesktopShell(
      allItems: _allItems,
      loc: loc,
      userName: userName,
      ref: ref,
      child: wrappedChild,
    );
  }
}

// ── Desktop: permanent sidebar ───────────────────────────────────────────────

class _DesktopShell extends StatelessWidget {
  const _DesktopShell({
    required this.child,
    required this.allItems,
    required this.loc,
    required this.userName,
    required this.ref,
  });

  final Widget child;
  final List<_NavItem> allItems;
  final String loc;
  final String userName;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        body: Row(
          children: [
            _Sidebar(
              items: allItems,
              loc: loc,
              userName: userName,
              ref: ref,
            ),
            const VerticalDivider(width: 1, color: AppColors.border),
            Expanded(child: child),
          ],
        ),
      );
}

// ── Mobile: bottom nav bar ────────────────────────────────────────────────────
// The outer Scaffold owns the bottomNavigationBar; the child (inner Scaffold)
// fills the body area above it. This avoids the nested-Scaffold drawer issue.

class _MobileShell extends StatelessWidget {
  const _MobileShell({
    required this.child,
    required this.allItems,
    required this.primaryIndices,
    required this.loc,
    required this.userName,
    required this.ref,
  });

  final Widget child;
  final List<_NavItem> allItems;
  final List<int> primaryIndices;
  final String loc;
  final String userName;
  final WidgetRef ref;

  List<_NavItem> get _primaryItems =>
      primaryIndices.map((i) => allItems[i]).toList();

  List<_NavItem> get _moreItems =>
      allItems.whereIndexed((i, _) => !primaryIndices.contains(i)).toList();

  // Returns 0-based index into the bottom nav (primary items + "More" = last).
  int _selectedIndex() {
    for (var i = 0; i < primaryIndices.length; i++) {
      if (loc.startsWith(_primaryItems[i].path)) return i;
    }
    return primaryIndices.length; // "More" tab
  }

  bool get _isMoreActive => _selectedIndex() == primaryIndices.length;

  void _onTap(BuildContext context, int index) {
    if (index < primaryIndices.length) {
      context.go(_primaryItems[index].path);
    } else {
      _showMoreSheet(context);
    }
  }

  void _showMoreSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _MoreSheet(items: _moreItems, loc: loc),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _selectedIndex();

    return Scaffold(
      backgroundColor: AppColors.background,
      // ── Bottom nav ──────────────────────────────────────────────────────
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 60,
            child: Row(
              children: [
                // Primary tabs
                ..._primaryItems.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  final isActive = selectedIndex == i;
                  return _BottomTab(
                    icon: isActive ? item.activeIcon : item.icon,
                    label: item.label,
                    isActive: isActive,
                    onTap: () => _onTap(context, i),
                  );
                }),
                // "More" tab
                _BottomTab(
                  icon: Icons.more_horiz_rounded,
                  label: 'More',
                  isActive: _isMoreActive,
                  onTap: () => _showMoreSheet(context),
                ),
              ],
            ),
          ),
        ),
      ),
      body: child,
    );
  }
}

class _BottomTab extends StatelessWidget {
  const _BottomTab({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 22,
                color: isActive ? AppColors.primary : AppColors.textMuted,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive ? AppColors.primary : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      );
}

// ── "More" bottom sheet ───────────────────────────────────────────────────────

class _MoreSheet extends StatelessWidget {
  const _MoreSheet({required this.items, required this.loc});
  final List<_NavItem> items;
  final String loc;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'More',
                style: GoogleFonts.syne(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          ...items.map((item) {
            final isActive = loc.startsWith(item.path);
            return ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
              leading: Icon(
                isActive ? item.activeIcon : item.icon,
                size: 20,
                color: isActive ? AppColors.primary : AppColors.textMuted,
              ),
              title: Text(
                item.label,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
              trailing: isActive
                  ? const Icon(Icons.circle, size: 6, color: AppColors.primary)
                  : null,
              tileColor: isActive ? AppColors.primaryTint : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              onTap: () {
                Navigator.of(context).pop();
                context.go(item.path);
              },
            );
          }),
          const SizedBox(height: 16),
          // Sign out row
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Divider(color: AppColors.border),
          ),
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
            leading: const Icon(Icons.storefront_outlined,
                size: 20, color: AppColors.textMuted),
            title: Text(
              'Customer View',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            onTap: () {
              Navigator.of(context).pop();
              context.go(RoutePaths.menu);
            },
          ),
          const SizedBox(height: 8),
        ],
      );
}

// ── Desktop sidebar ───────────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.items,
    required this.loc,
    required this.userName,
    required this.ref,
  });

  final List<_NavItem> items;
  final String loc;
  final String userName;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) => Container(
        width: 220,
        color: AppColors.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTint,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      'ADMIN PANEL',
                      style: GoogleFonts.dmMono(
                        fontSize: 9,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Spice Route',
                    style: GoogleFonts.syne(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    userName,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Nav items
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                children: items.map((item) {
                  final isActive = loc.startsWith(item.path);
                  return _SidebarTile(item: item, isActive: isActive);
                }).toList(),
              ),
            ),

            // Footer actions
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 24),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                children: [
                  _ActionTile(
                    icon: Icons.storefront_outlined,
                    label: 'Customer View',
                    onTap: () => context.go(RoutePaths.menu),
                  ),
                  const SizedBox(height: 2),
                  _ActionTile(
                    icon: Icons.logout_rounded,
                    label: 'Sign Out',
                    color: AppColors.error,
                    onTap: () =>
                        ref.read(authNotifierProvider.notifier).logout(),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({required this.item, required this.isActive});
  final _NavItem item;
  final bool isActive;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Material(
          color: isActive ? AppColors.primaryTint : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: () => context.go(item.path),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    isActive ? item.activeIcon : item.icon,
                    size: 18,
                    color: isActive ? AppColors.primary : AppColors.textMuted,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    item.label,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      color:
                          isActive ? AppColors.primary : AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                Icon(icon, size: 17, color: color ?? AppColors.textMuted),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: color ?? AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

// ── Data class ────────────────────────────────────────────────────────────────

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.path,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String path;
}

// ── Extension helper ──────────────────────────────────────────────────────────

extension _IterableIndexed<T> on Iterable<T> {
  Iterable<T> whereIndexed(bool Function(int index, T element) test) sync* {
    var i = 0;
    for (final e in this) {
      if (test(i, e)) yield e;
      i++;
    }
  }
}
