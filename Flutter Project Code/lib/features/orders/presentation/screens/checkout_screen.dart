import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/route_names.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../providers/orders_provider.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String _orderType = 'dine_in';

  // Dine-in
  final _tableCtrl = TextEditingController();

  // Delivery
  final _pincodeCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  // Common
  final _notesCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _tableCtrl.dispose();
    _pincodeCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final cartItems = ref.read(cartProvider);
    if (cartItems.isEmpty) {
      _showSnack('Your cart is empty', AppColors.error);
      return;
    }

    final items = cartItems
        .map((c) => {
              'menu_item_id': c.menuItemId,
              'quantity': c.quantity,
            })
        .toList();

    await ref.read(createOrderProvider.notifier).placeOrder(
          orderType: _orderType,
          items: items,
          tableId: _orderType == 'dine_in' ? _tableCtrl.text.trim() : null,
          pincode: _orderType == 'delivery' ? _pincodeCtrl.text.trim() : null,
          addressLine:
              _orderType == 'delivery' ? _addressCtrl.text.trim() : null,
          specialInstructions: _notesCtrl.text.trim(),
        );
  }

  /// Launches the QR scanner sheet and populates the table number field.
  Future<void> _scanTableQr() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _QrScannerSheet(),
    );

    if (result != null && result.isNotEmpty && mounted) {
      // QR encodes either a plain table_number string or a JSON payload.
      // Try to parse JSON first; fall back to treating the raw string as the
      // table number (e.g. "T5", "7").
      String tableNumber = result.trim();
      try {
        // JSON format: {"table_number":"T5"} or {"table":"T5","token":"uuid"}
        final decoded = _tryParseTableJson(result);
        if (decoded != null) tableNumber = decoded;
      } catch (_) {
        // Not JSON — use raw string
      }

      _tableCtrl.text = tableNumber;
      _showSnack('Table $tableNumber scanned successfully!', AppColors.success);
    }
  }

  String? _tryParseTableJson(String raw) {
    if (!raw.startsWith('{')) return null;
    // Very lightweight parse — avoids importing dart:convert just for this.
    final tableMatch =
        RegExp(r'"table(?:_number)?"\s*:\s*"([^"]+)"').firstMatch(raw);
    return tableMatch?.group(1);
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cartItems = ref.watch(cartProvider);
    final subtotal = ref.watch(cartSubtotalProvider);
    final gst = ref.watch(cartGstProvider);
    final total = ref.watch(cartTotalProvider);
    final orderState = ref.watch(createOrderProvider);

    // Listen for success / error
    ref.listen<CreateOrderState>(createOrderProvider, (_, next) {
      if (next is CreateOrderSuccess) {
        ref.read(cartProvider.notifier).clear();
        if (_orderType == 'dine_in') {
          // Dine-in: pay later at counter — go to order detail, skip payment
          _showSnack('Order placed! Pay at the counter when done 🍽️',
              AppColors.success);
          context.goNamed(
            RouteNames.orderDetail,
            pathParameters: {'id': next.order.id},
          );
        } else {
          // Delivery: proceed to online payment
          _showSnack('Order placed successfully!', AppColors.success);
          context.goNamed(
            RouteNames.payment,
            queryParameters: {
              'orderId': next.order.id,
              'total': next.order.totalAmount.toString(),
            },
          );
        }
      } else if (next is CreateOrderError) {
        _showSnack(next.message, AppColors.error);
        ref.read(createOrderProvider.notifier).reset();
      }
    });

    final isLoading = orderState is CreateOrderLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 18),
          onPressed: () => context.pop(),
        ),
        title: Text('Checkout',
            style: GoogleFonts.syne(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Order type picker ─────────────────────────────────
                    Text('Order Type',
                        style: GoogleFonts.syne(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                            letterSpacing: 0.5)),
                    const SizedBox(height: 10),
                    Row(children: [
                      _TypeCard(
                        icon: Icons.table_restaurant_rounded,
                        label: 'Dine-In',
                        selected: _orderType == 'dine_in',
                        onTap: () => setState(() => _orderType = 'dine_in'),
                      ),
                      const SizedBox(width: 12),
                      _TypeCard(
                        icon: Icons.delivery_dining_rounded,
                        label: 'Delivery',
                        selected: _orderType == 'delivery',
                        onTap: () => setState(() => _orderType = 'delivery'),
                        accentColor: AppColors.info,
                      ),
                    ]).animate().fadeIn(delay: 100.ms),

                    const SizedBox(height: 24),

                    // ── Type-specific fields ──────────────────────────────
                    if (_orderType == 'dine_in')
                      _DineInFields(
                        tableCtrl: _tableCtrl,
                        onScanQr: _scanTableQr,
                      ).animate().fadeIn().slideX(begin: -0.04)
                    else
                      _DeliveryFields(
                        pincodeCtrl: _pincodeCtrl,
                        addressCtrl: _addressCtrl,
                      ).animate().fadeIn().slideX(begin: 0.04),

                    const SizedBox(height: 24),

                    // ── Special instructions ──────────────────────────────
                    Text('Special Instructions',
                        style: GoogleFonts.syne(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                            letterSpacing: 0.5)),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _notesCtrl,
                      maxLines: 3,
                      style: GoogleFonts.dmSans(
                          fontSize: 14, color: AppColors.textPrimary),
                      cursorColor: AppColors.primary,
                      decoration: InputDecoration(
                        hintText: 'Any allergies or special requests...',
                        hintStyle: GoogleFonts.dmSans(
                            fontSize: 13, color: AppColors.textDisabled),
                        filled: true,
                        fillColor: AppColors.surfaceAlt,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 1.5),
                        ),
                      ),
                    ).animate().fadeIn(delay: 300.ms),

                    const SizedBox(height: 24),

                    // ── Order summary ─────────────────────────────────────
                    Text('Order Summary',
                        style: GoogleFonts.syne(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                            letterSpacing: 0.5)),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Items
                            ...cartItems.map((c) => Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(children: [
                                    Text('${c.quantity}×',
                                        style: GoogleFonts.syne(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primary)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                        child: Text(c.name,
                                            style: GoogleFonts.dmSans(
                                                fontSize: 13,
                                                color:
                                                    AppColors.textSecondary))),
                                    Text(
                                        'Rs. ${c.itemTotal.toStringAsFixed(0)}',
                                        style: GoogleFonts.dmSans(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textSecondary)),
                                  ]),
                                )),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child:
                                  Divider(color: AppColors.border, height: 1),
                            ),
                            _SummaryRow('Subtotal',
                                'Rs. ${subtotal.toStringAsFixed(2)}'),
                            const SizedBox(height: 6),
                            _SummaryRow(
                                'GST (18%)', 'Rs. ${gst.toStringAsFixed(2)}'),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child:
                                  Divider(color: AppColors.border, height: 1),
                            ),
                            Row(children: [
                              Text('Total',
                                  style: GoogleFonts.syne(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary)),
                              const Spacer(),
                              Text('Rs. ${total.toStringAsFixed(2)}',
                                  style: GoogleFonts.syne(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary)),
                            ]),
                          ]),
                    ).animate().fadeIn(delay: 350.ms),
                  ]),
            ),
          ),

          // ── Place order button ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: isLoading ? null : _placeOrder,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: isLoading ? null : AppColors.primaryGradient,
                      color: isLoading ? AppColors.surfaceAlt : null,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: isLoading
                        ? const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  valueColor:
                                      AlwaysStoppedAnimation(AppColors.primary),
                                  strokeWidth: 2),
                            ),
                          )
                        : Text('Place Order',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.syne(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── QR Scanner bottom sheet ───────────────────────────────────────────────────

class _QrScannerSheet extends StatefulWidget {
  const _QrScannerSheet();

  @override
  State<_QrScannerSheet> createState() => _QrScannerSheetState();
}

class _QrScannerSheetState extends State<_QrScannerSheet> {
  final MobileScannerController _controller = MobileScannerController();
  bool _scanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(children: [
          // Handle + title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Text('Scan Table QR',
                    style: GoogleFonts.syne(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white60, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
              Text('Point camera at the QR code on your table',
                  style:
                      GoogleFonts.dmSans(fontSize: 12, color: Colors.white38)),
            ]),
          ),

          // Camera view
          Expanded(
            child: Stack(children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(16)),
                child: MobileScanner(
                  controller: _controller,
                  onDetect: (capture) {
                    if (_scanned) return;
                    final barcode = capture.barcodes.firstOrNull;
                    final raw = barcode?.rawValue;
                    if (raw != null && raw.isNotEmpty) {
                      _scanned = true;
                      Navigator.pop(context, raw);
                    }
                  },
                ),
              ),

              // Scan overlay frame
              Center(
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.primary, width: 2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Stack(children: [
                    // Corner accents
                    for (final a in [
                      Alignment.topLeft,
                      Alignment.topRight,
                      Alignment.bottomLeft,
                      Alignment.bottomRight,
                    ])
                      Align(
                        alignment: a,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            border: Border(
                              top: a == Alignment.topLeft ||
                                      a == Alignment.topRight
                                  ? const BorderSide(
                                      color: AppColors.primary, width: 3)
                                  : BorderSide.none,
                              bottom: a == Alignment.bottomLeft ||
                                      a == Alignment.bottomRight
                                  ? const BorderSide(
                                      color: AppColors.primary, width: 3)
                                  : BorderSide.none,
                              left: a == Alignment.topLeft ||
                                      a == Alignment.bottomLeft
                                  ? const BorderSide(
                                      color: AppColors.primary, width: 3)
                                  : BorderSide.none,
                              right: a == Alignment.topRight ||
                                      a == Alignment.bottomRight
                                  ? const BorderSide(
                                      color: AppColors.primary, width: 3)
                                  : BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                  ]),
                ),
              ),

              // Torch toggle
              Positioned(
                bottom: 20,
                right: 20,
                child: IconButton(
                  onPressed: () => _controller.toggleTorch(),
                  icon: const Icon(Icons.flashlight_on_rounded,
                      color: Colors.white70, size: 26),
                ),
              ),
            ]),
          ),
        ]),
      );
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.accentColor = AppColors.primary,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color accentColor;

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: selected
                  ? accentColor.withValues(alpha: 0.12)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? accentColor : AppColors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Column(children: [
              Icon(icon,
                  color: selected ? accentColor : AppColors.textMuted,
                  size: 26),
              const SizedBox(height: 8),
              Text(label,
                  style: GoogleFonts.syne(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: selected ? accentColor : AppColors.textTertiary)),
            ]),
          ),
        ),
      );
}

class _DineInFields extends StatelessWidget {
  const _DineInFields({
    required this.tableCtrl,
    required this.onScanQr,
  });
  final TextEditingController tableCtrl;
  final VoidCallback onScanQr;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('Table Number',
                style: GoogleFonts.syne(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                    letterSpacing: 0.5)),
            const Spacer(),
            // QR scan shortcut
            GestureDetector(
              onTap: onScanQr,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.qr_code_scanner_rounded,
                      size: 14, color: AppColors.primary),
                  const SizedBox(width: 5),
                  Text('Scan QR',
                      style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          TextFormField(
            controller: tableCtrl,
            keyboardType: TextInputType.text,
            style:
                GoogleFonts.dmSans(fontSize: 14, color: AppColors.textPrimary),
            cursorColor: AppColors.primary,
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Please enter your table number or scan the QR code';
              }
              return null;
            },
            decoration: _inputDecoration('e.g. T5 or scan the table QR code'),
          ),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.info_outline_rounded,
                size: 13, color: AppColors.textDisabled),
            const SizedBox(width: 6),
            Text(
              'Scan the QR code on your table for instant fill-in',
              style: GoogleFonts.dmSans(
                  fontSize: 11, color: AppColors.textDisabled),
            ),
          ]),
        ],
      );
}

class _DeliveryFields extends StatelessWidget {
  const _DeliveryFields({required this.pincodeCtrl, required this.addressCtrl});
  final TextEditingController pincodeCtrl;
  final TextEditingController addressCtrl;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pincode',
              style: GoogleFonts.syne(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                  letterSpacing: 0.5)),
          const SizedBox(height: 10),
          TextFormField(
            controller: pincodeCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            style:
                GoogleFonts.dmSans(fontSize: 14, color: AppColors.textPrimary),
            cursorColor: AppColors.primary,
            validator: (v) {
              if (v == null || v.trim().length != 6) {
                return 'Enter a valid 6-digit pincode';
              }
              return null;
            },
            decoration: _inputDecoration('6-digit Indian pincode',
                counter: const SizedBox.shrink()),
          ),
          const SizedBox(height: 16),
          Text('Delivery Address',
              style: GoogleFonts.syne(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                  letterSpacing: 0.5)),
          const SizedBox(height: 10),
          TextFormField(
            controller: addressCtrl,
            maxLines: 3,
            style:
                GoogleFonts.dmSans(fontSize: 14, color: AppColors.textPrimary),
            cursorColor: AppColors.primary,
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Please enter your delivery address';
              }
              return null;
            },
            decoration: _inputDecoration('House no., street, area...'),
          ),
        ],
      );
}

InputDecoration _inputDecoration(String hint, {Widget? counter}) =>
    InputDecoration(
      hintText: hint,
      counter: counter,
      hintStyle:
          GoogleFonts.dmSans(fontSize: 13, color: AppColors.textDisabled),
      filled: true,
      fillColor: AppColors.surfaceAlt,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
    );

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(children: [
        Text(label,
            style:
                GoogleFonts.dmSans(fontSize: 13, color: AppColors.textMuted)),
        const Spacer(),
        Text(value,
            style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
      ]);
}
