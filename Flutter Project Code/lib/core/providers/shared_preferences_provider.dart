import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/api_client.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// sharedPreferencesProvider
/// Seeded in main.dart via ProviderScope overrides — so it is always
/// synchronously available to every other provider.
/// ─────────────────────────────────────────────────────────────────────────────
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in ProviderScope',
  ),
);

/// ─────────────────────────────────────────────────────────────────────────────
/// apiClientProvider
/// Single [ApiClient] instance for the whole app.
/// Automatically picks up the SharedPreferences instance so the auth
/// interceptor can read / clear the session token.
/// ─────────────────────────────────────────────────────────────────────────────
final apiClientProvider = Provider<ApiClient>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ApiClient(prefs);
});
