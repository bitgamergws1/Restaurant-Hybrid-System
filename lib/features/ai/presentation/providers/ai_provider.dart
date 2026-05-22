import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/ai_repository.dart';

// ── Chat message model ────────────────────────────────────────────────────────

enum MessageRole { user, assistant }

final class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.timestamp,
    this.isLoading = false,
  });

  final String id;
  final MessageRole role;
  final String text;
  final DateTime timestamp;
  final bool isLoading;

  bool get isUser => role == MessageRole.user;
  bool get isAssistant => role == MessageRole.assistant;

  ChatMessage copyWith({
    String? text,
    bool? isLoading,
  }) =>
      ChatMessage(
        id: id,
        role: role,
        text: text ?? this.text,
        timestamp: timestamp,
        isLoading: isLoading ?? this.isLoading,
      );

  @override
  String toString() =>
      'ChatMessage(role: $role, text: ${text.substring(0, text.length.clamp(0, 40))}...)';
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
    // Seed with a welcome message from the AI waiter.
    return AiChatState(
      messages: [
        ChatMessage(
          id: _nextId(),
          role: MessageRole.assistant,
          text: 'Hello! I am your AI Waiter at Spice Route.\n\n'
              'Tell me what you are in the mood for — spicy, mild, vegetarian, '
              'something light — and I will recommend the perfect dishes for you.',
          timestamp: DateTime.now(),
        ),
      ],
    );
  }

  AiRepository get _repo => ref.read(aiRepositoryProvider);

  static String _nextId() => 'msg_${++_idCounter}';

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isSending) return;

    // Append user message.
    final userMsg = ChatMessage(
      id: _nextId(),
      role: MessageRole.user,
      text: trimmed,
      timestamp: DateTime.now(),
    );

    // Append a loading placeholder for the assistant.
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

    // Replace loading placeholder with actual response.
    final updatedMessages = state.messages.map((m) {
      if (m.id == loadingMsg.id) {
        return m.copyWith(
          text: result.success && result.recommendation != null
              ? result.recommendation!
              : (result.error ?? 'Something went wrong. Please try again.'),
          isLoading: false,
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

// ── Complaint triage state ────────────────────────────────────────────────────

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

  Future<void> submit({
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
      state = TriageSuccess(
        complaintId: null,
        triage: result.triage!,
      );
    } else {
      state = TriageError(
        result.error ?? 'Could not submit complaint. Please try again.',
      );
    }
  }

  void reset() => state = const TriageIdle();
}

final triageProvider = AutoDisposeNotifierProvider<TriageNotifier, TriageState>(
  TriageNotifier.new,
);
