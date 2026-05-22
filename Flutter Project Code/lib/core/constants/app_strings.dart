/// ─────────────────────────────────────────────────────────────────────────────
/// AppStrings
/// All user-facing text in one place.
/// ─────────────────────────────────────────────────────────────────────────────
abstract final class AppStrings {
  // ── Brand ────────────────────────────────────────────────────────────────────
  static const String appName = 'Spice Route';
  static const String tagline = 'Taste the Tradition';

  // ── Auth – Login ─────────────────────────────────────────────────────────────
  static const String welcomeBack = 'Welcome back.';
  static const String loginSubhead = 'Sign in to your account';
  static const String emailLabel = 'Email address';
  static const String emailHint = 'you@example.com';
  static const String passwordLabel = 'Password';
  static const String passwordHint = 'Min. 8 characters';
  static const String forgotPwd = 'Forgot password?';
  static const String signIn = 'Sign In';
  static const String noAccount = "Don't have an account?";
  static const String signUpLink = 'Sign Up';

  // ── Auth – Signup ─────────────────────────────────────────────────────────────
  static const String createAccount = 'Create account.';
  static const String signupSubhead = 'Join Spice Route today';
  static const String nameLabel = 'Full name';
  static const String nameHint = 'Priya Sharma';
  static const String phoneLabel = 'Phone number (optional)';
  static const String phoneHint = '9XXXXXXXXX';
  static const String signUpBtn = 'Create Account';
  static const String haveAccount = 'Already have an account?';
  static const String signInLink = 'Sign In';
  static const String termsNote =
      'By signing up, you agree to our Terms & Privacy Policy.';

  // ── Auth – OTP ───────────────────────────────────────────────────────────────
  static const String checkInbox = 'Check your inbox.';
  static const String otpSubhead = "We've sent a 6-digit code to";
  static const String otpExpiry = 'Code expires in';
  static const String didntGet = "Didn't receive it?";
  static const String resendCode = 'Resend code';
  static const String verifyBtn = 'Verify & Continue';
  static const String invalidOtp = 'Invalid or expired OTP. Please try again.';

  // ── Auth – Forgot / Reset Password ───────────────────────────────────────────
  static const String forgotTitle = 'Reset password.';
  static const String forgotSubhead =
      "Enter your email and we'll send a reset code";
  static const String sendOtp = 'Send Reset Code';
  static const String newPwdLabel = 'New password';
  static const String confirmPwdLabel = 'Confirm new password';
  static const String resetBtn = 'Reset Password';
  static const String pwdMismatch = 'Passwords do not match';
  static const String pwdTooShort = 'Password must be at least 8 characters';

  // ── Errors ───────────────────────────────────────────────────────────────────
  static const String networkError =
      'Network error. Please check your connection.';
  static const String genericError = 'Something went wrong. Please try again.';
  static const String fieldRequired = 'This field is required';
  static const String invalidEmail = 'Please enter a valid email address';
  static const String invalidPhone =
      'Enter a valid 10-digit Indian mobile number';
}
