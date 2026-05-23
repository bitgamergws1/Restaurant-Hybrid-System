import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../router/route_names.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/otp_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';

import '../../features/ai/presentation/screens/ai_chat_screen.dart';

import '../../features/cart/presentation/screens/cart_screen.dart';

import '../../features/home/presentation/screens/home_screen.dart';

import '../../features/menu/presentation/screens/menu_screen.dart';

import '../../features/orders/presentation/screens/checkout_screen.dart';
import '../../features/orders/presentation/screens/order_detail_screen.dart';
import '../../features/orders/presentation/screens/order_tracking_screen.dart';
import '../../features/orders/presentation/screens/orders_screen.dart';

import '../../features/payments/presentation/screens/payment_screen.dart';

import '../../features/profile/presentation/screens/profile_screen.dart';

import '../../features/support/presentation/screens/support_screen.dart';

import '../../features/admin/presentation/screens/admin_shell.dart';
import '../../features/admin/presentation/screens/dashboard_screen.dart';
import '../../features/admin/presentation/screens/admin_orders_screen.dart';
import '../../features/admin/presentation/screens/delivery_screen.dart';
import '../../features/admin/presentation/screens/menu_management_screen.dart';
import '../../features/admin/presentation/screens/tables_management_screen.dart';
import '../../features/admin/presentation/screens/riders_screen.dart';
import '../../features/admin/presentation/screens/analytics_screen.dart';
import '../../features/admin/presentation/screens/complaints_admin_screen.dart';

import '../widgets/app_nav_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthChangeNotifier(ref);

  return GoRouter(
    debugLogDiagnostics: false,
    initialLocation: RoutePaths.splash,
    refreshListenable: notifier,
    redirect: (context, state) {
      final auth = ref.read(authNotifierProvider);

      final isAuthed = auth is AuthAuthenticated;

      final loc = state.matchedLocation;

      final onSplash = loc == RoutePaths.splash;
      final onAuth = loc.startsWith('/login') ||
          loc.startsWith('/signup') ||
          loc.startsWith('/otp') ||
          loc.startsWith('/forgot');

      // AuthInitial = true app startup check (show splash).
      // AuthLoading = an async op is running on a screen — do NOT redirect;
      //   the screen shows its own spinner. Redirecting here unmounts the
      //   screen and kills ref.listen callbacks (OTP nav never fires).
      if (auth is AuthInitial) return onSplash ? null : RoutePaths.splash;
      if (auth is AuthLoading) return null; // stay wherever we are

      if (!isAuthed) return onAuth ? null : RoutePaths.login;
      if (isAuthed && (onSplash || onAuth)) {
        // Role-based landing: admin/staff → admin dashboard, customer → menu
        final user = auth.user;
        return user.isStaff ? RoutePaths.adminDashboard : RoutePaths.menu;
      }

      // Block customers from /admin/* routes entirely
      if (isAuthed) {
        final user = auth.user;
        final onAdmin = loc.startsWith('/admin');
        if (onAdmin && !user.isStaff) return RoutePaths.menu;
      }

      // Redirect bare /admin to /admin/dashboard
      if (loc == RoutePaths.admin) return RoutePaths.adminDashboard;

      return null;
    },
    routes: [
      // ── Public ───────────────────────────────────────────────────────────

      GoRoute(
        path: RoutePaths.splash,
        name: RouteNames.splash,
        builder: (_, __) => const SplashScreen(),
      ),

      GoRoute(
        path: RoutePaths.login,
        name: RouteNames.login,
        builder: (_, __) => const LoginScreen(),
      ),

      GoRoute(
        path: RoutePaths.signup,
        name: RouteNames.signup,
        builder: (_, __) => const SignupScreen(),
      ),

      GoRoute(
        path: RoutePaths.otp,
        name: RouteNames.otp,
        builder: (_, state) => OtpScreen(
          email: state.uri.queryParameters['email'] ?? '',
          purpose: state.uri.queryParameters['purpose'] ?? 'signup',
          name: state.uri.queryParameters['name'] ?? '',
          isReset: state.uri.queryParameters['purpose'] == 'reset',
        ),
      ),

      GoRoute(
        path: RoutePaths.forgotPassword,
        name: RouteNames.forgotPassword,
        builder: (_, __) => const ForgotPasswordScreen(),
      ),

      // ── Full-screen overlays (no bottom nav) ─────────────────────────────

      GoRoute(
        path: RoutePaths.cart,
        name: RouteNames.cart,
        builder: (_, __) => const CartScreen(),
      ),

      GoRoute(
        path: RoutePaths.checkout,
        name: RouteNames.checkout,
        builder: (_, __) => const CheckoutScreen(),
      ),

      GoRoute(
        path: RoutePaths.payment,
        name: RouteNames.payment,
        builder: (_, state) => PaymentScreen(
          orderId: state.uri.queryParameters['orderId'] ?? '',
          totalAmount: double.tryParse(
                state.uri.queryParameters['total'] ?? '0',
              ) ??
              0,
        ),
      ),

      // ── Support (full-screen overlay, reachable from order detail or profile) ──
      // Uses pushNamed so back button always returns to the calling screen.
      // Optional [orderId] query param pre-selects the order in the flow.
      GoRoute(
        path: RoutePaths.support,
        name: RouteNames.support,
        builder: (_, state) => SupportScreen(
          prefillOrderId: state.uri.queryParameters['orderId'],
        ),
      ),

      // ── Bottom-nav shell ─────────────────────────────────────────────────

      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppNavShell(shell: shell),
        branches: [
          // Home
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.home,
                name: RouteNames.home,
                builder: (_, __) => const HomeScreen(),
              ),
            ],
          ),

          // Menu
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.menu,
                name: RouteNames.menu,
                builder: (_, __) => const MenuScreen(),
              ),
            ],
          ),

          // Orders
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.orders,
                name: RouteNames.orders,
                builder: (_, __) => const OrdersScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    name: RouteNames.orderDetail,
                    builder: (_, state) => OrderDetailScreen(
                      orderId: state.pathParameters['id']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'track',
                        name: RouteNames.orderTracking,
                        builder: (_, state) => OrderTrackingScreen(
                          orderId: state.pathParameters['id']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // AI Chef
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.aiChat,
                name: RouteNames.aiChat,
                builder: (_, __) => const AiChatScreen(),
              ),
            ],
          ),

          // Profile
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.profile,
                name: RouteNames.profile,
                builder: (_, __) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // ── Admin shell ───────────────────────────────────────────────────────

      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: RoutePaths.adminDashboard,
            name: RouteNames.adminDashboard,
            builder: (_, __) => const DashboardScreen(),
          ),
          GoRoute(
            path: RoutePaths.adminOrders,
            name: RouteNames.adminOrders,
            builder: (_, __) => const AdminOrdersScreen(),
          ),
          GoRoute(
            path: RoutePaths.adminDelivery,
            name: RouteNames.adminDelivery,
            builder: (_, __) => const DeliveryScreen(),
          ),
          GoRoute(
            path: RoutePaths.adminMenu,
            name: RouteNames.adminMenu,
            builder: (_, __) => const MenuManagementScreen(),
          ),
          GoRoute(
            path: RoutePaths.adminTables,
            name: RouteNames.adminTables,
            builder: (_, __) => const TablesManagementScreen(),
          ),
          GoRoute(
            path: RoutePaths.adminRiders,
            name: RouteNames.adminRiders,
            builder: (_, __) => const RidersScreen(),
          ),
          GoRoute(
            path: RoutePaths.adminAnalytics,
            name: RouteNames.adminAnalytics,
            builder: (_, __) => const AnalyticsScreen(),
          ),
          GoRoute(
            path: RoutePaths.adminComplaints,
            name: RouteNames.adminComplaints,
            builder: (_, __) => const ComplaintsAdminScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Center(
        child: Text(
          'Route not found: ${state.uri}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    ),
  );
});

final class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(Ref ref) {
    ref.listen<AuthState>(
      authNotifierProvider,
      (_, __) => notifyListeners(),
    );
  }
}
