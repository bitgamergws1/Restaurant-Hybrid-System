import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/ai_repository.dart';
import '../../../menu/data/menu_repository.dart';
import '../../../menu/domain/models/menu_item_model.dart';

// ── Chat message model ────────────────────────────────────────────────────────

enum MessageRole { user, assistant }

final class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.timestamp,
    this.isLoading = false,
    this.suggestedItems = const [],
  });

  final String id;
  final MessageRole role;
  final String text;
  final DateTime timestamp;
  final bool isLoading;

  /// Menu items extracted from the AI response — rendered as tappable cards.
  final List<MenuItemModel> suggestedItems;

  bool get isUser => role == MessageRole.user;
  bool get isAssistant => role == MessageRole.assistant;

  ChatMessage copyWith({
    String? text,
    bool? isLoading,
    List<MenuItemModel>? suggestedItems,
  }) =>
      ChatMessage(
        id: id,
        role: role,
        text: text ?? this.text,
        timestamp: timestamp,
        isLoading: isLoading ?? this.isLoading,
        suggestedItems: suggestedItems ?? this.suggestedItems,
      );
}

// ── Markdown stripper ─────────────────────────────────────────────────────────
// The AI backend sometimes returns **bold** or *italic* markers.
// Strip them so plain text renders cleanly in the bubble.

String stripMarkdown(String text) {
  return text
      .replaceAllMapped(
          RegExp(r'\*\*(.*?)\*\*', dotAll: true), (m) => m.group(1) ?? '')
      .replaceAllMapped(
          RegExp(r'\*(.*?)\*', dotAll: true), (m) => m.group(1) ?? '')
      .replaceAllMapped(
          RegExp(r'__(.*?)__', dotAll: true), (m) => m.group(1) ?? '')
      .replaceAllMapped(
          RegExp(r'_(.*?)_', dotAll: true), (m) => m.group(1) ?? '');
}

// ── Chat state ────────────────────────────────────────────────────────────────

final class AiChatState {
  const AiChatState({
    required this.messages,
    this.isSending = false,
    this.error,
  });

  final List<ChatMessage> messages;
  final bool isSending;
  final String? error;

  bool get hasMessages => messages.isNotEmpty;

  AiChatState copyWith({
    List<ChatMessage>? messages,
    bool? isSending,
    String? error,
  }) =>
      AiChatState(
        messages: messages ?? this.messages,
        isSending: isSending ?? this.isSending,
        error: error,
      );

  static const AiChatState initial = AiChatState(messages: []);
}

// ── Notifier ──────────────────────────────────────────────────────────────────

final class AiChatNotifier extends AutoDisposeNotifier<AiChatState> {
  static int _idCounter = 0;

  @override
  AiChatState build() {
    return AiChatState(
      messages: [
        ChatMessage(
          id: _nextId(),
          role: MessageRole.assistant,
          text: 'Hello! I\'m your AI Waiter at Spice Route.\n\n'
              'Tell me what you are in the mood for — spicy, mild, '
              'vegetarian, something light — and I\'ll recommend '
              'the perfect dishes for you.',
          timestamp: DateTime.now(),
        ),
      ],
    );
  }

  AiRepository get _repo => ref.read(aiRepositoryProvider);
  MenuRepository get _menuRepo => ref.read(menuRepositoryProvider);

  static String _nextId() => 'msg_${++_idCounter}';

  // ── Extract menu items mentioned in the AI response ──────────────────────

  Future<List<MenuItemModel>> _extractSuggestedItems(String cleanText) async {
    try {
      final allItems = await _menuRepo.getMenu();
      final lower = cleanText.toLowerCase();

      // 1. Direct name match (highest confidence)
      final direct = allItems
          .where((item) => lower.contains(item.name.toLowerCase()))
          .toList();

      if (direct.isNotEmpty) {
        return direct.take(5).toList();
      }

      // 2. Word-level partial match as fallback
      final words = lower
          .split(RegExp(r'[\s,।\-\(\)]+'))
          .where((w) => w.length > 3)
          .toSet();

      return allItems
          .where(
              (item) => words.any((w) => item.name.toLowerCase().contains(w)))
          .take(5)
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Send message ─────────────────────────────────────────────────────────

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isSending) return;

    final userMsg = ChatMessage(
      id: _nextId(),
      role: MessageRole.user,
      text: trimmed,
      timestamp: DateTime.now(),
    );

    final loadingMsg = ChatMessage(
      id: _nextId(),
      role: MessageRole.assistant,
      text: '',
      timestamp: DateTime.now(),
      isLoading: true,
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg, loadingMsg],
      isSending: true,
      error: null,
    );

    final result = await _repo.getRecommendation(trimmed);

    // Strip markdown from raw AI response before storing.
    final rawText = result.success && result.recommendation != null
        ? result.recommendation!
        : (result.error ?? 'Something went wrong. Please try again.');
    final cleanText = stripMarkdown(rawText);

    // Extract matching menu items using the clean (no asterisks) text.
    final suggested = result.success
        ? await _extractSuggestedItems(cleanText)
        : <MenuItemModel>[];

    final updatedMessages = state.messages.map((m) {
      if (m.id == loadingMsg.id) {
        return m.copyWith(
          text: cleanText,
          isLoading: false,
          suggestedItems: suggested,
        );
      }
      return m;
    }).toList();

    state = state.copyWith(
      messages: updatedMessages,
      isSending: false,
      error: result.success ? null : result.error,
    );
  }

  void clearError() => state = state.copyWith(error: null);

  void clearHistory() => state = build();
}

final aiChatProvider = AutoDisposeNotifierProvider<AiChatNotifier, AiChatState>(
  AiChatNotifier.new,
);

// ── Complaint triage ──────────────────────────────────────────────────────────

sealed class TriageState {
  const TriageState();
}

final class TriageIdle extends TriageState {
  const TriageIdle();
}

final class TriageLoading extends TriageState {
  const TriageLoading();
}

final class TriageSuccess extends TriageState {
  const TriageSuccess({required this.complaintId, required this.triage});
  final String? complaintId;
  final Map<String, dynamic> triage;
}

final class TriageError extends TriageState {
  const TriageError(this.message);
  final String message;
}

final class TriageNotifier extends AutoDisposeNotifier<TriageState> {
  @override
  TriageState build() => const TriageIdle();

  Future<TriageState> submit({
    required String text,
    String? userId,
    String? orderId,
  }) async {
    state = const TriageLoading();

    final result = await ref.read(aiRepositoryProvider).triageComplaint(
          text: text,
          userId: userId,
          orderId: orderId,
        );

    if (result.success && result.triage != null) {
      state = TriageSuccess(complaintId: null, triage: result.triage!);
    } else {
      state = TriageError(
        result.error ?? 'Could not submit complaint. Please try again.',
      );
    }

    // Return the final state directly so callers don't need a second
    // ref.read() after the await — which would race against AutoDispose
    // resetting the provider back to TriageIdle when no listener is active.
    return state;
  }

  void reset() => state = const TriageIdle();
}

final triageProvider = AutoDisposeNotifierProvider<TriageNotifier, TriageState>(
  TriageNotifier.new,
);
