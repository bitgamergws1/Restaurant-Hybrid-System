import 'user_model.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// AuthState  (sealed)
/// Every possible state of the authentication lifecycle.
/// Dart 3 sealed class → exhaustive pattern matching in switch expressions.
/// ─────────────────────────────────────────────────────────────────────────────
sealed class AuthState {
  const AuthState();
}

/// App just launched — checking SharedPreferences for an existing token.
final class AuthInitial extends AuthState {
  const AuthInitial();
}

/// An async auth operation is in progress.
final class AuthLoading extends AuthState {
  const AuthLoading();
}

/// Token found and user is fully authenticated.
final class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);
  final UserModel user;
}

/// No token, or the token was rejected by the backend.
final class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// An auth operation failed (login, signup, OTP verify, etc.)
final class AuthError extends AuthState {
  const AuthError(this.message);
  final String message;
}

/// Signup submitted — OTP sent, waiting for verification.
/// Carries enough context to render the OTP screen without extra providers.
final class AuthOtpPending extends AuthState {
  const AuthOtpPending({
    required this.email,
    required this.purpose,
    required this.name,
  });

  final String email;
  final String purpose; // 'signup' | 'reset'
  final String name;
}
