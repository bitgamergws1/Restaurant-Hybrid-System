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

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();

  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _pwdFocus = FocusNode();

  @override
  void dispose() {
    for (final c in [_nameCtrl, _emailCtrl, _phoneCtrl, _pwdCtrl]) {
      c.dispose();
    }
    for (final f in [_nameFocus, _emailFocus, _phoneFocus, _pwdFocus]) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref.read(authNotifierProvider.notifier).signup(
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          password: _pwdCtrl.text,
          phone: _phoneCtrl.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState is AuthLoading;

    // On OTP pending → navigate to OTP screen
    ref.listen<AuthState>(authNotifierProvider, (_, next) {
      if (next is AuthOtpPending) {
        context.pushNamed(
          RouteNames.otp,
          queryParameters: {
            'email': next.email,
            'purpose': next.purpose,
            'name': next.name,
          },
        );
      } else if (next is AuthError) {
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
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background glow (bottom-left)
          Positioned(
            bottom: -100,
            left: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.10),
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
                    // ── Back + Logo row ────────────────────────────────────
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _BackButton(onTap: () => context.pop()),
                        const Spacer(),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                            color: AppColors.surfaceAlt,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.asset(
                            'assets/images/route.png',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.restaurant,
                              color: AppColors.primary,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ).animate().fadeIn(duration: 300.ms),

                    const SizedBox(height: 32),

                    Text(
                      AppStrings.createAccount,
                      style: GoogleFonts.syne(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        height: 1.1,
                      ),
                    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2),

                    const SizedBox(height: 6),

                    Text(
                      AppStrings.signupSubhead,
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        color: AppColors.textTertiary,
                      ),
                    ).animate().fadeIn(delay: 150.ms),

                    const SizedBox(height: 36),

                    // ── Name ───────────────────────────────────────────────
                    AuthTextField(
                      label: AppStrings.nameLabel,
                      hint: AppStrings.nameHint,
                      controller: _nameCtrl,
                      focusNode: _nameFocus,
                      textInputAction: TextInputAction.next,
                      prefixIcon: Icons.person_outline_rounded,
                      autofillHints: const [AutofillHints.name],
                      onFieldSubmitted: (_) =>
                          FocusScope.of(context).requestFocus(_emailFocus),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? AppStrings.fieldRequired
                          : null,
                    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),

                    const SizedBox(height: 20),

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
                          FocusScope.of(context).requestFocus(_phoneFocus),
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
                    ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.1),

                    const SizedBox(height: 20),

                    // ── Phone (optional) ───────────────────────────────────
                    AuthTextField(
                      label: AppStrings.phoneLabel,
                      hint: AppStrings.phoneHint,
                      controller: _phoneCtrl,
                      focusNode: _phoneFocus,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      prefixIcon: Icons.phone_outlined,
                      maxLength: 10,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      onFieldSubmitted: (_) =>
                          FocusScope.of(context).requestFocus(_pwdFocus),
                      validator: (v) {
                        if (v == null || v.isEmpty) return null; // optional
                        final re = RegExp(r'^[6-9]\d{9}$');
                        if (!re.hasMatch(v.trim())) {
                          return AppStrings.invalidPhone;
                        }
                        return null;
                      },
                    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),

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
                      autofillHints: const [AutofillHints.newPassword],
                      onFieldSubmitted: (_) => _submit(),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return AppStrings.fieldRequired;
                        }
                        if (v.length < 8) return AppStrings.pwdTooShort;
                        return null;
                      },
                    ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.1),

                    const SizedBox(height: 28),

                    SpiceButton(
                      label: AppStrings.signUpBtn,
                      onPressed: _submit,
                      isLoading: isLoading,
                    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),

                    const SizedBox(height: 20),

                    // Terms note
                    Center(
                      child: Text(
                        AppStrings.termsNote,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: AppColors.textDisabled,
                          height: 1.5,
                        ),
                      ),
                    ).animate().fadeIn(delay: 450.ms),

                    const SizedBox(height: 28),

                    // Already have account
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          AppStrings.haveAccount,
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.pop(),
                          child: Text(
                            AppStrings.signInLink,
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
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
