import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/menu_repository.dart';
import '../../domain/models/menu_item_model.dart';

// ── Filter state ─────────────────────────────────────────────────────────────

final selectedCategoryProvider = StateProvider<String?>((ref) => null);
final searchQueryProvider = StateProvider<String>((ref) => '');

// ── Menu items ───────────────────────────────────────────────────────────────

final menuItemsProvider =
    FutureProvider.autoDispose<List<MenuItemModel>>((ref) async {
  final repo = ref.watch(menuRepositoryProvider);
  final category = ref.watch(selectedCategoryProvider);
  final search = ref.watch(searchQueryProvider);
  return repo.getMenu(category: category, search: search);
});

// ── Categories ───────────────────────────────────────────────────────────────

final categoriesProvider =
    FutureProvider.autoDispose<List<String>>((ref) async {
  return ref.watch(menuRepositoryProvider).getCategories();
});
