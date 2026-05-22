import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../providers/admin_providers.dart';
import '../../../../features/menu/domain/models/menu_item_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MenuManagementScreen — view, toggle availability, create, edit, delete items.
// ─────────────────────────────────────────────────────────────────────────────

class MenuManagementScreen extends ConsumerStatefulWidget {
  const MenuManagementScreen({super.key});

  @override
  ConsumerState<MenuManagementScreen> createState() =>
      _MenuManagementScreenState();
}

class _MenuManagementScreenState extends ConsumerState<MenuManagementScreen> {
  String _search = '';
  String _categoryFilter = '';

  @override
  Widget build(BuildContext context) {
    final menuAsync = ref.watch(adminMenuProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onPressed: () => _showItemDialog(context, ref, null),
        child: const Icon(Icons.add_rounded),
      ),
      body: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 12),
            child: Row(
              children: [
                Text(
                  'Menu',
                  style: GoogleFonts.syne(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded,
                      color: AppColors.textMuted, size: 20),
                  onPressed: () =>
                      ref.read(adminMenuProvider.notifier).refresh(),
                ),
              ],
            ),
          ),

          // ── Search bar ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
              style: GoogleFonts.dmSans(
                  color: AppColors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search items…',
                hintStyle: GoogleFonts.dmSans(color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.textMuted, size: 18),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ── List ──────────────────────────────────────────────────────
          Expanded(
            child: menuAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2),
              ),
              error: (e, _) => Center(
                child: Text('Error: $e',
                    style: GoogleFonts.dmSans(color: AppColors.error)),
              ),
              data: (items) {
                // Build category list
                final categories = {
                  '',
                  ...items.map((i) => i.category),
                }.toList();

                var filtered = items.where((item) {
                  final matchSearch = _search.isEmpty ||
                      item.name.toLowerCase().contains(_search) ||
                      (item.category.toLowerCase().contains(_search));
                  final matchCat = _categoryFilter.isEmpty ||
                      item.category == _categoryFilter;
                  return matchSearch && matchCat;
                }).toList();

                return Column(
                  children: [
                    // Category filter
                    SizedBox(
                      height: 38,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        children: categories.map((cat) {
                          final isActive = _categoryFilter == cat;
                          return GestureDetector(
                            onTap: () => setState(() => _categoryFilter = cat),
                            child: Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? AppColors.primaryTint
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isActive
                                      ? AppColors.primary.withValues(alpha: 0.5)
                                      : AppColors.border,
                                ),
                              ),
                              child: Text(
                                cat.isEmpty ? 'All' : cat,
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  fontWeight: isActive
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isActive
                                      ? AppColors.primary
                                      : AppColors.textTertiary,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text('No items',
                                  style: GoogleFonts.dmSans(
                                      color: AppColors.textMuted)),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                              itemCount: filtered.length,
                              itemBuilder: (_, i) => _MenuItemCard(
                                item: filtered[i],
                                onToggle: () => ref
                                    .read(adminMenuProvider.notifier)
                                    .toggleAvailability(filtered[i]),
                                onEdit: () =>
                                    _showItemDialog(context, ref, filtered[i]),
                                onDelete: () =>
                                    _confirmDelete(context, ref, filtered[i]),
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showItemDialog(
      BuildContext context, WidgetRef ref, MenuItemModel? existing) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ItemFormSheet(
        existing: existing,
        onSave: (payload) async {
          if (existing == null) {
            await ref.read(adminMenuProvider.notifier).createItem(payload);
          } else {
            await ref
                .read(adminMenuProvider.notifier)
                .updateItem(existing.id, payload);
          }
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, MenuItemModel item) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Delete Item',
            style: GoogleFonts.syne(color: AppColors.textPrimary)),
        content: Text(
          'Delete "${item.name}"? This cannot be undone.',
          style: GoogleFonts.dmSans(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: GoogleFonts.dmSans(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(adminMenuProvider.notifier).deleteItem(item.id);
            },
            child: Text('Delete',
                style: GoogleFonts.dmSans(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

// ── Widgets ──────────────────────────────────────────────────────────────────

class _MenuItemCard extends StatelessWidget {
  const _MenuItemCard({
    required this.item,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final MenuItemModel item;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: item.isAvailable ? AppColors.border : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            // Availability dot
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: item.isAvailable ? AppColors.success : AppColors.error,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: item.isAvailable
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                    ),
                  ),
                  Text(
                    '${item.category}  ·  ₹${item.price.toStringAsFixed(0)}',
                    style: GoogleFonts.dmSans(
                        fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            // Toggle
            GestureDetector(
              onTap: onToggle,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: item.isAvailable
                      ? AppColors.success.withValues(alpha: 0.12)
                      : AppColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  item.isAvailable ? 'On' : 'Off',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color:
                        item.isAvailable ? AppColors.success : AppColors.error,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Edit
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  size: 16, color: AppColors.textMuted),
              onPressed: onEdit,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 4),
            // Delete
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  size: 16, color: AppColors.error),
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      );
}

class _ItemFormSheet extends StatefulWidget {
  const _ItemFormSheet({this.existing, required this.onSave});

  final MenuItemModel? existing;
  final Future<void> Function(Map<String, dynamic>) onSave;

  @override
  State<_ItemFormSheet> createState() => _ItemFormSheetState();
}

class _ItemFormSheetState extends State<_ItemFormSheet> {
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _subcategoryCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _imageCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  bool _isAvailable = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _nameCtrl.text = widget.existing!.name;
      _priceCtrl.text = widget.existing!.price.toString();
      _categoryCtrl.text = widget.existing!.category;
      _subcategoryCtrl.text = widget.existing!.subcategory ?? '';
      _descCtrl.text = widget.existing!.description ?? '';
      _imageCtrl.text = widget.existing!.imageUrl ?? '';
      _tagsCtrl.text = widget.existing!.tags.join(', ');
      _isAvailable = widget.existing!.isAvailable;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _categoryCtrl.dispose();
    _subcategoryCtrl.dispose();
    _descCtrl.dispose();
    _imageCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isEdit ? 'Edit Item' : 'New Item',
            style: GoogleFonts.syne(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _Field(label: 'Name', controller: _nameCtrl),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: _Field(
                      label: 'Price (₹)',
                      controller: _priceCtrl,
                      keyboardType: TextInputType.number)),
              const SizedBox(width: 10),
              Expanded(
                  child: _Field(label: 'Category', controller: _categoryCtrl)),
            ],
          ),
          const SizedBox(height: 10),
          _Field(label: 'Subcategory (optional)', controller: _subcategoryCtrl),
          const SizedBox(height: 10),
          _Field(
              label: 'Description (optional)',
              controller: _descCtrl,
              maxLines: 2),
          const SizedBox(height: 10),
          // ── Image URL with live preview ──────────────────────────────────
          _ImageUrlField(controller: _imageCtrl),
          const SizedBox(height: 10),
          _Field(
            label: 'Tags (comma-separated: veg, spicy, bestseller…)',
            controller: _tagsCtrl,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Available',
                  style: GoogleFonts.dmSans(
                      color: AppColors.textSecondary, fontSize: 13)),
              const Spacer(),
              Switch(
                value: _isAvailable,
                onChanged: (v) => setState(() => _isAvailable = v),
                activeThumbColor: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(isEdit ? 'Save Changes' : 'Create Item',
                      style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.isEmpty || _priceCtrl.text.isEmpty) return;
    setState(() => _saving = true);
    try {
      final tags = _tagsCtrl.text
          .split(',')
          .map((t) => t.trim().toLowerCase())
          .where((t) => t.isNotEmpty)
          .toList();

      await widget.onSave({
        'name': _nameCtrl.text.trim(),
        'price': double.tryParse(_priceCtrl.text) ?? 0,
        'category': _categoryCtrl.text.trim(),
        'subcategory': _subcategoryCtrl.text.trim().isEmpty
            ? null
            : _subcategoryCtrl.text.trim(),
        'description':
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'image_url':
            _imageCtrl.text.trim().isEmpty ? null : _imageCtrl.text.trim(),
        'tags': tags,
        'is_available': _isAvailable,
      });
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ── Image URL field with live thumbnail preview ──────────────────────────────
class _ImageUrlField extends StatefulWidget {
  const _ImageUrlField({required this.controller});
  final TextEditingController controller;

  @override
  State<_ImageUrlField> createState() => _ImageUrlFieldState();
}

class _ImageUrlFieldState extends State<_ImageUrlField> {
  String _preview = '';

  @override
  void initState() {
    super.initState();
    _preview = widget.controller.text;
    widget.controller.addListener(_onChanged);
  }

  void _onChanged() => setState(() => _preview = widget.controller.text.trim());

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasUrl = _preview.startsWith('http');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          style: GoogleFonts.dmSans(color: AppColors.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            labelText: 'Image URL (optional)',
            labelStyle:
                GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 12),
            hintText: 'https://...',
            hintStyle:
                GoogleFonts.dmSans(color: AppColors.textDisabled, fontSize: 12),
            filled: true,
            fillColor: AppColors.surfaceAlt,
            suffixIcon: hasUrl
                ? const Icon(Icons.link_rounded,
                    color: AppColors.primary, size: 18)
                : const Icon(Icons.link_off_rounded,
                    color: AppColors.textDisabled, size: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        if (hasUrl) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              _preview,
              height: 100,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Center(
                  child: Icon(Icons.broken_image_rounded,
                      color: AppColors.textDisabled, size: 28),
                ),
              ),
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : Container(
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.primary),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: GoogleFonts.dmSans(color: AppColors.textPrimary, fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          labelStyle:
              GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 12),
          filled: true,
          fillColor: AppColors.surfaceAlt,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.primary),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      );
}
