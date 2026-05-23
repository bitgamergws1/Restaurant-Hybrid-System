import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../providers/admin_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ComplaintsAdminScreen
// Full complaints management: filter by status + priority, tap for detail,
// inline status transitions (open → in_review → resolved → closed).
// "Resolve" is intercepted to collect a resolution message + send email.
// ─────────────────────────────────────────────────────────────────────────────

class ComplaintsAdminScreen extends ConsumerStatefulWidget {
  const ComplaintsAdminScreen({super.key});

  @override
  ConsumerState<ComplaintsAdminScreen> createState() =>
      _ComplaintsAdminScreenState();
}

class _ComplaintsAdminScreenState extends ConsumerState<ComplaintsAdminScreen> {
  String _statusFilter = '';
  String _priorityFilter = '';

  static const _statusTabs = ['All', 'Open', 'In Review', 'Resolved', 'Closed'];
  static const _statusValues = ['', 'open', 'in_review', 'resolved', 'closed'];

  void _applyFilters() {
    ref.read(adminComplaintsProvider.notifier).refresh(
          status: _statusFilter.isEmpty ? null : _statusFilter,
          priority: _priorityFilter.isEmpty ? null : _priorityFilter,
        );
  }

  // ── Opens the resolution message dialog and calls resolveComplaint ──────────
  Future<void> _showResolveDialog(
      BuildContext context, ComplaintModel complaint) async {
    final controller = TextEditingController();
    String selectedStatus = 'resolved';
    bool isSending = false;
    // Capture before any await — showDialog is itself async
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: AppColors.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.check_circle_outline_rounded,
                        size: 18, color: AppColors.success),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Resolve Complaint',
                            style: GoogleFonts.syne(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '#${complaint.shortId}',
                            style: GoogleFonts.dmMono(
                                fontSize: 11, color: AppColors.textMuted),
                          ),
                        ]),
                  ),
                ]),

                const SizedBox(height: 20),

                // Complaint preview
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    complaint.rawText,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                        height: 1.5),
                  ),
                ),

                const SizedBox(height: 16),

                // Resolution message field
                Text(
                  'Resolution Message',
                  style: GoogleFonts.syne(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  maxLines: 4,
                  minLines: 3,
                  style: GoogleFonts.dmSans(
                      fontSize: 13, color: AppColors.textSecondary),
                  decoration: InputDecoration(
                    hintText:
                        'Describe how this was resolved and any actions taken…',
                    hintStyle: GoogleFonts.dmSans(
                        fontSize: 12, color: AppColors.textDisabled),
                    filled: true,
                    fillColor: AppColors.surfaceAlt,
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
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),

                const SizedBox(height: 14),

                // Status selector (resolved vs closed)
                Text(
                  'Set final status',
                  style: GoogleFonts.syne(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  _StatusToggle(
                    label: 'Resolved',
                    value: 'resolved',
                    groupValue: selectedStatus,
                    color: AppColors.success,
                    onTap: (v) => setDialogState(() => selectedStatus = v),
                  ),
                  const SizedBox(width: 8),
                  _StatusToggle(
                    label: 'Closed',
                    value: 'closed',
                    groupValue: selectedStatus,
                    color: AppColors.textMuted,
                    onTap: (v) => setDialogState(() => selectedStatus = v),
                  ),
                ]),

                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.mail_outline_rounded,
                      size: 12, color: AppColors.textDisabled),
                  const SizedBox(width: 4),
                  Text(
                    'Resolution email will be sent to the customer.',
                    style: GoogleFonts.dmSans(
                        fontSize: 11, color: AppColors.textDisabled),
                  ),
                ]),

                const SizedBox(height: 20),

                // Actions
                Row(children: [
                  Expanded(
                    child: TextButton(
                      onPressed:
                          isSending ? null : () => Navigator.pop(ctx, false),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textMuted,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text('Cancel',
                          style: GoogleFonts.dmSans(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: isSending
                          ? null
                          : () {
                              if (controller.text.trim().isEmpty) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Please enter a resolution message'),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                                return;
                              }
                              setDialogState(() => isSending = true);
                              Navigator.pop(ctx, true);
                            },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.success,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: isSending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              'Send & Resolve',
                              style: GoogleFonts.dmSans(
                                  fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(adminComplaintsProvider.notifier).resolveComplaint(
              complaint.id,
              controller.text.trim(),
              status: selectedStatus,
            );
        messenger.showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle_rounded,
                  size: 16, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                'Complaint resolved & email sent',
                style: GoogleFonts.dmSans(
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ]),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to resolve: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }

    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final complaintsAsync = ref.watch(adminComplaintsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Complaints',
                      style: GoogleFonts.syne(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    complaintsAsync.when(
                      data: (list) => Text(
                        '${list.length} complaint${list.length == 1 ? '' : 's'}',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ],
                ),
                const Spacer(),
                _PriorityFilterChip(
                  current: _priorityFilter,
                  onChanged: (v) {
                    setState(() => _priorityFilter = v);
                    _applyFilters();
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded,
                      color: AppColors.textMuted, size: 20),
                  onPressed: _applyFilters,
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Status tab bar ────────────────────────────────────────────────
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _statusTabs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final isActive = _statusValues[i] == _statusFilter;
                return GestureDetector(
                  onTap: () {
                    setState(() => _statusFilter = _statusValues[i]);
                    _applyFilters();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color:
                          isActive ? AppColors.primary : AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isActive ? AppColors.primary : AppColors.border,
                      ),
                    ),
                    child: Text(
                      _statusTabs[i],
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isActive ? Colors.white : AppColors.textTertiary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // ── List ──────────────────────────────────────────────────────────
          Expanded(
            child: complaintsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2),
              ),
              error: (e, _) => Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 44, color: AppColors.textDisabled),
                  const SizedBox(height: 12),
                  Text('Failed to load complaints',
                      style: GoogleFonts.syne(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted)),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _applyFilters,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Retry'),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary),
                  ),
                ]),
              ),
              data: (complaints) {
                final filtered = _priorityFilter.isEmpty
                    ? complaints
                    : complaints
                        .where((c) => c.priority == _priorityFilter)
                        .toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.inbox_outlined,
                            size: 48, color: AppColors.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          _statusFilter.isEmpty && _priorityFilter.isEmpty
                              ? 'No complaints yet'
                              : 'No complaints match this filter',
                          style: GoogleFonts.syne(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Great job keeping things clean!',
                          style: GoogleFonts.dmSans(
                              fontSize: 12, color: AppColors.textDisabled),
                        ),
                      ],
                    ),
                  );
                }

                final sorted = [...filtered]
                  ..sort((a, b) => b.priorityOrder.compareTo(a.priorityOrder));

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                  itemCount: sorted.length,
                  itemBuilder: (_, i) => _ComplaintCard(
                    complaint: sorted[i],
                    onTap: () => _showDetail(context, ref, sorted[i]),
                    onStatusChange: (newStatus) =>
                        ref.read(adminComplaintsProvider.notifier).updateStatus(
                              sorted[i].id,
                              newStatus,
                            ),
                    // Intercept "resolved" to open the resolution dialog
                    onResolve: () => _showResolveDialog(context, sorted[i]),
                  ).animate().fadeIn(delay: (i * 40).ms).slideY(begin: 0.03),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showDetail(
      BuildContext context, WidgetRef ref, ComplaintModel complaint) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ComplaintDetailSheet(
        complaint: complaint,
        onStatusChange: (newStatus) {
          ref
              .read(adminComplaintsProvider.notifier)
              .updateStatus(complaint.id, newStatus);
          Navigator.pop(context);
        },
        // Intercept "resolved" from the detail sheet too
        onResolve: () {
          Navigator.pop(context); // close sheet first
          _showResolveDialog(context, complaint);
        },
      ),
    );
  }
}

// ── Status toggle for dialog ──────────────────────────────────────────────────

class _StatusToggle extends StatelessWidget {
  const _StatusToggle({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.color,
    required this.onTap,
  });
  final String label;
  final String value;
  final String groupValue;
  final Color color;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected ? color.withValues(alpha: 0.12) : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (isSelected)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Icon(Icons.check_rounded, size: 12, color: color),
            ),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? color : AppColors.textTertiary,
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Priority filter chip ──────────────────────────────────────────────────────

class _PriorityFilterChip extends StatelessWidget {
  const _PriorityFilterChip({
    required this.current,
    required this.onChanged,
  });
  final String current;
  final ValueChanged<String> onChanged;

  static const _options = [
    ('All', ''),
    ('Critical', 'critical'),
    ('High', 'high'),
    ('Medium', 'medium'),
    ('Low', 'low'),
  ];

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
        color: AppColors.surfaceAlt,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onSelected: onChanged,
        offset: const Offset(0, 36),
        itemBuilder: (_) => _options
            .map((opt) => PopupMenuItem<String>(
                  value: opt.$2,
                  child: Row(children: [
                    if (opt.$2.isNotEmpty)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: _priorityColor(opt.$2),
                          shape: BoxShape.circle,
                        ),
                      )
                    else
                      const SizedBox(width: 16),
                    Text(opt.$1,
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          color: current == opt.$2
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontWeight: current == opt.$2
                              ? FontWeight.w600
                              : FontWeight.w400,
                        )),
                  ]),
                ))
            .toList(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color:
                current.isEmpty ? AppColors.surfaceAlt : AppColors.primaryTint,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: current.isEmpty ? AppColors.border : AppColors.primary,
            ),
          ),
          child: Row(children: [
            Icon(
              Icons.filter_list_rounded,
              size: 14,
              color: current.isEmpty ? AppColors.textMuted : AppColors.primary,
            ),
            const SizedBox(width: 4),
            Text(
              current.isEmpty
                  ? 'Priority'
                  : current[0].toUpperCase() + current.substring(1),
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color:
                    current.isEmpty ? AppColors.textMuted : AppColors.primary,
              ),
            ),
          ]),
        ),
      );
}

// ── Complaint card ────────────────────────────────────────────────────────────

class _ComplaintCard extends StatelessWidget {
  const _ComplaintCard({
    required this.complaint,
    required this.onTap,
    required this.onStatusChange,
    required this.onResolve,
  });

  final ComplaintModel complaint;
  final VoidCallback onTap;
  final ValueChanged<String> onStatusChange;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    final priorityColor = _priorityColor(complaint.priority ?? '');
    final statusColor = _statusColor(complaint.status);
    final nextStatus = _nextStatus(complaint.status);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: complaint.priority == 'critical'
                ? AppColors.error.withValues(alpha: 0.35)
                : complaint.priority == 'high'
                    ? AppColors.warning.withValues(alpha: 0.25)
                    : AppColors.border,
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Top row ────────────────────────────────────────────────────
          Row(children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: priorityColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '#${complaint.shortId}',
              style: GoogleFonts.dmMono(
                  fontSize: 11, color: AppColors.textMuted, letterSpacing: 0.5),
            ),
            if (complaint.category != null) ...[
              const SizedBox(width: 8),
              _Badge(
                label: complaint.category!.replaceAll('_', ' '),
                color: AppColors.info,
              ),
            ],
            const Spacer(),
            _Badge(
              label: complaint.status.replaceAll('_', ' '),
              color: statusColor,
            ),
          ]),

          const SizedBox(height: 10),

          Text(
            complaint.rawText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 10),

          // ── Bottom row ─────────────────────────────────────────────────
          Row(children: [
            if (complaint.sentiment != null)
              _SentimentIcon(sentiment: complaint.sentiment!),
            if (complaint.sentiment != null) const SizedBox(width: 6),
            if (complaint.priority != null)
              _Badge(
                label: complaint.priority!,
                color: priorityColor,
                small: true,
              ),
            const Spacer(),
            Text(
              _formatDate(complaint.createdAt),
              style: GoogleFonts.dmSans(
                  fontSize: 10, color: AppColors.textDisabled),
            ),
            const SizedBox(width: 10),

            // Quick action button — "Resolve" opens dialog, others advance directly
            if (nextStatus != null)
              GestureDetector(
                onTap: nextStatus == 'resolved'
                    ? onResolve
                    : () => onStatusChange(nextStatus),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border:
                        Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    Icon(
                      nextStatus == 'resolved'
                          ? Icons.check_circle_outline_rounded
                          : Icons.arrow_forward_rounded,
                      size: 10,
                      color: statusColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _nextStatusLabel(nextStatus),
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ]),
                ),
              ),
          ]),
        ]),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ── Complaint detail bottom sheet ─────────────────────────────────────────────

class _ComplaintDetailSheet extends StatelessWidget {
  const _ComplaintDetailSheet({
    required this.complaint,
    required this.onStatusChange,
    required this.onResolve,
  });

  final ComplaintModel complaint;
  final ValueChanged<String> onStatusChange;
  final VoidCallback onResolve;

  static const _allStatuses = ['open', 'in_review', 'resolved', 'closed'];

  @override
  Widget build(BuildContext context) {
    final priorityColor = _priorityColor(complaint.priority ?? '');

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      expand: false,
      builder: (_, controller) => SingleChildScrollView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Handle
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
          ),

          // ── Header ──────────────────────────────────────────────────────
          Row(children: [
            Container(
              width: 10,
              height: 10,
              decoration:
                  BoxDecoration(color: priorityColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Text(
              'Complaint #${complaint.shortId}',
              style: GoogleFonts.syne(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary),
            ),
          ]),

          const SizedBox(height: 4),
          Text(
            _formatDateTime(complaint.createdAt),
            style:
                GoogleFonts.dmSans(fontSize: 12, color: AppColors.textDisabled),
          ),

          const SizedBox(height: 16),

          // ── Badges ──────────────────────────────────────────────────────
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (complaint.category != null)
              _Badge(
                  label: complaint.category!.replaceAll('_', ' '),
                  color: AppColors.info),
            if (complaint.sentiment != null)
              _SentimentBadge(sentiment: complaint.sentiment!),
            if (complaint.priority != null)
              _Badge(
                  label: '${complaint.priority} priority',
                  color: priorityColor),
            _Badge(
              label: complaint.status.replaceAll('_', ' '),
              color: _statusColor(complaint.status),
            ),
          ]),

          const SizedBox(height: 20),

          // ── Full text ───────────────────────────────────────────────────
          Text(
            'Complaint',
            style: GoogleFonts.syne(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
                letterSpacing: 1.2),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              complaint.rawText,
              style: GoogleFonts.dmSans(
                  fontSize: 14, color: AppColors.textSecondary, height: 1.6),
            ),
          ),

          if (complaint.orderId != null) ...[
            const SizedBox(height: 12),
            _DetailRow('Order',
                '#${complaint.orderId!.substring(0, 8).toUpperCase()}'),
          ],

          const SizedBox(height: 24),

          // ── Status transitions ───────────────────────────────────────────
          Text(
            'Update Status',
            style: GoogleFonts.syne(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
                letterSpacing: 1.2),
          ),
          const SizedBox(height: 10),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allStatuses.map((s) {
              final isCurrent = s == complaint.status;
              final color = _statusColor(s);
              return GestureDetector(
                // "resolved" always opens the resolution dialog
                onTap: isCurrent
                    ? null
                    : s == 'resolved'
                        ? onResolve
                        : () => onStatusChange(s),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? color.withValues(alpha: 0.15)
                        : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isCurrent ? color : AppColors.border,
                      width: isCurrent ? 1.5 : 1,
                    ),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (isCurrent)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child:
                            Icon(Icons.check_rounded, size: 12, color: color),
                      )
                    else if (s == 'resolved')
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(Icons.mail_outline_rounded,
                            size: 12, color: color),
                      ),
                    Text(
                      s == 'resolved' && !isCurrent
                          ? 'Resolve + Email'
                          : s.replaceAll('_', ' '),
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight:
                            isCurrent ? FontWeight.w700 : FontWeight.w500,
                        color: isCurrent ? color : AppColors.textTertiary,
                      ),
                    ),
                  ]),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.info_outline_rounded,
                size: 11, color: AppColors.textDisabled),
            const SizedBox(width: 4),
            Text(
              '"Resolve + Email" sends a resolution message to the customer.',
              style: GoogleFonts.dmSans(
                  fontSize: 11, color: AppColors.textDisabled),
            ),
          ]),
        ]),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final h = dt.hour > 12
        ? dt.hour - 12
        : dt.hour == 0
            ? 12
            : dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}  $h:$m $period';
  }
}

// ── Shared helpers ─────────────────────────────────────────────────────────────

Color _priorityColor(String priority) => switch (priority) {
      'critical' => AppColors.error,
      'high' => AppColors.warning,
      'medium' => AppColors.primary,
      'low' => AppColors.success,
      _ => AppColors.textDisabled,
    };

Color _statusColor(String status) => switch (status) {
      'open' => AppColors.error,
      'in_review' => AppColors.warning,
      'resolved' => AppColors.success,
      'closed' => AppColors.textMuted,
      _ => AppColors.textDisabled,
    };

String? _nextStatus(String current) => switch (current) {
      'open' => 'in_review',
      'in_review' => 'resolved',
      'resolved' => 'closed',
      _ => null,
    };

String _nextStatusLabel(String status) => switch (status) {
      'in_review' => 'Review',
      'resolved' => 'Resolve',
      'closed' => 'Close',
      _ => status,
    };

// ── Small reusable widgets ────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color, this.small = false});
  final String label;
  final Color color;
  final bool small;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(
          horizontal: small ? 6 : 8,
          vertical: small ? 2 : 3,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: small ? 9 : 10,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0.3,
          ),
        ),
      );
}

class _SentimentIcon extends StatelessWidget {
  const _SentimentIcon({required this.sentiment});
  final String sentiment;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (sentiment) {
      'positive' => (Icons.sentiment_satisfied_alt_rounded, AppColors.success),
      'neutral' => (Icons.sentiment_neutral_rounded, AppColors.textMuted),
      'negative' => (Icons.sentiment_dissatisfied_rounded, AppColors.warning),
      'very_negative' => (
          Icons.sentiment_very_dissatisfied_rounded,
          AppColors.error
        ),
      _ => (Icons.sentiment_neutral_rounded, AppColors.textDisabled),
    };
    return Icon(icon, size: 14, color: color);
  }
}

class _SentimentBadge extends StatelessWidget {
  const _SentimentBadge({required this.sentiment});
  final String sentiment;

  @override
  Widget build(BuildContext context) {
    final color = switch (sentiment) {
      'positive' => AppColors.success,
      'neutral' => AppColors.textMuted,
      'negative' => AppColors.warning,
      'very_negative' => AppColors.error,
      _ => AppColors.textDisabled,
    };
    final icon = switch (sentiment) {
      'positive' => Icons.sentiment_satisfied_alt_rounded,
      'neutral' => Icons.sentiment_neutral_rounded,
      'negative' => Icons.sentiment_dissatisfied_rounded,
      'very_negative' => Icons.sentiment_very_dissatisfied_rounded,
      _ => Icons.sentiment_neutral_rounded,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Text(
          sentiment.replaceAll('_', ' '),
          style: GoogleFonts.dmSans(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.3),
        ),
      ]),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Text(label,
              style:
                  GoogleFonts.dmSans(fontSize: 13, color: AppColors.textMuted)),
          const Spacer(),
          Text(value,
              style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
        ]),
      );
}
