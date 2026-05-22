import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/providers/shared_preferences_provider.dart';
import '../domain/models/user_model.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// AuthResult record  (Dart 3 records)
/// Lightweight return type instead of a generic Either<> monad.
/// ─────────────────────────────────────────────────────────────────────────────
typedef AuthResult = ({bool success, String? error});
typedef LoginResult = ({
  bool success,
  UserModel? user,
  String? token,
  String? error
});

/// ─────────────────────────────────────────────────────────────────────────────
/// AuthRepository
/// All network calls that relate to authentication.
/// Persists / clears the session token in [SharedPreferences].
/// ─────────────────────────────────────────────────────────────────────────────
final class AuthRepository {
  const AuthRepository(this._client, this._prefs);

  final ApiClient _client;
  final SharedPreferences _prefs;

  // ── Login ──────────────────────────────────────────────────────────────────

  Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final data = await _client.post(
        ApiEndpoints.login,
        data: {'email': email, 'password': password},
      );
      final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      final token = data['token'] as String;
      await _persistSession(token, user);
      return (success: true, user: user, token: token, error: null);
    } on ApiException catch (e) {
      return (success: false, user: null, token: null, error: e.message);
    } catch (_) {
      return (
        success: false,
        user: null,
        token: null,
        error: 'Unexpected error. Please try again.'
      );
    }
  }

  // ── Signup ────────────────────────────────────────────────────────────────

  Future<AuthResult> signup({
    required String name,
    required String email,
    required String password,
    String phone = '',
  }) async {
    try {
      await _client.post(
        ApiEndpoints.signup,
        data: {
          'name': name,
          'email': email,
          'password': password,
          if (phone.isNotEmpty) 'phone': phone,
        },
      );
      return (success: true, error: null);
    } on ApiException catch (e) {
      return (success: false, error: e.message);
    } catch (_) {
      return (success: false, error: 'Unexpected error. Please try again.');
    }
  }

  // ── Verify OTP ────────────────────────────────────────────────────────────

  Future<LoginResult> verifyOtp({
    required String email,
    required String otp,
    required String purpose,
  }) async {
    try {
      final data = await _client.post(
        ApiEndpoints.verifyOtp,
        data: {'email': email, 'otp': otp, 'purpose': purpose},
      );

      // signup OTP returns a user + token; reset OTP does not
      if (purpose == 'signup') {
        final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
        final token = data['token'] as String;
        await _persistSession(token, user);
        return (success: true, user: user, token: token, error: null);
      }
      // For reset purpose — just report success
      return (success: true, user: null, token: null, error: null);
    } on ApiException catch (e) {
      return (success: false, user: null, token: null, error: e.message);
    } catch (_) {
      return (
        success: false,
        user: null,
        token: null,
        error: 'Unexpected error.'
      );
    }
  }

  // ── Resend OTP ────────────────────────────────────────────────────────────

  Future<AuthResult> resendOtp({
    required String email,
    required String purpose,
  }) async {
    try {
      await _client.post(
        ApiEndpoints.resendOtp,
        data: {'email': email, 'purpose': purpose},
      );
      return (success: true, error: null);
    } on ApiException catch (e) {
      return (success: false, error: e.message);
    } catch (_) {
      return (success: false, error: 'Unexpected error.');
    }
  }

  // ── Forgot Password ───────────────────────────────────────────────────────

  Future<AuthResult> forgotPassword({required String email}) async {
    try {
      await _client.post(
        ApiEndpoints.forgotPassword,
        data: {'email': email},
      );
      return (success: true, error: null);
    } on ApiException catch (e) {
      return (success: false, error: e.message);
    } catch (_) {
      return (success: false, error: 'Unexpected error.');
    }
  }

  // ── Reset Password ────────────────────────────────────────────────────────

  Future<AuthResult> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    try {
      await _client.post(
        ApiEndpoints.resetPassword,
        data: {
          'email': email,
          'otp': otp,
          'new_password': newPassword,
        },
      );
      return (success: true, error: null);
    } on ApiException catch (e) {
      return (success: false, error: e.message);
    } catch (_) {
      return (success: false, error: 'Unexpected error.');
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    try {
      await _client.post(ApiEndpoints.logout);
    } catch (_) {
      // Even if the server call fails, clear local state
    } finally {
      await _clearSession();
    }
  }

  // ── Session helpers ───────────────────────────────────────────────────────

  /// Returns a [UserModel] if a valid token exists in SharedPreferences,
  /// null otherwise. Used during app startup on the splash screen.
  UserModel? getCachedUser() {
    final token = _prefs.getString(ApiConfig.tokenPrefKey);
    final userJson = _prefs.getString(ApiConfig.userPrefKey);
    if (token == null || token.isEmpty || userJson == null) return null;
    try {
      return UserModel.fromJson(
        jsonDecode(userJson) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistSession(String token, UserModel user) async {
    await _prefs.setString(ApiConfig.tokenPrefKey, token);
    await _prefs.setString(ApiConfig.userPrefKey, jsonEncode(user.toJson()));
  }

  Future<void> _clearSession() async {
    await _prefs.remove(ApiConfig.tokenPrefKey);
    await _prefs.remove(ApiConfig.userPrefKey);
  }
}

/// Provider ─────────────────────────────────────────────────────────────────
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return AuthRepository(client, prefs);
});
