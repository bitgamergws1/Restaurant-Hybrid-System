/// ─────────────────────────────────────────────────────────────────────────────
/// ComplaintModel — mirrors the `complaints` table row.
/// ─────────────────────────────────────────────────────────────────────────────
final class ComplaintModel {
  const ComplaintModel({
    required this.id,
    required this.rawText,
    required this.status,
    required this.createdAt,
    this.userId,
    this.orderId,
    this.category,
    this.sentiment,
    this.priority,
  });

  final String id;
  final String rawText;
  final String status; // open | in_review | resolved | closed
  final DateTime createdAt;
  final String? userId;
  final String? orderId;
  final String?
      category; // food_quality | delivery | service | billing | hygiene | other
  final String? sentiment; // positive | neutral | negative | very_negative
  final String? priority; // low | medium | high | critical

  String get shortId => id.substring(0, 8).toUpperCase();

  bool get isOpen => status == 'open';
  bool get isResolved => status == 'resolved' || status == 'closed';

  /// Numeric urgency for sorting — higher = more urgent.
  int get priorityOrder {
    const map = {'critical': 4, 'high': 3, 'medium': 2, 'low': 1};
    return map[priority] ?? 0;
  }

  factory ComplaintModel.fromJson(Map<String, dynamic> j) => ComplaintModel(
        id: j['id'] as String,
        rawText: j['raw_text'] as String,
        status: j['status'] as String? ?? 'open',
        createdAt: DateTime.parse(j['created_at'] as String),
        userId: j['user_id'] as String?,
        orderId: j['order_id'] as String?,
        category: j['category'] as String?,
        sentiment: j['sentiment'] as String?,
        priority: j['priority'] as String?,
      );

  @override
  bool operator ==(Object other) => other is ComplaintModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
