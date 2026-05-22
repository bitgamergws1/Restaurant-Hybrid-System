import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../providers/admin_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TablesManagementScreen — view, create, edit, delete tables + QR regeneration.
// ─────────────────────────────────────────────────────────────────────────────

class TablesManagementScreen extends ConsumerWidget {
  const TablesManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tablesAsync = ref.watch(adminTablesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onPressed: () => _showTableDialog(context, ref, null),
        child: const Icon(Icons.add_rounded),
      ),
      body: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
            child: Row(
              children: [
                Text(
                  'Tables',
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
                      ref.read(adminTablesProvider.notifier).refresh(),
                ),
              ],
            ),
          ),

          // ── Legend ────────────────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _LegendDot(color: AppColors.success, label: 'Free'),
                SizedBox(width: 16),
                _LegendDot(color: AppColors.error, label: 'Occupied'),
                SizedBox(width: 16),
                _LegendDot(color: AppColors.warning, label: 'Reserved'),
                SizedBox(width: 16),
                _LegendDot(color: AppColors.textMuted, label: 'Inactive'),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Grid ──────────────────────────────────────────────────────
          Expanded(
            child: tablesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2),
              ),
              error: (e, _) => Center(
                child: Text('Error: $e',
                    style: GoogleFonts.dmSans(color: AppColors.error)),
              ),
              data: (tables) {
                if (tables.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.table_restaurant_outlined,
                            size: 48, color: AppColors.textMuted),
                        const SizedBox(height: 12),
                        Text('No tables yet',
                            style:
                                GoogleFonts.dmSans(color: AppColors.textMuted)),
                        const SizedBox(height: 8),
                        Text('Tap + to add your first table',
                            style: GoogleFonts.dmSans(
                                color: AppColors.textMuted, fontSize: 12)),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.2,
                  ),
                  itemCount: tables.length,
                  itemBuilder: (_, i) => _TableCard(
                    table: tables[i],
                    onEdit: () => _showTableDialog(context, ref, tables[i]),
                    onDelete: () => _confirmDelete(context, ref, tables[i]),
                    onRegenerateQr: () => ref
                        .read(adminTablesProvider.notifier)
                        .regenerateQr(tables[i].id),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showTableDialog(
      BuildContext context, WidgetRef ref, RestaurantTableModel? existing) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _TableFormSheet(
        existing: existing,
        onSave: (payload) async {
          if (existing == null) {
            await ref.read(adminTablesProvider.notifier).createTable(payload);
          } else {
            await ref
                .read(adminTablesProvider.notifier)
                .updateTable(existing.id, payload);
          }
        },
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, RestaurantTableModel table) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Delete Table',
            style: GoogleFonts.syne(color: AppColors.textPrimary)),
        content: Text(
          'Delete table "${table.tableNumber}"?',
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
              ref.read(adminTablesProvider.notifier).deleteTable(table.id);
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

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(label,
              style:
                  GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted)),
        ],
      );
}

class _TableCard extends StatelessWidget {
  const _TableCard({
    required this.table,
    required this.onEdit,
    required this.onDelete,
    required this.onRegenerateQr,
  });

  final RestaurantTableModel table;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onRegenerateQr;

  Color get _statusColor => switch (table.status) {
        'free' => AppColors.success,
        'occupied' => AppColors.error,
        'reserved' => AppColors.warning,
        _ => AppColors.textMuted,
      };

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _statusColor.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                      color: _statusColor, shape: BoxShape.circle),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onEdit,
                  child: const Icon(Icons.edit_outlined,
                      size: 14, color: AppColors.textMuted),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onDelete,
                  child: const Icon(Icons.delete_outline_rounded,
                      size: 14, color: AppColors.error),
                ),
              ],
            ),
            const Spacer(),
            Text(
              table.tableNumber,
              style: GoogleFonts.syne(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              '${table.capacity} seats · ${table.floor}',
              style:
                  GoogleFonts.dmSans(fontSize: 10, color: AppColors.textMuted),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: onRegenerateQr,
              child: Row(
                children: [
                  const Icon(Icons.qr_code_rounded,
                      size: 11, color: AppColors.textMuted),
                  const SizedBox(width: 3),
                  Text(
                    'Regen QR',
                    style: GoogleFonts.dmSans(
                        fontSize: 10, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _TableFormSheet extends StatefulWidget {
  const _TableFormSheet({this.existing, required this.onSave});

  final RestaurantTableModel? existing;
  final Future<void> Function(Map<String, dynamic>) onSave;

  @override
  State<_TableFormSheet> createState() => _TableFormSheetState();
}

class _TableFormSheetState extends State<_TableFormSheet> {
  final _numberCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController();
  final _floorCtrl = TextEditingController();
  String _status = 'free';
  bool _saving = false;

  static const _statuses = ['free', 'occupied', 'reserved', 'inactive'];

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final t = widget.existing!;
      _numberCtrl.text = t.tableNumber;
      _capacityCtrl.text = t.capacity.toString();
      _floorCtrl.text = t.floor;
      _status = t.status;
    } else {
      _capacityCtrl.text = '4';
      _floorCtrl.text = 'Ground Floor';
    }
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    _capacityCtrl.dispose();
    _floorCtrl.dispose();
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
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isEdit ? 'Edit Table' : 'New Table',
            style: GoogleFonts.syne(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _Field(label: 'Table Number (e.g. T-01)', controller: _numberCtrl),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: _Field(
                      label: 'Capacity',
                      controller: _capacityCtrl,
                      keyboardType: TextInputType.number)),
              const SizedBox(width: 10),
              Expanded(child: _Field(label: 'Floor', controller: _floorCtrl)),
            ],
          ),
          const SizedBox(height: 12),
          Text('Status',
              style:
                  GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 6),
          Row(
            children: _statuses
                .map(
                  (s) => GestureDetector(
                    onTap: () => setState(() => _status = s),
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _status == s
                            ? AppColors.primaryTint
                            : AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _status == s
                              ? AppColors.primary.withValues(alpha: 0.4)
                              : AppColors.border,
                        ),
                      ),
                      child: Text(
                        s,
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: _status == s
                              ? AppColors.primary
                              : AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
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
                  : Text(isEdit ? 'Save Changes' : 'Create Table',
                      style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_numberCtrl.text.isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.onSave({
        'table_number': _numberCtrl.text.trim(),
        'capacity': int.tryParse(_capacityCtrl.text) ?? 4,
        'floor': _floorCtrl.text.trim(),
        'status': _status,
      });
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: GoogleFonts.dmSans(color: AppColors.textPrimary, fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          labelStyle:
              GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 12),
          filled: true,
          fillColor: AppColors.surfaceAlt,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      );
}
