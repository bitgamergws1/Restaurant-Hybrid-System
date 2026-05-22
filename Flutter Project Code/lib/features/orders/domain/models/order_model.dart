/// ─────────────────────────────────────────────────────────────────────────────
/// OrderItemModel — mirrors the `order_items` table row.
/// ─────────────────────────────────────────────────────────────────────────────
final class OrderItemModel {
  const OrderItemModel({
    required this.id,
    required this.orderId,
    required this.menuItemId,
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
    required this.itemTotal,
  });

  final String id;
  final String orderId;
  final String menuItemId;
  final String itemName;
  final int quantity;
  final double unitPrice;
  final double itemTotal;

  factory OrderItemModel.fromJson(Map<String, dynamic> j) => OrderItemModel(
        id: j['id'] as String,
        orderId: j['order_id'] as String,
        menuItemId: j['menu_item_id'] as String,
        itemName: j['item_name'] as String,
        quantity: j['quantity'] as int,
        unitPrice: double.parse(j['unit_price'].toString()),
        itemTotal: double.parse(j['item_total'].toString()),
      );
}

/// ─────────────────────────────────────────────────────────────────────────────
/// OrderModel — mirrors the `orders` table row.
/// Updated: added estimatedDeliveryTime, estimatedTableTime, riderId.
/// ─────────────────────────────────────────────────────────────────────────────
final class OrderModel {
  const OrderModel({
    required this.id,
    required this.userId,
    required this.orderType,
    required this.status,
    required this.subtotal,
    required this.gstAmount,
    required this.totalAmount,
    required this.paymentStatus,
    required this.createdAt,
    this.tableId,
    this.deliveryAddress,
    this.deliveryCoordinates,
    this.paymentId,
    this.specialInstructions,
    this.invoiceSent = false,
    this.estimatedDeliveryTime,
    this.estimatedTableTime,
    this.riderId,
  });

  final String id;
  final String userId;
  final String orderType;
  final String status;
  final double subtotal;
  final double gstAmount;
  final double totalAmount;
  final String paymentStatus;
  final DateTime createdAt;
  final String? tableId;
  final Map<String, dynamic>? deliveryAddress;
  final Map<String, dynamic>? deliveryCoordinates;
  final String? paymentId;
  final String? specialInstructions;
  final bool invoiceSent;
  // ── Admin-side fields ────────────────────────────────────────────────────
  final DateTime? estimatedDeliveryTime;
  final DateTime? estimatedTableTime;
  final String? riderId;

  bool get isDineIn => orderType == 'dine_in';
  bool get isDelivery => orderType == 'delivery';
  bool get isPaid => paymentStatus == 'paid';
  bool get isCancelled => status == 'cancelled';
  bool get isDelivered => status == 'delivered';
  bool get isActive => !isCancelled && !isDelivered;
  bool get hasRider => riderId != null;

  String get shortId => id.substring(0, 8).toUpperCase();

  /// ETA applicable to the order type.
  DateTime? get eta => isDineIn ? estimatedTableTime : estimatedDeliveryTime;

  /// Numeric step index for the tracking timeline (0-based).
  int get statusStep {
    const steps = [
      'pending',
      'confirmed',
      'preparing',
      'ready',
      'out_for_delivery',
      'delivered',
    ];
    return steps.indexOf(status).clamp(0, steps.length - 1);
  }

  factory OrderModel.fromJson(Map<String, dynamic> j) => OrderModel(
        id: j['id'] as String,
        userId: j['user_id'] as String? ?? '',
        orderType: j['order_type'] as String,
        status: j['status'] as String,
        subtotal: double.parse(j['subtotal'].toString()),
        gstAmount: double.parse(j['gst_amount'].toString()),
        totalAmount: double.parse(j['total_amount'].toString()),
        paymentStatus: j['payment_status'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
        tableId: j['table_id'] as String?,
        deliveryAddress: j['delivery_address'] as Map<String, dynamic>?,
        deliveryCoordinates: j['delivery_coordinates'] as Map<String, dynamic>?,
        paymentId: j['payment_id'] as String?,
        specialInstructions: j['special_instructions'] as String?,
        invoiceSent: j['invoice_sent'] as bool? ?? false,
        estimatedDeliveryTime: j['estimated_delivery_time'] != null
            ? DateTime.tryParse(j['estimated_delivery_time'] as String)
            : null,
        estimatedTableTime: j['estimated_table_time'] != null
            ? DateTime.tryParse(j['estimated_table_time'] as String)
            : null,
        riderId: j['rider_id'] as String?,
      );
}
