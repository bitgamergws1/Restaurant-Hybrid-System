import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/providers/shared_preferences_provider.dart';
import '../../../../core/router/route_names.dart';
import '../../../admin/domain/models/restaurant_table_model.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../providers/orders_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Provider: fetches available tables for customers (non-inactive only).
// Uses the /tables/available endpoint which is auth-protected.
// ─────────────────────────────────────────────────────────────────────────────

final availableTablesProvider =
    FutureProvider.autoDispose<List<RestaurantTableModel>>((ref) async {
  final client = ref.read(apiClientProvider);
  final data = await client.get(ApiEndpoints.availableTables);
  final list = data['tables'] as List<dynamic>? ?? [];
  return list
      .map((e) => RestaurantTableModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ─────────────────────────────────────────────────────────────────────────────

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String _orderType = 'dine_in';

  // Dine-in — selected from dropdown OR filled by QR scan
  RestaurantTableModel? _selectedTable;

  // Delivery
  final _pincodeCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  // Common
  final _notesCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
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

    // Validate dine-in table selection
    if (_orderType == 'dine_in' && _selectedTable == null) {
      _showSnack('Please select a table first', AppColors.error);
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
          tableId: _orderType == 'dine_in' ? _selectedTable?.tableNumber : null,
          pincode: _orderType == 'delivery' ? _pincodeCtrl.text.trim() : null,
          addressLine:
              _orderType == 'delivery' ? _addressCtrl.text.trim() : null,
          specialInstructions: _notesCtrl.text.trim(),
        );
  }

  /// Launches the QR scanner sheet and matches scanned table against server list.
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

    if (result == null || result.isEmpty || !mounted) return;

    // Parse the QR — may be JSON {"table_number":"T-01","token":"uuid"}
    // or a plain table number string.
    String tableNumber = result.trim();
    try {
      final decoded = _tryParseTableJson(result);
      if (decoded != null) tableNumber = decoded;
    } catch (_) {}

    // Try to match against available tables
    final tables = ref.read(availableTablesProvider).valueOrNull ?? [];
    final match = tables.cast<RestaurantTableModel?>().firstWhere(
          (t) => t?.tableNumber.toLowerCase() == tableNumber.toLowerCase(),
          orElse: () => null,
        );

    if (match != null) {
      setState(() => _selectedTable = match);
      _showSnack('Table ${match.tableNumber} selected ✓', AppColors.success);
    } else {
      // Table from QR not in server list — still accept it as a string
      setState(() {
        // Create a minimal placeholder so validation passes
        _selectedTable = RestaurantTableModel(
          id: '',
          tableNumber: tableNumber,
          capacity: 0,
          floor: '',
          status: 'free',
          qrToken: '',
          createdAt: DateTime.now(),
        );
      });
      _showSnack('Table $tableNumber scanned', AppColors.success);
    }
  }

  String? _tryParseTableJson(String raw) {
    if (!raw.startsWith('{')) return null;
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
          _showSnack('Order placed! Pay at the counter when done 🍽️',
              AppColors.success);
          context.goNamed(
            RouteNames.orderDetail,
            pathParameters: {'id': next.order.id},
          );
        } else {
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
                      _DineInSection(
                        selectedTable: _selectedTable,
                        onTableSelected: (t) =>
                            setState(() => _selectedTable = t),
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

// ─────────────────────────────────────────────────────────────────────────────
// _DineInSection — shows available tables as a tappable grid + QR scan option
// ─────────────────────────────────────────────────────────────────────────────

class _DineInSection extends ConsumerWidget {
  const _DineInSection({
    required this.selectedTable,
    required this.onTableSelected,
    required this.onScanQr,
  });

  final RestaurantTableModel? selectedTable;
  final void Function(RestaurantTableModel) onTableSelected;
  final VoidCallback onScanQr;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tablesAsync = ref.watch(availableTablesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Row(children: [
          Text('Select Your Table',
              style: GoogleFonts.syne(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                  letterSpacing: 0.5)),
          const Spacer(),
          // QR scan button
          GestureDetector(
            onTap: onScanQr,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primaryTint,
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
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

        const SizedBox(height: 12),

        // Selected table badge (if any)
        if (selectedTable != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.15),
                  AppColors.primaryLight.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
            ),
            child: Row(children: [
              const Icon(Icons.table_restaurant_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  selectedTable!.tableNumber,
                  style: GoogleFonts.syne(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary),
                ),
                if (selectedTable!.capacity > 0)
                  Text(
                    '${selectedTable!.capacity} seats · ${selectedTable!.floor}',
                    style: GoogleFonts.dmSans(
                        fontSize: 11, color: AppColors.textMuted),
                  ),
              ]),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  // Trigger rebuild by passing null — parent handles this
                  // We can't set null directly here; user must pick another table
                },
                child: const Icon(Icons.check_circle_rounded,
                    color: AppColors.primary, size: 20),
              ),
            ]),
          ),
          const SizedBox(height: 12),
        ],

        // Table grid / loading / error
        tablesAsync.when(
          loading: () => Container(
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2),
              ),
            ),
          ),
          error: (_, __) => Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(children: [
              const Icon(Icons.wifi_off_rounded,
                  color: AppColors.textMuted, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Could not load tables. Use Scan QR instead.',
                    style: GoogleFonts.dmSans(
                        color: AppColors.textMuted, fontSize: 12)),
              ),
              TextButton(
                onPressed: () => ref.refresh(availableTablesProvider),
                child: Text('Retry',
                    style: GoogleFonts.dmSans(color: AppColors.primary)),
              ),
            ]),
          ),
          data: (tables) {
            final free = tables
                .where((t) => t.status == 'free' || t.status == 'reserved')
                .toList();
            final all = tables;

            if (all.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text('No tables available right now.',
                    style: GoogleFonts.dmSans(color: AppColors.textMuted)),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (free.isNotEmpty) ...[
                  Text(
                    'Available Tables (${free.length})',
                    style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                ],

                // Horizontal scrollable chip row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: all.map((t) {
                      final isSelected =
                          selectedTable?.tableNumber == t.tableNumber;
                      final statusColor = switch (t.status) {
                        'free' => AppColors.success,
                        'occupied' => AppColors.error,
                        'reserved' => AppColors.warning,
                        _ => AppColors.textMuted,
                      };
                      final canSelect =
                          t.status == 'free' || t.status == 'reserved';

                      return GestureDetector(
                        onTap: canSelect ? () => onTableSelected(t) : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primaryTint
                                : canSelect
                                    ? AppColors.surface
                                    : AppColors.surfaceAlt
                                        .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : statusColor.withValues(alpha: 0.4),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                      color: statusColor,
                                      shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  t.tableNumber,
                                  style: GoogleFonts.syne(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: isSelected
                                        ? AppColors.primary
                                        : canSelect
                                            ? AppColors.textPrimary
                                            : AppColors.textDisabled,
                                  ),
                                ),
                              ]),
                              const SizedBox(height: 2),
                              Text(
                                '${t.capacity} seats',
                                style: GoogleFonts.dmSans(
                                    fontSize: 9,
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.textMuted),
                              ),
                              if (!canSelect)
                                Text(
                                  t.status,
                                  style: GoogleFonts.dmSans(
                                      fontSize: 8,
                                      color: statusColor,
                                      fontWeight: FontWeight.w600),
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 12, color: AppColors.textDisabled),
                  const SizedBox(width: 5),
                  Text(
                    'Greyed tables are occupied. Scan QR for instant selection.',
                    style: GoogleFonts.dmSans(
                        fontSize: 10, color: AppColors.textDisabled),
                  ),
                ]),
              ],
            );
          },
        ),
      ],
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
              Center(
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.primary, width: 2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Stack(children: [
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
