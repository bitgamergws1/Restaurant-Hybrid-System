import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../providers/admin_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TablesManagementScreen — view, create, edit, delete tables + QR display.
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
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: tables.length,
                  itemBuilder: (_, i) => _TableCard(
                    table: tables[i],
                    onTap: () => _showTableDetail(context, ref, tables[i]),
                    onEdit: () => _showTableDialog(context, ref, tables[i]),
                    onDelete: () => _confirmDelete(context, ref, tables[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Detail sheet (QR + actions) ──────────────────────────────────────────

  void _showTableDetail(
      BuildContext context, WidgetRef ref, RestaurantTableModel table) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _TableDetailSheet(
        table: table,
        onEdit: () {
          Navigator.pop(context);
          _showTableDialog(context, ref, table);
        },
        onDelete: () {
          Navigator.pop(context);
          _confirmDelete(context, ref, table);
        },
        onRegenerateQr: () async {
          await ref.read(adminTablesProvider.notifier).regenerateQr(table.id);
          if (context.mounted) Navigator.pop(context);
          // Re-open detail with updated table
          final updatedTables = ref.read(adminTablesProvider).valueOrNull ?? [];
          final updated = updatedTables.firstWhere(
            (t) => t.id == table.id,
            orElse: () => table,
          );
          if (context.mounted) _showTableDetail(context, ref, updated);
        },
      ),
    );
  }

  // ── Create / Edit sheet ──────────────────────────────────────────────────

  void _showTableDialog(
      BuildContext context, WidgetRef ref, RestaurantTableModel? existing) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Table',
            style: GoogleFonts.syne(color: AppColors.textPrimary)),
        content: Text(
          'Delete table "${table.tableNumber}"? This cannot be undone.',
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

// ── Table Detail Sheet (QR Code + actions) ───────────────────────────────────

class _TableDetailSheet extends StatelessWidget {
  const _TableDetailSheet({
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

  String get _statusLabel => switch (table.status) {
        'free' => 'Free',
        'occupied' => 'Occupied',
        'reserved' => 'Reserved',
        _ => 'Inactive',
      };

  // QR encodes a JSON payload the checkout scanner can parse
  String get _qrData => jsonEncode({
        'table_number': table.tableNumber,
        'token': table.qrToken,
      });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, scrollCtrl) => ListView(
        controller: scrollCtrl,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),

          // Header row
          Row(
            children: [
              // Status badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: _statusColor.withValues(alpha: 0.4)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                        color: _statusColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _statusLabel,
                    style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _statusColor),
                  ),
                ]),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: AppColors.textMuted, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Table number + meta
          Text(
            table.tableNumber,
            style: GoogleFonts.syne(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${table.capacity} seats  ·  ${table.floor}',
            style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textMuted),
          ),

          const SizedBox(height: 28),

          // ── QR Code ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Text(
                  'Table QR Code',
                  style: GoogleFonts.syne(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 20),

                // QR with logo overlay
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: QrImageView(
                    data: _qrData,
                    version: QrVersions.auto,
                    size: 200,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Color(0xFF0F0F0F),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xFF0F0F0F),
                    ),
                    embeddedImage:
                        const AssetImage('assets/images/logo_qr.png'),
                    embeddedImageStyle: const QrEmbeddedImageStyle(
                      size: Size(36, 36),
                    ),
                    // If logo asset doesn't exist, QR still works without it
                    errorStateBuilder: (ctx, err) => QrImageView(
                      data: _qrData,
                      version: QrVersions.auto,
                      size: 200,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                Text(
                  'Scan to place order at this table',
                  style: GoogleFonts.dmSans(
                      fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 4),
                // Show token for reference
                SelectableText(
                  table.qrToken.length > 16
                      ? '${table.qrToken.substring(0, 8)}…'
                      : table.qrToken,
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    color: AppColors.textDisabled,
                  ).copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Regen QR ───────────────────────────────────────────────────
          OutlinedButton.icon(
            onPressed: onRegenerateQr,
            icon: const Icon(Icons.refresh_rounded,
                size: 16, color: AppColors.warning),
            label: Text(
              'Regenerate QR Code',
              style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w600, color: AppColors.warning),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 13),
              side: BorderSide(color: AppColors.warning.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              backgroundColor: AppColors.warning.withValues(alpha: 0.06),
            ),
          ),

          const SizedBox(height: 12),

          // ── Copy QR data ───────────────────────────────────────────────
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _qrData));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('QR data copied to clipboard'),
                behavior: SnackBarBehavior.floating,
              ));
            },
            icon: const Icon(Icons.copy_rounded,
                size: 16, color: AppColors.textMuted),
            label: Text(
              'Copy QR Data',
              style: GoogleFonts.dmSans(color: AppColors.textMuted),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 13),
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),

          const SizedBox(height: 24),
          const Divider(color: AppColors.border),
          const SizedBox(height: 12),

          // ── Edit / Delete row ──────────────────────────────────────────
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined,
                    size: 15, color: AppColors.primary),
                label: Text('Edit Table',
                    style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w600, color: AppColors.primary)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  backgroundColor: AppColors.primaryTint,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 15, color: AppColors.error),
                label: Text('Delete',
                    style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w600, color: AppColors.error)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  side:
                      BorderSide(color: AppColors.error.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  backgroundColor: AppColors.errorTint,
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ── Table Card (3D restaurant table look) ────────────────────────────────────

class _TableCard extends StatelessWidget {
  const _TableCard({
    required this.table,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final RestaurantTableModel table;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  Color get _statusColor => switch (table.status) {
        'free' => AppColors.success,
        'occupied' => AppColors.error,
        'reserved' => AppColors.warning,
        _ => AppColors.textMuted,
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.surface,
              AppColors.surfaceAlt,
            ],
          ),
          border: Border.all(
            color: _statusColor.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _statusColor.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // ── Background table illustration ────────────────────────
            Positioned(
              bottom: -4,
              right: -4,
              child: Opacity(
                opacity: 0.06,
                child: Icon(
                  Icons.table_restaurant_rounded,
                  size: 80,
                  color: _statusColor,
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Top row: status + action icons ───────────────────
                  Row(
                    children: [
                      // Status pulse dot
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _statusColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _statusColor.withValues(alpha: 0.5),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Edit
                      GestureDetector(
                        onTap: onEdit,
                        behavior: HitTestBehavior.opaque,
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.edit_outlined,
                              size: 15, color: AppColors.textMuted),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Delete
                      GestureDetector(
                        onTap: onDelete,
                        behavior: HitTestBehavior.opaque,
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.delete_outline_rounded,
                              size: 15, color: AppColors.error),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ── Table 3D visual ──────────────────────────────────
                  Center(child: _TableTopIllustration(color: _statusColor)),

                  const SizedBox(height: 12),

                  // ── Table number ─────────────────────────────────────
                  Text(
                    table.tableNumber,
                    style: GoogleFonts.syne(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),

                  const SizedBox(height: 2),

                  Text(
                    '${table.capacity} seats · ${table.floor}',
                    style: GoogleFonts.dmSans(
                        fontSize: 10, color: AppColors.textMuted),
                  ),

                  const SizedBox(height: 8),

                  // ── QR hint ──────────────────────────────────────────
                  Row(children: [
                    const Icon(Icons.qr_code_rounded,
                        size: 11, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Tap to view QR',
                      style: GoogleFonts.dmSans(
                          fontSize: 10,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tiny 3D table-top illustration ───────────────────────────────────────────

class _TableTopIllustration extends StatelessWidget {
  const _TableTopIllustration({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 44,
      child: CustomPaint(painter: _TablePainter(color: color)),
    );
  }
}

class _TablePainter extends CustomPainter {
  const _TablePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final tablePaint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Table top (rounded rect)
    final tableRect = RRect.fromLTRBR(
      4,
      4,
      size.width - 4,
      size.height - 16,
      const Radius.circular(6),
    );
    canvas.drawRRect(tableRect, tablePaint);
    canvas.drawRRect(tableRect, borderPaint);

    // Left leg
    final legPaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromLTRBR(10, size.height - 18, 18, size.height, Radius.zero),
      legPaint,
    );
    // Right leg
    canvas.drawRRect(
      RRect.fromLTRBR(size.width - 18, size.height - 18, size.width - 10,
          size.height, Radius.zero),
      legPaint,
    );
  }

  @override
  bool shouldRepaint(_TablePainter old) => old.color != color;
}

// ── Legend dot ───────────────────────────────────────────────────────────────

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

// ── Table Form Sheet (create / edit) ─────────────────────────────────────────

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
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _statuses
                .map(
                  (s) => GestureDetector(
                    onTap: () => setState(() => _status = s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _status == s
                            ? AppColors.primaryTint
                            : AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _status == s
                              ? AppColors.primary.withValues(alpha: 0.4)
                              : AppColors.border,
                        ),
                      ),
                      child: Text(
                        s,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
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
