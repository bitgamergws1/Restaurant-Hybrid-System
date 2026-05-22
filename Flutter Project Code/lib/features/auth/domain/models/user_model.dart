/// ─────────────────────────────────────────────────────────────────────────────
/// UserModel
/// Immutable value object matching the backend `users` table shape.
/// Uses Dart 3 `final class` — cannot be extended or mixed in.
/// ─────────────────────────────────────────────────────────────────────────────
final class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone = '',
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final String phone;

  bool get isAdmin => role == 'admin';
  bool get isStaff => role == 'staff' || role == 'admin';
  bool get isCustomer => role == 'customer';

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        role: json['role'] as String,
        phone: json['phone'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        'phone': phone,
      };

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    String? phone,
  }) =>
      UserModel(
        id: id ?? this.id,
        name: name ?? this.name,
        email: email ?? this.email,
        role: role ?? this.role,
        phone: phone ?? this.phone,
      );

  @override
  String toString() => 'UserModel(id: $id, name: $name, role: $role)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
