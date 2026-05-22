/// ─────────────────────────────────────────────────────────────────────────────
/// AdminRiderInfo
/// Embedded rider data returned by the Supabase join in /admin/orders.
/// ─────────────────────────────────────────────────────────────────────────────
final class AdminRiderInfo {
  const AdminRiderInfo({
    required this.id,
    required this.name,
    required this.phone,
  });

  final String id;
  final String name;
  final String phone;

  factory AdminRiderInfo.fromJson(Map<String, dynamic> j) => AdminRiderInfo(
        id: j['id'] as String,
        name: j['name'] as String,
        phone: j['phone'] as String,
      );
}

/// ─────────────────────────────────────────────────────────────────────────────
/// AdminOrderModel
/// Extends the basic order shape with admin-only fields:
///   • estimatedDeliveryTime / estimatedTableTime (set via /orders/:id/eta)
///   • riderId + nested [AdminRiderInfo] (set via /orders/:id/assign-rider)
///   • deliveryCoordinates
///
/// The backend's GET /admin/orders query is:
///   db.table("orders").select("*, riders(id, name, phone)")
/// so the `riders` key is a nested object (or null).
/// ─────────────────────────────────────────────────────────────────────────────
final class AdminOrderModel {
  const AdminOrderModel({
    required this.id,
    required this.userId,
    required this.orderType,
    required this.status,
    required this.paymentStatus,
    required this.subtotal,
    required this.gstAmount,
    required this.totalAmount,
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
    this.rider,
  });

  final String id;
  final String userId;
  final String orderType;
  final String status;
  final String paymentStatus;
  final double subtotal;
  final double gstAmount;
  final double totalAmount;
  final DateTime createdAt;
  final String? tableId;
  final Map<String, dynamic>? deliveryAddress;
  final Map<String, dynamic>? deliveryCoordinates;
  final String? paymentId;
  final String? specialInstructions;
  final bool invoiceSent;
  final DateTime? estimatedDeliveryTime;
  final DateTime? estimatedTableTime;
  final String? riderId;
  final AdminRiderInfo? rider; // from riders(id, name, phone) join

  bool get isDineIn => orderType == 'dine_in';
  bool get isDelivery => orderType == 'delivery';
  bool get isPaid => paymentStatus == 'paid';
  bool get isPending => status == 'pending';
  bool get isCancelled => status == 'cancelled';
  bool get isDelivered => status == 'delivered';
  bool get isActive => !isCancelled && !isDelivered;
  bool get hasRider => rider != null;
  bool get needsRider => isDelivery && !hasRider && isActive;

  String get shortId => id.substring(0, 8).toUpperCase();

  DateTime? get eta => isDineIn ? estimatedTableTime : estimatedDeliveryTime;

  String get deliveryAddressLine {
    if (deliveryAddress == null) return '';
    final parts = <String>[
      deliveryAddress!['address_line'] as String? ?? '',
      deliveryAddress!['area'] as String? ?? '',
      deliveryAddress!['district'] as String? ?? '',
      deliveryAddress!['pincode'] as String? ?? '',
    ].where((s) => s.isNotEmpty).toList();
    return parts.join(', ');
  }

  factory AdminOrderModel.fromJson(Map<String, dynamic> j) {
    final riderRaw = j['riders'];
    AdminRiderInfo? riderInfo;
    if (riderRaw is Map<String, dynamic>) {
      riderInfo = AdminRiderInfo.fromJson(riderRaw);
    }

    return AdminOrderModel(
      id: j['id'] as String,
      userId: j['user_id'] as String? ?? '',
      orderType: j['order_type'] as String,
      status: j['status'] as String,
      paymentStatus: j['payment_status'] as String,
      subtotal: double.parse(j['subtotal'].toString()),
      gstAmount: double.parse(j['gst_amount'].toString()),
      totalAmount: double.parse(j['total_amount'].toString()),
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
      rider: riderInfo,
    );
  }

  AdminOrderModel copyWith({
    String? status,
    DateTime? estimatedDeliveryTime,
    DateTime? estimatedTableTime,
    String? riderId,
    AdminRiderInfo? rider,
  }) =>
      AdminOrderModel(
        id: id,
        userId: userId,
        orderType: orderType,
        status: status ?? this.status,
        paymentStatus: paymentStatus,
        subtotal: subtotal,
        gstAmount: gstAmount,
        totalAmount: totalAmount,
        createdAt: createdAt,
        tableId: tableId,
        deliveryAddress: deliveryAddress,
        deliveryCoordinates: deliveryCoordinates,
        paymentId: paymentId,
        specialInstructions: specialInstructions,
        invoiceSent: invoiceSent,
        estimatedDeliveryTime:
            estimatedDeliveryTime ?? this.estimatedDeliveryTime,
        estimatedTableTime: estimatedTableTime ?? this.estimatedTableTime,
        riderId: riderId ?? this.riderId,
        rider: rider ?? this.rider,
      );

  @override
  bool operator ==(Object other) => other is AdminOrderModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
