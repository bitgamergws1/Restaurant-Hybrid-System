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

// Not autoDispose — categories must survive category-tap rebuilds.
// autoDispose was causing the provider to reset whenever selectedCategory
// changed (brief un-watch during rebuild), making chips flicker/disappear.
final categoriesProvider = FutureProvider<List<String>>((ref) async {
  return ref.watch(menuRepositoryProvider).getCategories();
});
