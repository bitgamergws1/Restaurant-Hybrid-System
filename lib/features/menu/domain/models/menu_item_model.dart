/// MenuItemModel — mirrors the `menu_items` Supabase table.
final class MenuItemModel {
  const MenuItemModel({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    this.description,
    this.subcategory,
    this.imageUrl,
    this.isAvailable = true,
    this.tags = const [],
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final double price;
  final String category;
  final String? description;
  final String? subcategory;
  final String? imageUrl;
  final bool isAvailable;
  final List<String> tags;
  final int sortOrder;

  factory MenuItemModel.fromJson(Map<String, dynamic> j) => MenuItemModel(
        id: j['id'] as String,
        name: j['name'] as String,
        price: double.parse(j['price'].toString()),
        category: j['category'] as String,
        description: j['description'] as String?,
        subcategory: j['subcategory'] as String?,
        imageUrl: j['image_url'] as String?,
        isAvailable: j['is_available'] as bool? ?? true,
        tags:
            (j['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
                [],
        sortOrder: j['sort_order'] as int? ?? 0,
      );

  bool get isVeg => tags.contains('veg');
  bool get isSpicy => tags.any((t) => t.contains('spicy'));

  @override
  bool operator ==(Object other) => other is MenuItemModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
