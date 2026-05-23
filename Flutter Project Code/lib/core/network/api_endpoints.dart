/// ─────────────────────────────────────────────────────────────────────────────
/// ApiEndpoints
/// Every backend route string in one place.
/// Base URL is read from [ApiConfig.baseUrl] at runtime so you can swap
/// local / staging / production without touching route strings.
/// ─────────────────────────────────────────────────────────────────────────────
abstract final class ApiConfig {
  /// For local dev: 'http://10.0.2.2:5000/api/v1'  (Android emulator)
  /// For local dev: 'http://localhost:5000/api/v1'  (Web / iOS simulator)
  static const String baseUrl =
      'https://restaurant-hybrid-system.onrender.com/api/v1';

  /// The header name the backend expects for session tokens.
  static const String sessionTokenHeader = 'X-Session-Token';

  /// SharedPreferences key where the session token is cached.
  static const String tokenPrefKey = 'session_token';

  /// SharedPreferences key for cached user JSON.
  static const String userPrefKey = 'cached_user';

  /// Connection / receive timeout in seconds.
  static const int timeoutSeconds = 30;
}

abstract final class ApiEndpoints {
  // ── Auth ─────────────────────────────────────────────────────────────────────
  static const String signup = '/auth/signup';
  static const String verifyOtp = '/auth/verify-otp';
  static const String resendOtp = '/auth/resend-otp';
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';

  // ── Menu ─────────────────────────────────────────────────────────────────────
  static const String menu = '/menu/';
  static const String menuCategories = '/menu/categories';
  static String menuItem(String id) => '/menu/$id';

  // ── Orders ───────────────────────────────────────────────────────────────────
  static const String orders = '/orders/';
  static String order(String id) => '/orders/$id';
  static String orderStatus(String id) => '/orders/$id/status';
  static String orderAssignRider(String id) => '/orders/$id/assign-rider';
  static String orderEta(String id) => '/orders/$id/eta';
  static String userOrders(String uid) => '/orders/user/$uid';

  // ── Payments ─────────────────────────────────────────────────────────────────
  static const String paymentVerify = '/payments/verify';
  static String invoice(String id) => '/payments/invoice/$id';

  // ── AI ───────────────────────────────────────────────────────────────────────
  static const String aiRecommend = '/ai/recommend';
  static const String aiTriage = '/ai/triage';
  static const String aiHealth = '/ai/health';

  // ── Admin ─────────────────────────────────────────────────────────────────────
  static const String analytics = '/admin/analytics';
  static const String complaints = '/admin/complaints';
  static String complaintStatus(String id) => '/admin/complaints/$id/status';
  static const String adminUsers = '/admin/users';
  static const String adminOrders = '/admin/orders';

  // ── Tables ─────────────────────────────────────────────────────────────────
  /// Admin: all tables (requires admin/staff role)
  static const String tables = '/tables';

  /// Customer: non-inactive tables for checkout dropdown (requires auth)
  static const String availableTables = '/tables/available';
  static String table(String id) => '/tables/$id';
  static String tableRegenerateQr(String id) => '/tables/$id/regenerate-qr';

  // ── Riders ─────────────────────────────────────────────────────────────────
  static const String riders = '/riders';
  static String rider(String id) => '/riders/$id';

  // ── Postal ───────────────────────────────────────────────────────────────────
  static String postal(String pin) => '/postal/$pin';
}
