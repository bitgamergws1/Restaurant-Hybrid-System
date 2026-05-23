/// ─────────────────────────────────────────────────────────────────────────────
/// RouteNames
/// All named routes in one place — prevents typo-bugs across the codebase.
/// ─────────────────────────────────────────────────────────────────────────────
abstract final class RouteNames {
  static const String splash = 'splash';
  static const String login = 'login';
  static const String signup = 'signup';
  static const String otp = 'otp';
  static const String forgotPassword = 'forgot-password';
  static const String resetPassword = 'reset-password';
  static const String home = 'home';
  static const String menu = 'menu';
  static const String cart = 'cart';
  static const String checkout = 'checkout';
  static const String payment = 'payment';
  static const String orders = 'orders';
  static const String orderDetail = 'order-detail';
  static const String orderTracking = 'order-tracking';
  static const String profile = 'profile';
  static const String aiChat = 'ai-chat';

  /// Full-screen support / complaint flow.
  /// Accepts optional [orderId] query param to pre-select an order.
  static const String support = 'support';

  // ── Admin ──────────────────────────────────────────────────────────────────
  static const String admin = 'admin';
  static const String adminDashboard = 'admin-dashboard';
  static const String adminOrders = 'admin-orders';
  static const String adminDelivery = 'admin-delivery';
  static const String adminMenu = 'admin-menu';
  static const String adminTables = 'admin-tables';
  static const String adminRiders = 'admin-riders';
  static const String adminAnalytics = 'admin-analytics';
  static const String adminComplaints = 'admin-complaints';
}

abstract final class RoutePaths {
  static const String splash = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String otp = '/otp';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String home = '/home';
  static const String menu = '/home/menu';
  static const String cart = '/cart';
  static const String checkout = '/checkout';
  static const String payment = '/payment';
  static const String orders = '/home/orders';
  static const String orderDetail = '/home/orders/:id';
  static const String profile = '/home/profile';
  static const String aiChat = '/home/ai';

  /// Full-screen overlay — navigated to with pushNamed so it sits above
  /// whichever branch the user is currently on.
  static const String support = '/support';

  // ── Admin ──────────────────────────────────────────────────────────────────
  static const String admin = '/admin';
  static const String adminDashboard = '/admin/dashboard';
  static const String adminOrders = '/admin/orders';
  static const String adminDelivery = '/admin/delivery';
  static const String adminMenu = '/admin/menu';
  static const String adminTables = '/admin/tables';
  static const String adminRiders = '/admin/riders';
  static const String adminAnalytics = '/admin/analytics';
  static const String adminComplaints = '/admin/complaints';
}
