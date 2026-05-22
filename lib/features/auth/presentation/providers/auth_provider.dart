import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/auth_repository.dart';
import '../../domain/models/auth_state.dart';
import '../../domain/models/user_model.dart';

export '../../domain/models/auth_state.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// AuthNotifier
/// The single state machine for the entire authentication lifecycle.
/// Notifies GoRouter via [_AuthChangeNotifier] in app_router.dart.
/// ─────────────────────────────────────────────────────────────────────────────
final class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Kick off the startup check asynchronously without blocking the build.
    Future.microtask(_checkStoredSession);
    return const AuthInitial();
  }

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  // ── Startup ──────────────────────────────────────────────────────────────

  /// Reads the cached user from SharedPreferences.
  /// If found → AuthAuthenticated; else → AuthUnauthenticated.
  Future<void> _checkStoredSession() async {
    state = const AuthLoading();
    await Future.delayed(const Duration(milliseconds: 1200)); // min splash time
    final user = _repo.getCachedUser();
    state =
        user != null ? AuthAuthenticated(user) : const AuthUnauthenticated();
  }

  // ── Login ─────────────────────────────────────────────────────────────────

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = const AuthLoading();
    final result = await _repo.login(email: email, password: password);
    if (result.success && result.user != null) {
      state = AuthAuthenticated(result.user!);
    } else {
      state = AuthError(result.error ?? 'Login failed');
    }
  }

  // ── Signup ────────────────────────────────────────────────────────────────

  Future<void> signup({
    required String name,
    required String email,
    required String password,
    String phone = '',
  }) async {
    state = const AuthLoading();
    final result = await _repo.signup(
      name: name,
      email: email,
      password: password,
      phone: phone,
    );
    if (result.success) {
      state = AuthOtpPending(email: email, purpose: 'signup', name: name);
    } else {
      state = AuthError(result.error ?? 'Signup failed');
    }
  }

  // ── OTP verify ────────────────────────────────────────────────────────────

  Future<void> verifyOtp({
    required String email,
    required String otp,
    required String purpose,
  }) async {
    state = const AuthLoading();
    final result = await _repo.verifyOtp(
      email: email,
      otp: otp,
      purpose: purpose,
    );
    if (result.success) {
      if (purpose == 'signup' && result.user != null) {
        state = AuthAuthenticated(result.user!);
      } else {
        // For 'reset' purpose we go to reset password screen
        state = const AuthUnauthenticated();
      }
    } else {
      state = AuthError(result.error ?? 'OTP verification failed');
    }
  }

  // ── Forgot / Reset ────────────────────────────────────────────────────────

  Future<({bool success, String? error})> forgotPassword(String email) async {
    state = const AuthLoading();
    final result = await _repo.forgotPassword(email: email);
    state = const AuthUnauthenticated();
    return (success: result.success, error: result.error);
  }

  Future<({bool success, String? error})> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    state = const AuthLoading();
    final result = await _repo.resetPassword(
      email: email,
      otp: otp,
      newPassword: newPassword,
    );
    state = const AuthUnauthenticated();
    return (success: result.success, error: result.error);
  }

  // ── Resend OTP ────────────────────────────────────────────────────────────

  Future<({bool success, String? error})> resendOtp({
    required String email,
    required String purpose,
  }) async {
    final result = await _repo.resendOtp(email: email, purpose: purpose);
    return (success: result.success, error: result.error);
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthUnauthenticated();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Clear error state back to unauthenticated (for form resets).
  void clearError() {
    if (state is AuthError) state = const AuthUnauthenticated();
  }

  UserModel? get currentUser =>
      state is AuthAuthenticated ? (state as AuthAuthenticated).user : null;
}

/// Top-level provider consumed throughout the app.
final authNotifierProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
