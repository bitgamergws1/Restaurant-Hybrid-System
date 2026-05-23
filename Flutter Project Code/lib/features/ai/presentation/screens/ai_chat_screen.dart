import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../../../menu/domain/models/menu_item_model.dart';
import '../providers/ai_provider.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// AiChatScreen
/// ─────────────────────────────────────────────────────────────────────────────
class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();
  bool _inputHasText = false;

  @override
  void initState() {
    super.initState();
    _inputCtrl.addListener(() {
      final hasText = _inputCtrl.text.trim().isNotEmpty;
      if (hasText != _inputHasText) setState(() => _inputHasText = hasText);
    });
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    setState(() => _inputHasText = false);
    ref.read(aiChatProvider.notifier).sendMessage(text);
    _scrollToBottom(delay: 100);
  }

  void _scrollToBottom({int delay = 0}) {
    Future.delayed(Duration(milliseconds: delay), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent + 200,
          duration: const Duration(milliseconds: 340),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(aiChatProvider);

    ref.listen<AiChatState>(aiChatProvider, (prev, next) {
      if (next.messages.length != (prev?.messages.length ?? 0)) {
        _scrollToBottom(delay: 120);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(chatState),
      body: Column(
        children: [
          Expanded(
            child: chatState.messages.isEmpty
                ? const _EmptyState()
                : _MessageList(
                    messages: chatState.messages,
                    scrollCtrl: _scrollCtrl,
                  ),
          ),
          if (chatState.error != null) _ErrorBanner(message: chatState.error!),
          _InputBar(
            controller: _inputCtrl,
            focusNode: _focusNode,
            hasText: _inputHasText,
            isSending: chatState.isSending,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(AiChatState state) => AppBar(
        backgroundColor: AppColors.background,
        scrolledUnderElevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'AI Waiter',
                  style: GoogleFonts.syne(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  state.isSending ? 'Thinking...' : 'Online',
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    color:
                        state.isSending ? AppColors.warning : AppColors.success,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (state.messages.length > 1)
            IconButton(
              icon: const Icon(
                Icons.refresh_rounded,
                color: AppColors.textMuted,
                size: 20,
              ),
              tooltip: 'Clear chat',
              onPressed: () {
                HapticFeedback.lightImpact();
                ref.read(aiChatProvider.notifier).clearHistory();
              },
            ),
          const SizedBox(width: 4),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      );
}

// ── Message list ──────────────────────────────────────────────────────────────

class _MessageList extends StatelessWidget {
  const _MessageList({required this.messages, required this.scrollCtrl});
  final List<ChatMessage> messages;
  final ScrollController scrollCtrl;

  @override
  Widget build(BuildContext context) => ListView.builder(
        controller: scrollCtrl,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        itemCount: messages.length,
        itemBuilder: (_, i) => _MessageBubble(
          message: messages[i],
          isLast: i == messages.length - 1,
        )
            .animate()
            .fadeIn(duration: 280.ms)
            .slideY(begin: 0.08, duration: 280.ms),
      );
}

// ── Message bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isLast});
  final ChatMessage message;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: EdgeInsets.only(
        bottom: 12,
        left: isUser ? 48 : 0,
        right: isUser ? 0 : 48,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            const _AvatarDot(isUser: false),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Text bubble
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                    border: isUser ? null : Border.all(color: AppColors.border),
                    boxShadow: isUser
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.25),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            )
                          ]
                        : null,
                  ),
                  child: message.isLoading
                      ? const _TypingIndicator()
                      : Text(
                          // Text is already stripped of markdown in the provider.
                          message.text,
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            color:
                                isUser ? Colors.white : AppColors.textSecondary,
                            height: 1.55,
                          ),
                        ),
                ),

                const SizedBox(height: 4),
                Text(
                  _formatTime(message.timestamp),
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    color: AppColors.textDisabled,
                  ),
                ),

                // ── Dish cards below AI bubble ─────────────────────────
                if (!isUser &&
                    !message.isLoading &&
                    message.suggestedItems.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _SuggestedDishRow(items: message.suggestedItems),
                ],
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            const _AvatarDot(isUser: true),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _AvatarDot extends StatelessWidget {
  const _AvatarDot({required this.isUser});
  final bool isUser;

  @override
  Widget build(BuildContext context) => Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: isUser
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.surfaceAlt,
          shape: BoxShape.circle,
          border: Border.all(
            color: isUser
                ? AppColors.primary.withValues(alpha: 0.4)
                : AppColors.border,
          ),
        ),
        child: Icon(
          isUser ? Icons.person_rounded : Icons.auto_awesome_rounded,
          color: isUser ? AppColors.primary : AppColors.textMuted,
          size: 14,
        ),
      );
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          3,
          (i) => Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: AppColors.textMuted,
                shape: BoxShape.circle,
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(
                  begin: 0.6,
                  end: 1.0,
                  duration: 600.ms,
                  delay: (i * 200).ms,
                  curve: Curves.easeInOut,
                ),
          ),
        ),
      );
}

// ── Suggested dish cards ──────────────────────────────────────────────────────

class _SuggestedDishRow extends StatelessWidget {
  const _SuggestedDishRow({required this.items});
  final List<MenuItemModel> items;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recommended for you',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 168,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _DishCard(item: items[i])
                  .animate()
                  .fadeIn(delay: (i * 70).ms, duration: 240.ms)
                  .slideX(begin: 0.1, duration: 240.ms),
            ),
          ),
        ],
      );
}

class _DishCard extends ConsumerWidget {
  const _DishCard({required this.item});
  final MenuItemModel item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartItems = ref.watch(cartProvider);
    final inCart = cartItems.any((c) => c.menuItemId == item.id);
    final qty = inCart
        ? cartItems.firstWhere((c) => c.menuItemId == item.id).quantity
        : 0;

    return Container(
      width: 148,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: inCart
              ? AppColors.primary.withValues(alpha: 0.55)
              : AppColors.border,
          width: inCart ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image / placeholder
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: SizedBox(
              height: 72,
              width: double.infinity,
              child: item.imageUrl != null
                  ? Image.network(
                      item.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _PlaceholderImg(item: item),
                    )
                  : _PlaceholderImg(item: item),
            ),
          ),

          // Name & price
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      '₹${item.price.toStringAsFixed(0)}',
                      style: GoogleFonts.syne(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    const Spacer(),
                    // Veg / non-veg dot
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: item.isVeg
                            ? AppColors.success
                            : const Color(0xFFEF5350),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Spacer(),

          // Action area
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: inCart
                ? _QtyRow(item: item, qty: qty)
                : Row(
                    children: [
                      // Add to Cart
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            ref.read(cartProvider.notifier).add(item);
                          },
                          child: Container(
                            height: 30,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.primaryTint,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              '+ Cart',
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Buy Now (add + go to cart)
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          ref.read(cartProvider.notifier).add(item);
                          context.push('/cart');
                        },
                        child: Container(
                          height: 30,
                          width: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.shopping_bag_rounded,
                            color: Colors.white,
                            size: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _QtyRow extends ConsumerWidget {
  const _QtyRow({required this.item, required this.qty});
  final MenuItemModel item;
  final int qty;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _QtyBtn(
            icon: Icons.remove,
            onTap: () => ref.read(cartProvider.notifier).remove(item.id),
          ),
          Text(
            '$qty',
            style: GoogleFonts.syne(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          _QtyBtn(
            icon: Icons.add,
            onTap: () => ref.read(cartProvider.notifier).add(item),
          ),
        ],
      );
}

class _QtyBtn extends StatelessWidget {
  const _QtyBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: Colors.white),
        ),
      );
}

class _PlaceholderImg extends StatelessWidget {
  const _PlaceholderImg({required this.item});
  final MenuItemModel item;

  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.surface,
        child: Center(
          child: Text(
            item.name.isNotEmpty ? item.name[0].toUpperCase() : '?',
            style: GoogleFonts.syne(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: AppColors.primary.withValues(alpha: 0.55),
            ),
          ),
        ),
      );
}

// ── Input bar ─────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.hasText,
    required this.isSending,
    required this.onSend,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasText;
  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.fromLTRB(
          16,
          10,
          16,
          MediaQuery.of(context).padding.bottom + 10,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Quick suggestion chips
            const _SuggestionChips(),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Ask for a recommendation...',
                        hintStyle: GoogleFonts.dmSans(
                          fontSize: 14,
                          color: AppColors.textDisabled,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                      onSubmitted: (_) => onSend(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: hasText && !isSending
                        ? AppColors.primaryGradient
                        : null,
                    color: hasText && !isSending ? null : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: hasText && !isSending
                        ? null
                        : Border.all(color: AppColors.border),
                  ),
                  child: IconButton(
                    onPressed: hasText && !isSending ? onSend : null,
                    icon: isSending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation(AppColors.primary),
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(
                            Icons.send_rounded,
                            color:
                                hasText ? Colors.white : AppColors.textDisabled,
                            size: 18,
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 36,
              ),
            ).animate().scale(
                  begin: const Offset(0.5, 0.5),
                  curve: Curves.elasticOut,
                  duration: 600.ms,
                ),
            const SizedBox(height: 20),
            Text(
              'AI Waiter',
              style: GoogleFonts.syne(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 8),
            Text(
              'Tell me what you are craving and I will\nrecommend the best dishes for you.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: AppColors.textMuted,
                height: 1.5,
              ),
            ).animate().fadeIn(delay: 300.ms),
          ],
        ),
      );
}

// ── Error banner ──────────────────────────────────────────────────────────────

class _ErrorBanner extends ConsumerWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.errorTint,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.error, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.error),
              ),
            ),
            GestureDetector(
              onTap: () => ref.read(aiChatProvider.notifier).clearError(),
              child: const Icon(Icons.close_rounded,
                  color: AppColors.error, size: 16),
            ),
          ],
        ),
      ).animate().fadeIn().slideY(begin: 0.1);
}

// ── Suggestion chips ──────────────────────────────────────────────────────────

class _SuggestionChips extends ConsumerWidget {
  const _SuggestionChips();

  static const _suggestions = [
    'Something spicy 🌶️',
    'Best vegetarian dish',
    'Light lunch ideas',
    "Today's bestseller?",
    'Something sweet 🍮',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSending = ref.watch(aiChatProvider).isSending;
    return SizedBox(
      height: 30,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _suggestions.length,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: isSending
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    ref
                        .read(aiChatProvider.notifier)
                        .sendMessage(_suggestions[i]);
                  },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                _suggestions[i],
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: isSending
                      ? AppColors.textDisabled
                      : AppColors.textTertiary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
