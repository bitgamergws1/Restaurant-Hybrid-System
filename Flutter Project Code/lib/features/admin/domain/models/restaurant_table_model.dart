// ─────────────────────────────────────────────────────────────────────────────
// RestaurantTableModel — mirrors the `restaurant_tables` table.
// ─────────────────────────────────────────────────────────────────────────────
final class RestaurantTableModel {
  const RestaurantTableModel({
    required this.id,
    required this.tableNumber,
    required this.capacity,
    required this.floor,
    required this.status,
    required this.qrToken,
    required this.createdAt,
  });

  final String id;
  final String tableNumber;
  final int capacity;
  final String floor;
  final String status; // free | occupied | reserved | inactive
  final String qrToken;
  final DateTime createdAt;

  bool get isFree => status == 'free';
  bool get isOccupied => status == 'occupied';

  factory RestaurantTableModel.fromJson(Map<String, dynamic> j) =>
      RestaurantTableModel(
        id: j['id'] as String,
        tableNumber: j['table_number'] as String,
        capacity: j['capacity'] as int? ?? 4,
        floor: j['floor'] as String? ?? 'Ground Floor',
        status: j['status'] as String? ?? 'free',
        qrToken: j['qr_token'] as String? ?? '',
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  @override
  bool operator ==(Object other) =>
      other is RestaurantTableModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

// ─────────────────────────────────────────────────────────────────────────────
// RiderModel — mirrors the `riders` table.
// ─────────────────────────────────────────────────────────────────────────────
final class RiderModel {
  const RiderModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.isActive,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String phone;
  final bool isActive;
  final DateTime createdAt;

  factory RiderModel.fromJson(Map<String, dynamic> j) => RiderModel(
        id: j['id'] as String,
        name: j['name'] as String,
        phone: j['phone'] as String,
        isActive: j['is_active'] as bool? ?? true,
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  @override
  bool operator ==(Object other) => other is RiderModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
