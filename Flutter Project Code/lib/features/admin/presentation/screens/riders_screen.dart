import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../providers/admin_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RidersScreen — manage delivery riders: create, toggle active, edit, delete.
// ─────────────────────────────────────────────────────────────────────────────

class RidersScreen extends ConsumerWidget {
  const RidersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ridersAsync = ref.watch(adminRidersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onPressed: () => _showRiderDialog(context, ref, null),
        child: const Icon(Icons.add_rounded),
      ),
      body: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
            child: Row(
              children: [
                Text(
                  'Riders',
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
                      ref.read(adminRidersProvider.notifier).refresh(),
                ),
              ],
            ),
          ),

          // ── List ──────────────────────────────────────────────────────
          Expanded(
            child: ridersAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2),
              ),
              error: (e, _) => Center(
                child: Text('Error: $e',
                    style: GoogleFonts.dmSans(color: AppColors.error)),
              ),
              data: (riders) {
                if (riders.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.two_wheeler_rounded,
                            size: 48, color: AppColors.textMuted),
                        const SizedBox(height: 12),
                        Text('No riders yet',
                            style:
                                GoogleFonts.dmSans(color: AppColors.textMuted)),
                        const SizedBox(height: 8),
                        Text('Tap + to add your first rider',
                            style: GoogleFonts.dmSans(
                                color: AppColors.textMuted, fontSize: 12)),
                      ],
                    ),
                  );
                }

                // Active first
                final sorted = [...riders]
                  ..sort((a, b) => b.isActive ? 1 : (a.isActive ? -1 : 0));

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                  itemCount: sorted.length,
                  itemBuilder: (_, i) => _RiderCard(
                    rider: sorted[i],
                    onToggle: () => ref
                        .read(adminRidersProvider.notifier)
                        .toggleActive(sorted[i]),
                    onEdit: () => _showRiderDialog(context, ref, sorted[i]),
                    onDelete: () => _confirmDelete(context, ref, sorted[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showRiderDialog(
      BuildContext context, WidgetRef ref, RiderModel? existing) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _RiderFormSheet(
        existing: existing,
        onSave: (payload) async {
          if (existing == null) {
            await ref.read(adminRidersProvider.notifier).createRider(payload);
          } else {
            await ref
                .read(adminRidersProvider.notifier)
                .updateRider(existing.id, payload);
          }
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, RiderModel rider) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Remove Rider',
            style: GoogleFonts.syne(color: AppColors.textPrimary)),
        content: Text(
          'Remove "${rider.name}" from the system?',
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
              ref.read(adminRidersProvider.notifier).deleteRider(rider.id);
            },
            child: Text('Remove',
                style: GoogleFonts.dmSans(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

// ── Widgets ──────────────────────────────────────────────────────────────────

class _RiderCard extends StatelessWidget {
  const _RiderCard({
    required this.rider,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final RiderModel rider;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: rider.isActive
                ? AppColors.success.withValues(alpha: 0.25)
                : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 20,
              backgroundColor: rider.isActive
                  ? AppColors.success.withValues(alpha: 0.15)
                  : AppColors.surfaceAlt,
              child: Text(
                rider.name[0].toUpperCase(),
                style: GoogleFonts.syne(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color:
                      rider.isActive ? AppColors.success : AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rider.name,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    rider.phone,
                    style: GoogleFonts.dmSans(
                        fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            // Active toggle
            GestureDetector(
              onTap: onToggle,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: rider.isActive
                      ? AppColors.success.withValues(alpha: 0.12)
                      : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: rider.isActive
                        ? AppColors.success.withValues(alpha: 0.3)
                        : AppColors.border,
                  ),
                ),
                child: Text(
                  rider.isActive ? 'Active' : 'Inactive',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: rider.isActive
                        ? AppColors.success
                        : AppColors.textMuted,
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

class _RiderFormSheet extends StatefulWidget {
  const _RiderFormSheet({this.existing, required this.onSave});

  final RiderModel? existing;
  final Future<void> Function(Map<String, dynamic>) onSave;

  @override
  State<_RiderFormSheet> createState() => _RiderFormSheetState();
}

class _RiderFormSheetState extends State<_RiderFormSheet> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _isActive = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _nameCtrl.text = widget.existing!.name;
      _phoneCtrl.text = widget.existing!.phone;
      _isActive = widget.existing!.isActive;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
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
            isEdit ? 'Edit Rider' : 'New Rider',
            style: GoogleFonts.syne(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _Field(label: 'Full Name', controller: _nameCtrl),
          const SizedBox(height: 10),
          _Field(
            label: 'Phone Number',
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Active',
                  style: GoogleFonts.dmSans(
                      color: AppColors.textSecondary, fontSize: 13)),
              const Spacer(),
              Switch(
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
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
                  : Text(isEdit ? 'Save Changes' : 'Add Rider',
                      style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.isEmpty || _phoneCtrl.text.isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.onSave({
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'is_active': _isActive,
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
