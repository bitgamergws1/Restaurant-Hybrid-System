import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinput/pinput.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/router/route_names.dart';
import '../providers/auth_provider.dart';
import '../widgets/spice_button.dart';
import '../widgets/auth_text_field.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// OtpScreen
/// Handles both signup OTP verification AND password-reset flow.
///
/// When [isReset] is false  → verify OTP to activate account → auto-login.
/// When [isReset] is true   → two-step: verify OTP first, then show new
///                            password fields.
/// ─────────────────────────────────────────────────────────────────────────────
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({
    super.key,
    required this.email,
    required this.purpose,
    required this.name,
    this.isReset = false,
  });

  final String email;
  final String purpose;
  final String name;
  final bool isReset;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _pinController = TextEditingController();
  final _pwdCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  /// Phase 1 = enter OTP; Phase 2 = enter new password (reset flow only)
  bool _otpVerified = false;
  String _verifiedOtp = '';

  // Countdown
  static const _countdownSec = 60;
  int _secondsLeft = _countdownSec;
  Timer? _timer;

  bool get _canResend => _secondsLeft == 0;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pinController.dispose();
    _pwdCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _countdownSec);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft == 0) {
        t.cancel();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _verifyOtp(String otp) async {
    if (otp.length < 6) return;

    // For reset flow, just mark OTP verified locally and show password fields
    if (widget.isReset) {
      // Verify via backend first to ensure the OTP is valid
      await ref.read(authNotifierProvider.notifier).verifyOtp(
            email: widget.email,
            otp: otp,
            purpose: 'reset',
          );
      // verifyOtp emits AuthUnauthenticated for reset — check error
      final state = ref.read(authNotifierProvider);
      if (state is! AuthError) {
        setState(() {
          _otpVerified = true;
          _verifiedOtp = otp;
        });
      }
      return;
    }

    // Signup flow — verifyOtp will emit AuthAuthenticated on success
    await ref.read(authNotifierProvider.notifier).verifyOtp(
          email: widget.email,
          otp: otp,
          purpose: widget.purpose,
        );
  }

  Future<void> _submitNewPassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final result = await ref.read(authNotifierProvider.notifier).resetPassword(
          email: widget.email,
          otp: _verifiedOtp,
          newPassword: _pwdCtrl.text,
        );

    if (!mounted) return;

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Password reset! Please sign in.',
            style: GoogleFonts.dmSans(color: Colors.white),
          ),
          backgroundColor: AppColors.success,
        ),
      );
      context.goNamed(RouteNames.login);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? AppStrings.genericError),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _resend() async {
    if (!_canResend) return;
    await ref.read(authNotifierProvider.notifier).resendOtp(
          email: widget.email,
          purpose: widget.purpose,
        );
    _startCountdown();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState is AuthLoading;

    // Error listener
    ref.listen<AuthState>(authNotifierProvider, (_, next) {
      if (next is AuthError) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(next.message),
              backgroundColor: AppColors.error,
            ),
          );
        Future.microtask(
          () => ref.read(authNotifierProvider.notifier).clearError(),
        );
        _pinController.clear();
      }
    });

    // ── Pinput theme ─────────────────────────────────────────────────────────
    const boxSize = Size(52, 60);
    final defaultTheme = PinTheme(
      width: boxSize.width,
      height: boxSize.height,
      textStyle: GoogleFonts.syne(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
    );

    final focusedTheme = defaultTheme.copyWith(
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 12,
          )
        ],
      ),
    );

    final filledTheme = defaultTheme.copyWith(
      decoration: BoxDecoration(
        color: AppColors.primaryTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // Back button
              _BackButton(onTap: () => context.pop())
                  .animate()
                  .fadeIn(duration: 300.ms),

              const SizedBox(height: 40),

              // ── Show OTP entry OR new-password form ──────────────────────
              if (!_otpVerified) ...[
                // ── OTP Phase ───────────────────────────────────────────────
                Text(
                  AppStrings.checkInbox,
                  style: GoogleFonts.syne(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.1,
                  ),
                ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2),

                const SizedBox(height: 8),

                RichText(
                  text: TextSpan(
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      color: AppColors.textTertiary,
                      height: 1.5,
                    ),
                    children: [
                      const TextSpan(text: '${AppStrings.otpSubhead} '),
                      TextSpan(
                        text: _maskEmail(widget.email),
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 150.ms),

                const SizedBox(height: 48),

                // ── Pinput ──────────────────────────────────────────────────
                Center(
                  child: Pinput(
                    length: 6,
                    controller: _pinController,
                    defaultPinTheme: defaultTheme,
                    focusedPinTheme: focusedTheme,
                    submittedPinTheme: filledTheme,
                    separatorBuilder: (_) => const SizedBox(width: 10),
                    onCompleted: _verifyOtp,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                  ),
                )
                    .animate()
                    .fadeIn(delay: 250.ms)
                    .scale(begin: const Offset(0.9, 0.9)),

                const SizedBox(height: 40),

                SpiceButton(
                  label: AppStrings.verifyBtn,
                  onPressed: () => _verifyOtp(_pinController.text),
                  isLoading: isLoading,
                  enabled: _pinController.text.length == 6,
                ).animate().fadeIn(delay: 300.ms),

                const SizedBox(height: 32),

                // ── Resend / countdown ──────────────────────────────────────
                Center(
                  child: _secondsLeft > 0
                      ? RichText(
                          text: TextSpan(
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              color: AppColors.textMuted,
                            ),
                            children: [
                              const TextSpan(text: '${AppStrings.otpExpiry} '),
                              TextSpan(
                                text:
                                    '0:${_secondsLeft.toString().padLeft(2, '0')}',
                                style: GoogleFonts.syne(
                                  fontSize: 13,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        )
                      : GestureDetector(
                          onTap: _resend,
                          child: RichText(
                            text: TextSpan(
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                color: AppColors.textMuted,
                              ),
                              children: [
                                const TextSpan(text: '${AppStrings.didntGet} '),
                                TextSpan(
                                  text: AppStrings.resendCode,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 13,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                    decoration: TextDecoration.underline,
                                    decorationColor: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ).animate().fadeIn(delay: 350.ms),
              ] else ...[
                // ── Reset Password Phase ─────────────────────────────────────
                Text(
                  'New Password.',
                  style: GoogleFonts.syne(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ).animate().fadeIn().slideY(begin: 0.2),

                const SizedBox(height: 8),

                Text(
                  'OTP verified. Set your new password below.',
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    color: AppColors.textTertiary,
                  ),
                ).animate().fadeIn(delay: 100.ms),

                const SizedBox(height: 36),

                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      AuthTextField(
                        label: AppStrings.newPwdLabel,
                        hint: AppStrings.passwordHint,
                        controller: _pwdCtrl,
                        obscureText: true,
                        prefixIcon: Icons.lock_outline_rounded,
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return AppStrings.fieldRequired;
                          }
                          if (v.length < 8) return AppStrings.pwdTooShort;
                          return null;
                        },
                      ).animate().fadeIn(delay: 150.ms),
                      const SizedBox(height: 20),
                      AuthTextField(
                        label: AppStrings.confirmPwdLabel,
                        hint: AppStrings.passwordHint,
                        controller: _confirmCtrl,
                        obscureText: true,
                        prefixIcon: Icons.lock_outline_rounded,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submitNewPassword(),
                        validator: (v) {
                          if (v != _pwdCtrl.text) return AppStrings.pwdMismatch;
                          return null;
                        },
                      ).animate().fadeIn(delay: 200.ms),
                      const SizedBox(height: 32),
                      SpiceButton(
                        label: AppStrings.resetBtn,
                        onPressed: _submitNewPassword,
                        isLoading: isLoading,
                      ).animate().fadeIn(delay: 250.ms),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 3) return '${name[0]}***@$domain';
    return '${name.substring(0, 3)}***@$domain';
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
            color: AppColors.surfaceAlt,
          ),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textSecondary,
            size: 16,
          ),
        ),
      );
}
