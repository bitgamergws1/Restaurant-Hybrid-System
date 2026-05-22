import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/route_names.dart';
import '../../data/payments_repository.dart'; // fixed: was '../data/' (wrong path)

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({
    super.key,
    required this.orderId,
    required this.totalAmount,
  });
  final String orderId;
  final double totalAmount;

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  bool _isProcessing = false;
  bool _isSuccess = false;
  String? _error;

  // Mock Razorpay test IDs (Phase 1 — real integration in Phase 2)
  static const _mockPaymentId = 'pay_MockTest123456';
  static const _mockOrderId = 'order_MockTest123';

  Future<void> _processPayment() async {
    setState(() {
      _isProcessing = true;
      _error = null;
    });

    await Future.delayed(const Duration(milliseconds: 1800));

    final result = await ref.read(paymentsRepositoryProvider).verifyPayment(
          orderId: widget.orderId,
          razorpayPaymentId: _mockPaymentId,
          razorpayOrderId: _mockOrderId,
        );

    if (!mounted) return;

    if (result.success) {
      // Auto-send receipt to user's registered email — fire-and-forget
      ref.read(paymentsRepositoryProvider).sendInvoice(widget.orderId);
      setState(() {
        _isProcessing = false;
        _isSuccess = true;
      });
      HapticFeedback.heavyImpact();
    } else {
      setState(() {
        _isProcessing = false;
        _error = result.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSuccess) return _SuccessScreen(orderId: widget.orderId);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: _isProcessing
            ? const SizedBox.shrink()
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: AppColors.textPrimary, size: 18),
                onPressed: () => context.pop(),
              ),
        title: Text('Secure Payment',
            style: GoogleFonts.syne(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Payment amount hero ──────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.15),
                  AppColors.surface,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Column(children: [
              Text('Amount to Pay',
                  style: GoogleFonts.dmSans(
                      fontSize: 13, color: AppColors.textMuted)),
              const SizedBox(height: 8),
              Text(
                'Rs. ${widget.totalAmount.toStringAsFixed(2)}',
                style: GoogleFonts.syne(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary),
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                    'Order #${widget.orderId.substring(0, 8).toUpperCase()}',
                    style: GoogleFonts.syne(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                        letterSpacing: 0.5)),
              ),
            ]),
          ).animate().fadeIn().slideY(begin: -0.06),

          const SizedBox(height: 28),

          // ── Test mode banner ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded,
                  color: AppColors.warning, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Test Mode — No real payment will be charged. Razorpay integration is in Phase 2.',
                  style: GoogleFonts.dmSans(
                      fontSize: 12, color: AppColors.warning, height: 1.4),
                ),
              ),
            ]),
          ).animate().fadeIn(delay: 100.ms),

          const SizedBox(height: 28),

          // ── Mock payment options ─────────────────────────────────────────
          Text('Select Payment Method',
              style: GoogleFonts.syne(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                  letterSpacing: 0.5)),
          const SizedBox(height: 14),

          ..._paymentMethods.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PaymentMethodTile(
                  method: e.value,
                  isSelected: e.key == 0,
                ),
              )
                  .animate()
                  .fadeIn(delay: (150 + e.key * 60).ms)
                  .slideX(begin: -0.04, delay: (150 + e.key * 60).ms)),

          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.errorTint,
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline_rounded,
                    color: AppColors.error, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(_error!,
                      style: GoogleFonts.dmSans(
                          fontSize: 12, color: AppColors.error, height: 1.4)),
                ),
              ]),
            ).animate().shake(),
          ],

          const SizedBox(height: 32),

          // ── Pay button ───────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: _isProcessing ? null : _processPayment,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  gradient: _isProcessing ? null : AppColors.primaryGradient,
                  color: _isProcessing ? AppColors.surfaceAlt : null,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _isProcessing
                      ? null
                      : [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                ),
                child: _isProcessing
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                valueColor:
                                    AlwaysStoppedAnimation(AppColors.primary),
                                strokeWidth: 2),
                          ),
                          const SizedBox(width: 12),
                          Text('Processing Payment...',
                              style: GoogleFonts.syne(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textMuted)),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.lock_rounded,
                              color: Colors.white, size: 16),
                          const SizedBox(width: 10),
                          Text(
                              'Pay Rs. ${widget.totalAmount.toStringAsFixed(2)}',
                              style: GoogleFonts.syne(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        ],
                      ),
              ),
            ),
          ).animate().fadeIn(delay: 400.ms),

          const SizedBox(height: 16),

          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.verified_user_rounded,
                color: AppColors.textDisabled, size: 13),
            const SizedBox(width: 6),
            Text('256-bit SSL encrypted payment',
                style: GoogleFonts.dmSans(
                    fontSize: 11, color: AppColors.textDisabled)),
          ]).animate().fadeIn(delay: 450.ms),
        ]),
      ),
    );
  }
}

// ── Payment methods ───────────────────────────────────────────────────────────

class _PMData {
  const _PMData(
      {required this.icon, required this.label, required this.subtitle});
  final IconData icon;
  final String label;
  final String subtitle;
}

const _paymentMethods = [
  _PMData(
    icon: Icons.account_balance_wallet_rounded,
    label: 'UPI / GPay',
    subtitle: 'Google Pay, PhonePe, Paytm & more',
  ),
  _PMData(
    icon: Icons.credit_card_rounded,
    label: 'Credit / Debit Card',
    subtitle: 'Visa, Mastercard, RuPay',
  ),
  _PMData(
    icon: Icons.account_balance_rounded,
    label: 'Net Banking',
    subtitle: 'All major Indian banks supported',
  ),
];

class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({required this.method, required this.isSelected});
  final _PMData method;
  final bool isSelected;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryTint : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.5)
                : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(method.icon,
                color: isSelected ? AppColors.primary : AppColors.textMuted,
                size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(method.label,
                  style: GoogleFonts.syne(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary)),
              const SizedBox(height: 2),
              Text(method.subtitle,
                  style: GoogleFonts.dmSans(
                      fontSize: 11, color: AppColors.textMuted)),
            ]),
          ),
          if (isSelected)
            const Icon(Icons.radio_button_checked_rounded,
                color: AppColors.primary, size: 18)
          else
            const Icon(Icons.radio_button_unchecked_rounded,
                color: AppColors.border, size: 18),
        ]),
      );
}

// ── Success screen ────────────────────────────────────────────────────────────

class _SuccessScreen extends StatelessWidget {
  const _SuccessScreen({required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.4),
                      width: 2),
                ),
                child: const Icon(Icons.check_rounded,
                    color: AppColors.success, size: 48),
              )
                  .animate()
                  .scale(
                    begin: const Offset(0, 0),
                    end: const Offset(1, 1),
                    curve: Curves.elasticOut,
                    duration: 600.ms,
                  )
                  .fadeIn(),
              const SizedBox(height: 28),
              Text('Payment Successful',
                      style: GoogleFonts.syne(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary))
                  .animate()
                  .fadeIn(delay: 400.ms)
                  .slideY(begin: 0.1, delay: 400.ms),
              const SizedBox(height: 8),
              Text('Your order has been confirmed and is being prepared.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                          fontSize: 14,
                          color: AppColors.textMuted,
                          height: 1.5))
                  .animate()
                  .fadeIn(delay: 500.ms),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.mark_email_read_outlined,
                    color: AppColors.textDisabled, size: 14),
                const SizedBox(width: 6),
                Text('Receipt sent to your registered email',
                    style: GoogleFonts.dmSans(
                        fontSize: 12, color: AppColors.textDisabled)),
              ]).animate().fadeIn(delay: 560.ms),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () => context.goNamed(
                    RouteNames.orderDetail,
                    pathParameters: {'id': orderId},
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text('View Order',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.syne(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                ),
              )
                  .animate()
                  .fadeIn(delay: 600.ms)
                  .slideY(begin: 0.1, delay: 600.ms),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.goNamed(RouteNames.menu),
                child: Text('Continue Browsing',
                    style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500)),
              ).animate().fadeIn(delay: 700.ms),
            ]),
          ),
        ),
      );
}
