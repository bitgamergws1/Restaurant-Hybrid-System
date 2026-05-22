// ─────────────────────────────────────────────────────────────────────────────
// Analytics models — mirror the /admin/analytics response shape.
// ─────────────────────────────────────────────────────────────────────────────

final class AnalyticsSummary {
  const AnalyticsSummary({
    required this.totalOrders,
    required this.paidOrders,
    required this.cancelledOrders,
    required this.dineInOrders,
    required this.deliveryOrders,
    required this.totalRevenue,
    required this.totalGst,
    required this.totalSubtotal,
    required this.averageOrderValue,
  });

  final int totalOrders;
  final int paidOrders;
  final int cancelledOrders;
  final int dineInOrders;
  final int deliveryOrders;
  final double totalRevenue;
  final double totalGst;
  final double totalSubtotal;
  final double averageOrderValue;

  factory AnalyticsSummary.fromJson(Map<String, dynamic> j) => AnalyticsSummary(
        totalOrders: j['total_orders'] as int? ?? 0,
        paidOrders: j['paid_orders'] as int? ?? 0,
        cancelledOrders: j['cancelled_orders'] as int? ?? 0,
        dineInOrders: j['dine_in_orders'] as int? ?? 0,
        deliveryOrders: j['delivery_orders'] as int? ?? 0,
        totalRevenue: double.parse((j['total_revenue'] ?? 0).toString()),
        totalGst: double.parse((j['total_gst_collected'] ?? 0).toString()),
        totalSubtotal: double.parse((j['total_subtotal'] ?? 0).toString()),
        averageOrderValue:
            double.parse((j['average_order_value'] ?? 0).toString()),
      );
}

final class DailyBreakdown {
  const DailyBreakdown({
    required this.date,
    required this.revenue,
    required this.orders,
  });

  final String date;
  final double revenue;
  final int orders;

  factory DailyBreakdown.fromJson(Map<String, dynamic> j) => DailyBreakdown(
        date: j['date'] as String,
        revenue: double.parse((j['revenue'] ?? 0).toString()),
        orders: j['orders'] as int? ?? 0,
      );
}

final class TopItem {
  const TopItem({
    required this.itemName,
    required this.totalQuantitySold,
    required this.totalRevenue,
  });

  final String itemName;
  final int totalQuantitySold;
  final double totalRevenue;

  factory TopItem.fromJson(Map<String, dynamic> j) => TopItem(
        itemName: j['item_name'] as String,
        totalQuantitySold: j['total_quantity_sold'] as int? ?? 0,
        totalRevenue: double.parse((j['total_revenue'] ?? 0).toString()),
      );
}

final class ComplaintsSummary {
  const ComplaintsSummary({
    required this.total,
    required this.byPriority,
    required this.byStatus,
  });

  final int total;
  final Map<String, int> byPriority;
  final Map<String, int> byStatus;

  factory ComplaintsSummary.fromJson(Map<String, dynamic> j) =>
      ComplaintsSummary(
        total: j['total'] as int? ?? 0,
        byPriority: Map<String, int>.from(
          (j['by_priority'] as Map<String, dynamic>?)?.map(
                (k, v) => MapEntry(k, (v as num).toInt()),
              ) ??
              {},
        ),
        byStatus: Map<String, int>.from(
          (j['by_status'] as Map<String, dynamic>?)?.map(
                (k, v) => MapEntry(k, (v as num).toInt()),
              ) ??
              {},
        ),
      );
}

final class AnalyticsData {
  const AnalyticsData({
    required this.summary,
    required this.dailyBreakdown,
    required this.topSellingItems,
    required this.complaints,
    required this.menuTotal,
    required this.menuAvailable,
  });

  final AnalyticsSummary summary;
  final List<DailyBreakdown> dailyBreakdown;
  final List<TopItem> topSellingItems;
  final ComplaintsSummary complaints;
  final int menuTotal;
  final int menuAvailable;

  factory AnalyticsData.fromJson(Map<String, dynamic> j) => AnalyticsData(
        summary:
            AnalyticsSummary.fromJson(j['summary'] as Map<String, dynamic>),
        dailyBreakdown: (j['daily_breakdown'] as List<dynamic>? ?? [])
            .map((e) => DailyBreakdown.fromJson(e as Map<String, dynamic>))
            .toList(),
        topSellingItems: (j['top_selling_items'] as List<dynamic>? ?? [])
            .map((e) => TopItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        complaints: ComplaintsSummary.fromJson(
            j['complaints'] as Map<String, dynamic>? ?? {}),
        menuTotal:
            (j['menu'] as Map<String, dynamic>?)?['total_items'] as int? ?? 0,
        menuAvailable:
            (j['menu'] as Map<String, dynamic>?)?['available_items'] as int? ??
                0,
      );
}
