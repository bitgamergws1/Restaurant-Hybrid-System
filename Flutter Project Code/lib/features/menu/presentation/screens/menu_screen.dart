import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/route_names.dart';
import '../providers/menu_provider.dart';
import '../widgets/menu_item_card.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class MenuScreen extends ConsumerStatefulWidget {
  const MenuScreen({super.key});
  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider
        .select((s) => s is AuthAuthenticated ? s.user : null));
    final menuAsync = ref.watch(menuItemsProvider);
    final catsAsync = ref.watch(categoriesProvider);
    final selCat = ref.watch(selectedCategoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── AppBar ────────────────────────────────────────────────────────
          SliverAppBar(
            backgroundColor: AppColors.background,
            floating: true,
            snap: true,
            elevation: 0,
            scrolledUnderElevation: 0,
            expandedHeight: 120,
            flexibleSpace: FlexibleSpaceBar(
              background: Padding(
                padding: const EdgeInsets.fromLTRB(20, 56, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Good ${_greeting()},',
                                style: GoogleFonts.dmSans(
                                    fontSize: 13, color: AppColors.textMuted),
                              ),
                              Text(
                                user?.name.split(' ').first ?? 'Guest',
                                style: GoogleFonts.syne(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary),
                              ),
                            ]),
                      ),
                      // AI recommend shortcut
                      GestureDetector(
                        onTap: () => context.goNamed(RouteNames.aiChat),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryTint,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color:
                                    AppColors.primary.withValues(alpha: 0.3)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.auto_awesome_rounded,
                                color: AppColors.primary, size: 14),
                            const SizedBox(width: 6),
                            Text('AI Chef',
                                style: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary)),
                          ]),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: AppColors.border),
            ),
          ),

          // ── Search bar ────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: TextField(
                controller: _searchCtrl,
                style: GoogleFonts.dmSans(
                    fontSize: 14, color: AppColors.textPrimary),
                cursorColor: AppColors.primary,
                onChanged: (v) =>
                    ref.read(searchQueryProvider.notifier).state = v,
                decoration: InputDecoration(
                  hintText: 'Search dishes, categories...',
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: AppColors.textMuted, size: 18),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: AppColors.textMuted, size: 16),
                          onPressed: () {
                            _searchCtrl.clear();
                            ref.read(searchQueryProvider.notifier).state = '';
                          },
                        )
                      : null,
                ),
              ).animate().fadeIn(delay: 100.ms),
            ),
          ),

          // ── Category chips ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: catsAsync.when(
              data: (cats) => _CategoryBar(
                categories: cats,
                selected: selCat,
                onSelect: (c) =>
                    ref.read(selectedCategoryProvider.notifier).state = c,
              ).animate().fadeIn(delay: 150.ms),
              loading: () => const SizedBox(height: 52),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),

          // ── Menu grid / list ──────────────────────────────────────────────
          menuAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.search_off_rounded,
                          color: AppColors.textDisabled, size: 48),
                      const SizedBox(height: 12),
                      Text('Nothing found',
                          style: GoogleFonts.syne(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted)),
                      const SizedBox(height: 4),
                      Text('Try a different search or category',
                          style: GoogleFonts.dmSans(
                              fontSize: 13, color: AppColors.textDisabled)),
                    ]),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                sliver: SliverLayoutBuilder(
                  builder: (ctx, constraints) {
                    final w = constraints.crossAxisExtent;
                    final cols = w >= 1200
                        ? 4
                        : w >= 800
                            ? 3
                            : w >= 500
                                ? 2
                                : 1;
                    return SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) =>
                            MenuItemCard(item: items[i], compact: cols > 2)
                                .animate()
                                .fadeIn(delay: (i * 40).ms)
                                .slideY(begin: 0.1, delay: (i * 40).ms),
                        childCount: items.length,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: cols == 1
                            ? 2.8
                            : cols == 2
                                ? 0.72
                                : 0.68,
                      ),
                    );
                  },
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(AppColors.primary),
                  strokeWidth: 2,
                ),
              ),
            ),
            error: (e, _) => SliverFillRemaining(
              child: _ErrorView(
                message: e.toString().replaceAll('ApiException', '').trim(),
                onRetry: () => ref.invalidate(menuItemsProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'morning';
    if (h < 17) return 'afternoon';
    return 'evening';
  }
}

// ── Category filter bar ──────────────────────────────────────────────────────

class _CategoryBar extends StatelessWidget {
  const _CategoryBar(
      {required this.categories,
      required this.selected,
      required this.onSelect});
  final List<String> categories;
  final String? selected;
  final void Function(String?) onSelect;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 52,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          itemCount: categories.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (ctx, i) {
            final label = i == 0 ? 'All' : categories[i - 1];
            final active =
                i == 0 ? selected == null : selected == categories[i - 1];
            return GestureDetector(
              onTap: () => onSelect(i == 0 ? null : categories[i - 1]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: active ? AppColors.primary : AppColors.border,
                  ),
                ),
                child: Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? Colors.white : AppColors.textTertiary,
                  ),
                ),
              ),
            );
          },
        ),
      );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.wifi_off_rounded,
              color: AppColors.textDisabled, size: 48),
          const SizedBox(height: 12),
          Text('Could not load menu',
              style: GoogleFonts.syne(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted)),
          const SizedBox(height: 4),
          Text(message,
              style: GoogleFonts.dmSans(
                  fontSize: 12, color: AppColors.textDisabled),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry'),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        ]),
      );
}
