import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/providers/shared_preferences_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// main()
/// 1. Ensures Flutter bindings are ready.
/// 2. Awaits SharedPreferences — the ONLY async call before first frame.
/// 3. Locks orientation to portrait on phones; allows all on tablets/web.
/// 4. Sets transparent system bars so our dark background bleeds edge-to-edge.
/// 5. Wraps everything in ProviderScope, injecting the prefs instance.
/// ─────────────────────────────────────────────────────────────────────────────
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── SharedPreferences init (synchronous from here on) ──────────────────────
  final prefs = await SharedPreferences.getInstance();

  // ── System UI — full edge-to-edge dark chrome ───────────────────────────────
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0F0F0F),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Allow all orientations on wider screens; portrait-only on phones.
  // We check after first frame so MediaQuery is available.

  runApp(
    ProviderScope(
      overrides: [
        // Seed the SharedPreferences provider so every downstream provider
        // can access it synchronously without a FutureProvider chain.
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const SpiceRouteApp(),
    ),
  );
}

/// Root application widget.
class SpiceRouteApp extends ConsumerWidget {
  const SpiceRouteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Spice Route',
      debugShowCheckedModeBanner: false,

      // ── Theme ────────────────────────────────────────────────────────────
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,

      // ── Router ───────────────────────────────────────────────────────────
      routerConfig: router,
    );
  }
}
