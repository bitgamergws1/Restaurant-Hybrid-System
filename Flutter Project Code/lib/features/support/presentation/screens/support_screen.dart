import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../ai/presentation/providers/ai_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../orders/data/orders_repository.dart';
import '../../../orders/domain/models/order_model.dart';

// ── Support step enum ─────────────────────────────────────────────────────────

enum _SupportStep {
  issueType,
  orderRelated,
  selectOrder,
  describe,
  submitting,
  done,
}

// ── Issue type config ─────────────────────────────────────────────────────────

class _IssueType {
  const _IssueType(
      {required this.label, required this.icon, required this.emoji});
  final String label;
  final IconData icon;
  final String emoji;
}

const _issueTypes = [
  _IssueType(
      label: 'Food Quality', icon: Icons.restaurant_rounded, emoji: '🍽️'),
  _IssueType(
      label: 'Delivery Issue',
      icon: Icons.delivery_dining_rounded,
      emoji: '🛵'),
  _IssueType(
      label: 'Wrong / Missing Item',
      icon: Icons.remove_shopping_cart_rounded,
      emoji: '📦'),
  _IssueType(
      label: 'Billing Problem', icon: Icons.receipt_long_rounded, emoji: '💳'),
  _IssueType(
      label: 'Rude Staff',
      icon: Icons.sentiment_dissatisfied_rounded,
      emoji: '😤'),
  _IssueType(label: 'Other', icon: Icons.help_outline_rounded, emoji: '💬'),
];

// ── Chat bubble model ─────────────────────────────────────────────────────────

enum _BubbleSide { bot, user }

class _Bubble {
  const _Bubble({required this.side, required this.text});
  final _BubbleSide side;
  final String text;
}

// ─────────────────────────────────────────────────────────────────────────────
// SupportScreen
// ─────────────────────────────────────────────────────────────────────────────

class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key, this.prefillOrderId});

  /// Optional: pre-fill an order ID (navigated from order detail screen)
  final String? prefillOrderId;

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  _SupportStep _step = _SupportStep.issueType;
  final List<_Bubble> _bubbles = [];
  final ScrollController _scroll = ScrollController();
  final TextEditingController _descCtrl = TextEditingController();
  final FocusNode _descFocus = FocusNode();

  // ── Collected data ────────────────────────────────────────────────────────
  String? _selectedIssueType;
  OrderModel? _selectedOrder;
  String? _prefillOrderId;
  List<OrderModel> _recentOrders = [];
  bool _loadingOrders = false;

  @override
  void initState() {
    super.initState();
    _prefillOrderId = widget.prefillOrderId;
    _startConversation();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _descCtrl.dispose();
    _descFocus.dispose();
    super.dispose();
  }

  void _startConversation() {
    _bubbles.add(const _Bubble(
      side: _BubbleSide.bot,
      text:
          'Hi there! 👋 I\'m your Support Assistant.\n\nI\'ll help you report an issue quickly. First, what type of problem are you facing?',
    ));
  }

  void _addBubble(_Bubble bubble) {
    setState(() => _bubbles.add(bubble));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 200,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Step handlers ─────────────────────────────────────────────────────────

  void _onIssueSelected(_IssueType issue) {
    _selectedIssueType = issue.label;

    _addBubble(_Bubble(
      side: _BubbleSide.user,
      text: '${issue.emoji} ${issue.label}',
    ));

    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _addBubble(const _Bubble(
        side: _BubbleSide.bot,
        text: 'Got it. Is this complaint related to a specific order?',
      ));
      setState(() => _step = _SupportStep.orderRelated);
    });
  }

  void _onOrderRelated(bool isRelated) {
    _addBubble(_Bubble(
      side: _BubbleSide.user,
      text: isRelated ? '✅ Yes, it\'s order-related' : '❌ No, it\'s general',
    ));

    if (isRelated) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        _addBubble(const _Bubble(
          side: _BubbleSide.bot,
          text: 'Select the order this is about, or skip if you\'re not sure.',
        ));
        setState(() {
          _step = _SupportStep.selectOrder;
          _loadingOrders = true;
        });
        _loadRecentOrders();
      });
    } else {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        _addBubble(const _Bubble(
          side: _BubbleSide.bot,
          text:
              'No problem! Please describe your issue in as much detail as possible:',
        ));
        setState(() => _step = _SupportStep.describe);
        _descFocus.requestFocus();
      });
    }
  }

  Future<void> _loadRecentOrders() async {
    final auth = ref.read(authNotifierProvider);
    if (auth is! AuthAuthenticated) {
      setState(() => _loadingOrders = false);
      return;
    }

    try {
      final orders =
          await ref.read(ordersRepositoryProvider).getUserOrders(auth.user.id);
      setState(() {
        _recentOrders = orders
            .where((o) =>
                o.status != 'delivered' ||
                DateTime.now().difference(o.createdAt).inDays <= 7)
            .take(5)
            .toList();
        _loadingOrders = false;

        // If a prefill order ID was passed, auto-select it
        if (_prefillOrderId != null) {
          try {
            _selectedOrder =
                _recentOrders.firstWhere((o) => o.id == _prefillOrderId);
          } catch (_) {}
        }
      });
    } catch (_) {
      setState(() => _loadingOrders = false);
    }
  }

  void _onOrderSelected(OrderModel? order) {
    _selectedOrder = order;

    _addBubble(_Bubble(
      side: _BubbleSide.user,
      text: order != null
          ? '📋 Order #${order.shortId}'
          : '⏭️ Skip — not sure of order',
    ));

    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _addBubble(const _Bubble(
        side: _BubbleSide.bot,
        text:
            'Almost there! Please describe your issue clearly — the more details, the faster we can resolve it:',
      ));
      setState(() => _step = _SupportStep.describe);
      _descFocus.requestFocus();
    });
  }

  Future<void> _onSubmit() async {
    final description = _descCtrl.text.trim();
    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please describe your issue first.'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    final issueLabel = _selectedIssueType ?? 'Other';
    final orderRef =
        _selectedOrder != null ? '\nOrder: #${_selectedOrder!.shortId}' : '';
    final fullText =
        'Issue type: $issueLabel$orderRef\n\nCustomer description: $description';

    _addBubble(_Bubble(
      side: _BubbleSide.user,
      text: description,
    ));

    setState(() => _step = _SupportStep.submitting);

    _addBubble(const _Bubble(
      side: _BubbleSide.bot,
      text: '⏳ Submitting your complaint and analysing priority...',
    ));

    final auth = ref.read(authNotifierProvider);
    final userId = auth is AuthAuthenticated ? auth.user.id : null;

    // Capture the result directly from submit() — do NOT use ref.read(triageProvider)
    // after the await. AutoDispose resets the provider to TriageIdle when no widget
    // is watch()ing it, so a subsequent ref.read() always returns TriageIdle.
    final triageState = await ref.read(triageProvider.notifier).submit(
          text: fullText,
          userId: userId,
          orderId: _selectedOrder?.id,
        );

    if (!mounted) return;

    if (triageState is TriageSuccess) {
      final triage = triageState.triage;
      final priority = triage['priority'] as String? ?? 'medium';
      final category = (triage['category'] as String? ?? 'other')
          .replaceAll('_', ' ')
          .split(' ')
          .map((w) => w[0].toUpperCase() + w.substring(1))
          .join(' ');

      _addBubble(_Bubble(
        side: _BubbleSide.bot,
        text:
            '✅ Your complaint has been received and logged!\n\nCategory: $category\nPriority: ${priority.toUpperCase()}\n\nOur team will review it and reach out to you via email within 24 hours. We apologise for the inconvenience!',
      ));
      setState(() => _step = _SupportStep.done);
    } else if (triageState is TriageError) {
      _addBubble(const _Bubble(
        side: _BubbleSide.bot,
        text:
            '❌ Sorry, we couldn\'t submit your complaint right now. Please try again or contact us directly at support.',
      ));
      setState(() => _step = _SupportStep.describe);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 18),
          onPressed: () => context.pop(),
        ),
        title: Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.support_agent_rounded,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Customer Support',
                style: GoogleFonts.syne(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            Text('We\'re here to help',
                style: GoogleFonts.dmSans(
                    fontSize: 11, color: AppColors.textMuted)),
          ]),
        ]),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: Column(children: [
        // ── Chat bubbles ─────────────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            itemCount: _bubbles.length,
            itemBuilder: (_, i) => _BubbleWidget(bubble: _bubbles[i])
                .animate()
                .fadeIn(duration: 300.ms)
                .slideY(begin: 0.1, end: 0),
          ),
        ),

        // ── Interactive area ─────────────────────────────────────────────
        _buildInteractiveArea(),
      ]),
    );
  }

  Widget _buildInteractiveArea() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, anim) =>
          FadeTransition(opacity: anim, child: child),
      child: switch (_step) {
        _SupportStep.issueType => _IssueTypeChips(
            key: const ValueKey('issueType'),
            onSelected: _onIssueSelected,
          ),
        _SupportStep.orderRelated => _YesNoButtons(
            key: const ValueKey('orderRelated'),
            onYes: () => _onOrderRelated(true),
            onNo: () => _onOrderRelated(false),
          ),
        _SupportStep.selectOrder => _OrderSelector(
            key: const ValueKey('selectOrder'),
            orders: _recentOrders,
            isLoading: _loadingOrders,
            preSelected: _selectedOrder,
            onSelected: _onOrderSelected,
          ),
        _SupportStep.describe => _DescribeInput(
            key: const ValueKey('describe'),
            controller: _descCtrl,
            focusNode: _descFocus,
            onSubmit: _onSubmit,
          ),
        _SupportStep.submitting => const _SubmittingIndicator(
            key: ValueKey('submitting'),
          ),
        _SupportStep.done => _DoneActions(
            key: const ValueKey('done'),
            onNewIssue: () {
              setState(() {
                _step = _SupportStep.issueType;
                _bubbles.add(const _Bubble(
                  side: _BubbleSide.bot,
                  text: 'Of course! What other issue can I help you with?',
                ));
                _selectedIssueType = null;
                _selectedOrder = null;
                _descCtrl.clear();
                ref.invalidate(triageProvider);
              });
            },
            onGoBack: () => context.pop(),
          ),
      },
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _BubbleWidget extends StatelessWidget {
  const _BubbleWidget({required this.bubble});
  final _Bubble bubble;

  @override
  Widget build(BuildContext context) {
    final isBot = bubble.side == _BubbleSide.bot;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isBot ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isBot) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.support_agent_rounded,
                  color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isBot ? AppColors.surface : AppColors.primary,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(isBot ? 2 : 14),
                  bottomRight: Radius.circular(isBot ? 14 : 2),
                ),
                border: isBot ? Border.all(color: AppColors.border) : null,
              ),
              child: Text(
                bubble.text,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: isBot ? AppColors.textSecondary : Colors.white,
                  height: 1.5,
                ),
              ),
            ),
          ),
          if (!isBot) ...[
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.surfaceAlt,
              child: Icon(Icons.person_rounded,
                  color: AppColors.textMuted, size: 16),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Issue type chips ──────────────────────────────────────────────────────────

class _IssueTypeChips extends StatelessWidget {
  const _IssueTypeChips({super.key, required this.onSelected});
  final void Function(_IssueType) onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Select issue type',
            style: GoogleFonts.dmSans(
                fontSize: 11, color: AppColors.textMuted, letterSpacing: 0.5)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _issueTypes
              .map((issue) => GestureDetector(
                    onTap: () => onSelected(issue),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(issue.emoji, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Text(issue.label,
                            style: GoogleFonts.dmSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary)),
                      ]),
                    ),
                  ))
              .toList(),
        ),
      ]),
    );
  }
}

// ── Yes / No buttons ──────────────────────────────────────────────────────────

class _YesNoButtons extends StatelessWidget {
  const _YesNoButtons({super.key, required this.onYes, required this.onNo});
  final VoidCallback onYes;
  final VoidCallback onNo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(children: [
        Expanded(
          child: _QuickButton(
            label: '✅  Yes, order-related',
            color: AppColors.success,
            onTap: onYes,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickButton(
            label: '❌  No, general issue',
            color: AppColors.textMuted,
            onTap: onNo,
          ),
        ),
      ]),
    );
  }
}

// ── Order selector ────────────────────────────────────────────────────────────

class _OrderSelector extends StatefulWidget {
  const _OrderSelector({
    super.key,
    required this.orders,
    required this.isLoading,
    required this.onSelected,
    this.preSelected,
  });
  final List<OrderModel> orders;
  final bool isLoading;
  final OrderModel? preSelected;
  final void Function(OrderModel?) onSelected;

  @override
  State<_OrderSelector> createState() => _OrderSelectorState();
}

class _OrderSelectorState extends State<_OrderSelector> {
  OrderModel? _picked;

  @override
  void initState() {
    super.initState();
    _picked = widget.preSelected;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Select order (optional)',
                style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    letterSpacing: 0.5)),
            const SizedBox(height: 8),
            if (widget.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(AppColors.primary)),
                  ),
                ),
              )
            else if (widget.orders.isEmpty)
              Text('No recent orders found.',
                  style: GoogleFonts.dmSans(
                      fontSize: 13, color: AppColors.textMuted))
            else
              SizedBox(
                height: 120,
                child: ListView.separated(
                  itemCount: widget.orders.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: AppColors.border),
                  itemBuilder: (_, i) {
                    final order = widget.orders[i];
                    final selected = _picked?.id == order.id;
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _picked = selected ? null : order),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 4),
                        color: selected
                            ? AppColors.primary.withValues(alpha: 0.08)
                            : Colors.transparent,
                        child: Row(children: [
                          Icon(
                            selected
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: selected
                                ? AppColors.primary
                                : AppColors.textDisabled,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('#${order.shortId}',
                                      style: GoogleFonts.syne(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary)),
                                  Text(
                                    '${order.isDineIn ? 'Dine-In' : 'Delivery'}  ·  Rs. ${order.totalAmount.toStringAsFixed(0)}',
                                    style: GoogleFonts.dmSans(
                                        fontSize: 11,
                                        color: AppColors.textMuted),
                                  ),
                                ]),
                          ),
                        ]),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: _QuickButton(
                  label: _picked != null
                      ? 'Continue with #${_picked!.shortId}'
                      : 'Continue without order',
                  color: AppColors.primary,
                  onTap: () => widget.onSelected(_picked),
                ),
              ),
            ]),
          ]),
    );
  }
}

// ── Describe input ────────────────────────────────────────────────────────────

class _DescribeInput extends StatelessWidget {
  const _DescribeInput({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            maxLines: 4,
            minLines: 1,
            maxLength: 1000,
            style:
                GoogleFonts.dmSans(fontSize: 14, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Describe your issue in detail...',
              hintStyle: GoogleFonts.dmSans(
                  fontSize: 14, color: AppColors.textDisabled),
              filled: true,
              fillColor: AppColors.surfaceAlt,
              contentPadding: const EdgeInsets.all(14),
              counterStyle: GoogleFonts.dmSans(
                  fontSize: 11, color: AppColors.textDisabled),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: onSubmit,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                const Icon(Icons.send_rounded, color: Colors.white, size: 20),
          ),
        ),
      ]),
    );
  }
}

// ── Submitting indicator ──────────────────────────────────────────────────────

class _SubmittingIndicator extends StatelessWidget {
  const _SubmittingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
        const SizedBox(width: 12),
        Text('Analysing and submitting...',
            style:
                GoogleFonts.dmSans(fontSize: 14, color: AppColors.textMuted)),
      ]),
    );
  }
}

// ── Done actions ──────────────────────────────────────────────────────────────

class _DoneActions extends StatelessWidget {
  const _DoneActions(
      {super.key, required this.onNewIssue, required this.onGoBack});
  final VoidCallback onNewIssue;
  final VoidCallback onGoBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(children: [
        Expanded(
          child: _QuickButton(
            label: '🔄  Report another issue',
            color: AppColors.textMuted,
            onTap: onNewIssue,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickButton(
            label: '🏠  Go back',
            color: AppColors.primary,
            onTap: onGoBack,
          ),
        ),
      ]),
    );
  }
}

// ── Quick button ──────────────────────────────────────────────────────────────

class _QuickButton extends StatelessWidget {
  const _QuickButton(
      {required this.label, required this.color, required this.onTap});
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color == AppColors.textMuted
                    ? AppColors.textSecondary
                    : color),
          ),
        ),
      );
}
