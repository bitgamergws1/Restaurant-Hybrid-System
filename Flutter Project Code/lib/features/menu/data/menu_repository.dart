import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/providers/shared_preferences_provider.dart';
import '../domain/models/menu_item_model.dart';

final class MenuRepository {
  const MenuRepository(this._client);
  final ApiClient _client;

  Future<List<MenuItemModel>> getMenu({
    String? category,
    String? search,
    bool availableOnly = true,
  }) async {
    final data = await _client.get(ApiEndpoints.menu, queryParams: {
      'available': availableOnly.toString(),
      if (category != null && category.isNotEmpty) 'category': category,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    final items = data['items'] as List<dynamic>? ?? [];
    return items
        .map((e) => MenuItemModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<String>> getCategories() async {
    final data = await _client.get(ApiEndpoints.menuCategories);
    return (data['categories'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
  }
}

final menuRepositoryProvider = Provider<MenuRepository>((ref) {
  return MenuRepository(ref.watch(apiClientProvider));
});
