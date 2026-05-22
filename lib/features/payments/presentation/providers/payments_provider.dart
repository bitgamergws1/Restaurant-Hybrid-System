import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/payments_repository.dart';

// ── State ─────────────────────────────────────────────────────────────────────

sealed class PaymentState {
  const PaymentState();
}

final class PaymentIdle extends PaymentState {
  const PaymentIdle();
}

final class PaymentLoading extends PaymentState {
  const PaymentLoading();
}

final class PaymentSuccess extends PaymentState {
  const PaymentSuccess({
    required this.orderId,
    required this.verifiedAt,
  });
  final String orderId;
  final String verifiedAt;
}

final class PaymentError extends PaymentState {
  const PaymentError(this.message);
  final String message;
}

// ── Invoice state ─────────────────────────────────────────────────────────────

sealed class InvoiceState {
  const InvoiceState();
}

final class InvoiceIdle extends InvoiceState {
  const InvoiceIdle();
}

final class InvoiceLoading extends InvoiceState {
  const InvoiceLoading();
}

final class InvoiceSent extends InvoiceState {
  const InvoiceSent();
}

final class InvoiceError extends InvoiceState {
  const InvoiceError(this.message);
  final String message;
}

// ── Payment notifier ──────────────────────────────────────────────────────────

final class PaymentNotifier extends AutoDisposeNotifier<PaymentState> {
  @override
  PaymentState build() => const PaymentIdle();

  PaymentsRepository get _repo => ref.read(paymentsRepositoryProvider);

  Future<void> verify({
    required String orderId,
    required String razorpayPaymentId,
    required String razorpayOrderId,
  }) async {
    state = const PaymentLoading();

    final result = await _repo.verifyPayment(
      orderId: orderId,
      razorpayPaymentId: razorpayPaymentId,
      razorpayOrderId: razorpayOrderId,
    );

    if (result.success) {
      final verifiedAt = result.payment?['verified_at'] as String? ??
          DateTime.now().toIso8601String();
      state = PaymentSuccess(orderId: orderId, verifiedAt: verifiedAt);
    } else {
      state = PaymentError(
        result.error ?? 'Payment verification failed. Please try again.',
      );
    }
  }

  void reset() => state = const PaymentIdle();
}

final paymentProvider =
    AutoDisposeNotifierProvider<PaymentNotifier, PaymentState>(
  PaymentNotifier.new,
);

// ── Invoice notifier ──────────────────────────────────────────────────────────

final class InvoiceNotifier extends AutoDisposeNotifier<InvoiceState> {
  @override
  InvoiceState build() => const InvoiceIdle();

  Future<void> send(String orderId) async {
    state = const InvoiceLoading();

    final result =
        await ref.read(paymentsRepositoryProvider).sendInvoice(orderId);

    state = result.success
        ? const InvoiceSent()
        : InvoiceError(result.error ?? 'Could not send invoice.');
  }

  void reset() => state = const InvoiceIdle();
}

final invoiceProvider =
    AutoDisposeNotifierProvider<InvoiceNotifier, InvoiceState>(
  InvoiceNotifier.new,
);
