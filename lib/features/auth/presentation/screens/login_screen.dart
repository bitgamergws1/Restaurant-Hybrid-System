import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/router/route_names.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/spice_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  final _emailFocus = FocusNode();
  final _pwdFocus = FocusNode();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwdCtrl.dispose();
    _emailFocus.dispose();
    _pwdFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    ref.read(authNotifierProvider.notifier).login(
          email: _emailCtrl.text.trim(),
          password: _pwdCtrl.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState is AuthLoading;
    final errorMsg = authState is AuthError ? (authState).message : null;

    // Show snackbar on error, clear after
    ref.listen<AuthState>(authNotifierProvider, (_, next) {
      if (next is AuthError) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(next.message),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        // Auto-clear so re-renders don't keep showing the error
        Future.microtask(
          () => ref.read(authNotifierProvider.notifier).clearError(),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Background glow (top-right) ──────────────────────────────────
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 48),

                    // ── Logo ───────────────────────────────────────────────
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border, width: 1),
                        color: AppColors.surfaceAlt,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset(
                        'assets/images/route.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.restaurant,
                          color: AppColors.primary,
                          size: 26,
                        ),
                      ),
                    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2),

                    const SizedBox(height: 32),

                    // ── Headline ───────────────────────────────────────────
                    Text(
                      AppStrings.welcomeBack,
                      style: GoogleFonts.syne(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        height: 1.1,
                      ),
                    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2),

                    const SizedBox(height: 6),

                    Text(
                      AppStrings.loginSubhead,
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        color: AppColors.textTertiary,
                      ),
                    ).animate().fadeIn(delay: 150.ms),

                    const SizedBox(height: 40),

                    // ── Email ──────────────────────────────────────────────
                    AuthTextField(
                      label: AppStrings.emailLabel,
                      hint: AppStrings.emailHint,
                      controller: _emailCtrl,
                      focusNode: _emailFocus,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      prefixIcon: Icons.alternate_email_rounded,
                      autofillHints: const [AutofillHints.email],
                      onFieldSubmitted: (_) =>
                          FocusScope.of(context).requestFocus(_pwdFocus),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return AppStrings.fieldRequired;
                        }
                        final re = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.]+$');
                        if (!re.hasMatch(v.trim())) {
                          return AppStrings.invalidEmail;
                        }
                        return null;
                      },
                    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.15),

                    const SizedBox(height: 20),

                    // ── Password ───────────────────────────────────────────
                    AuthTextField(
                      label: AppStrings.passwordLabel,
                      hint: AppStrings.passwordHint,
                      controller: _pwdCtrl,
                      focusNode: _pwdFocus,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      prefixIcon: Icons.lock_outline_rounded,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _submit(),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return AppStrings.fieldRequired;
                        }
                        if (v.length < 8) return AppStrings.pwdTooShort;
                        return null;
                      },
                    ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.15),

                    // ── Forgot password link ───────────────────────────────
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () =>
                            context.goNamed(RouteNames.forgotPassword),
                        child: Text(
                          AppStrings.forgotPwd,
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ).animate().fadeIn(delay: 300.ms),

                    const SizedBox(height: 8),

                    // ── Error Banner ───────────────────────────────────────
                    if (errorMsg != null) ...[
                      _ErrorBanner(message: errorMsg),
                      const SizedBox(height: 16),
                    ],

                    // ── CTA ────────────────────────────────────────────────
                    SpiceButton(
                      label: AppStrings.signIn,
                      onPressed: _submit,
                      isLoading: isLoading,
                    ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.2),

                    const SizedBox(height: 32),

                    // ── Divider ────────────────────────────────────────────
                    _OrDivider().animate().fadeIn(delay: 400.ms),

                    const SizedBox(height: 28),

                    // ── Sign up link ───────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          AppStrings.noAccount,
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.goNamed(RouteNames.signup),
                          child: Text(
                            AppStrings.signUpLink,
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 450.ms),

                    const SizedBox(height: 16),

                    // ── Staff access hint ──────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.shield_outlined,
                          size: 12,
                          color: AppColors.textDisabled,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Staff & Admin: use your assigned credentials',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: AppColors.textDisabled,
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 500.ms),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Small internal widgets ──────────────────────────────────────────────────

class _OrDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Expanded(child: Divider(color: AppColors.border)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'OR',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: AppColors.textDisabled,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const Expanded(child: Divider(color: AppColors.border)),
        ],
      );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.errorTint,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.error,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: AppColors.error,
                ),
              ),
            ),
          ],
        ),
      );
}
