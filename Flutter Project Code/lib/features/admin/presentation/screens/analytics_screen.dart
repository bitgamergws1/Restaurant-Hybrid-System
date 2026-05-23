import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../providers/admin_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// IST utilities
// Supabase stores timestamps in UTC. All display and bucketing is in IST.
// ─────────────────────────────────────────────────────────────────────────────

const _ist = Duration(hours: 5, minutes: 30);

DateTime _toIST(DateTime utc) => utc.toUtc().add(_ist);
DateTime _toUTC(DateTime ist) => ist.subtract(_ist);

DateTime _istNow() => _toIST(DateTime.now().toUtc());

String _istDateKey(DateTime utc) {
  final ist = _toIST(utc);
  return '${ist.year}-${ist.month.toString().padLeft(2, '0')}-${ist.day.toString().padLeft(2, '0')}';
}

int _istHour(DateTime utc) => _toIST(utc).hour;

// ─────────────────────────────────────────────────────────────────────────────
// Time range
// ─────────────────────────────────────────────────────────────────────────────

enum TimeRange {
  day1('1D', 1),
  day3('3D', 3),
  day7('7D', 7),
  day30('30D', 30);

  const TimeRange(this.label, this.days);
  final String label;
  final int days;

  /// ISO-8601 UTC string to pass as `from` query param.
  String get fromUtcISO {
    final nowIST = _istNow();
    final startIST =
        DateTime(nowIST.year, nowIST.month, nowIST.day - (days - 1));
    return _toUTC(startIST).toIso8601String();
  }

  String get toUtcISO => DateTime.now().toUtc().toIso8601String();
}

// ─────────────────────────────────────────────────────────────────────────────
// Computed chart data (derived from raw AdminOrderModel list)
// ─────────────────────────────────────────────────────────────────────────────

class _ChartData {
  const _ChartData({
    required this.revenueTrend,
    required this.ordersTrend,
    required this.dineInTrend,
    required this.deliveryTrend,
    required this.peakHours,
    required this.ogiveSpots,
    required this.ogiveBucketLabels,
    required this.dineInCount,
    required this.deliveryCount,
    required this.paidCount,
    required this.pendingCount,
    required this.failedCount,
    required this.statusCounts,
    required this.bucketLabels,
    required this.isHourly,
  });

  final List<FlSpot> revenueTrend;
  final List<FlSpot> ordersTrend;
  final List<FlSpot> dineInTrend;
  final List<FlSpot> deliveryTrend;
  final List<double> peakHours; // index = IST hour 0-23
  final List<FlSpot> ogiveSpots;
  final List<String> ogiveBucketLabels;
  final int dineInCount;
  final int deliveryCount;
  final int paidCount;
  final int pendingCount;
  final int failedCount;
  final Map<String, int> statusCounts;
  final List<String> bucketLabels; // x-axis labels for trend charts
  final bool isHourly;

  static _ChartData empty() => _ChartData(
        revenueTrend: [],
        ordersTrend: [],
        dineInTrend: [],
        deliveryTrend: [],
        peakHours: List.filled(24, 0),
        ogiveSpots: [],
        ogiveBucketLabels: [],
        dineInCount: 0,
        deliveryCount: 0,
        paidCount: 0,
        pendingCount: 0,
        failedCount: 0,
        statusCounts: {},
        bucketLabels: [],
        isHourly: false,
      );

  static _ChartData fromOrders(
    List<AdminOrderModel> orders,
    TimeRange range,
  ) {
    if (orders.isEmpty) return _ChartData.empty();

    final isHourly = range == TimeRange.day1;

    // ── Trend buckets ──────────────────────────────────────────────────────
    final Map<String, double> revenueMap = {};
    final Map<String, int> ordersMap = {};
    final Map<String, int> dineInMap = {};
    final Map<String, int> deliveryMap = {};

    if (isHourly) {
      for (var h = 0; h < 24; h++) {
        final k = h.toString();
        revenueMap[k] = 0;
        ordersMap[k] = 0;
        dineInMap[k] = 0;
        deliveryMap[k] = 0;
      }
    } else {
      final nowIST = _istNow();
      for (var i = range.days - 1; i >= 0; i--) {
        final d = DateTime(nowIST.year, nowIST.month, nowIST.day - i);
        final k =
            '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        revenueMap[k] = 0;
        ordersMap[k] = 0;
        dineInMap[k] = 0;
        deliveryMap[k] = 0;
      }
    }

    // ── Status / type / payment counts ────────────────────────────────────
    int dineInCount = 0, deliveryCount = 0;
    int paidCount = 0, pendingCount = 0, failedCount = 0;
    final Map<String, int> statusCounts = {};

    // ── Peak hours ─────────────────────────────────────────────────────────
    final peakHours = List.filled(24, 0.0);

    // ── Order values for ogive ─────────────────────────────────────────────
    final List<double> orderValues = [];

    for (final o in orders) {
      final key = isHourly
          ? _istHour(o.createdAt).toString()
          : _istDateKey(o.createdAt);

      if (o.isPaid) {
        revenueMap[key] = (revenueMap[key] ?? 0) + o.totalAmount;
      }
      ordersMap[key] = (ordersMap[key] ?? 0) + 1;

      if (o.isDineIn) {
        dineInMap[key] = (dineInMap[key] ?? 0) + 1;
        dineInCount++;
      } else {
        deliveryMap[key] = (deliveryMap[key] ?? 0) + 1;
        deliveryCount++;
      }

      if (o.isPaid) paidCount++;
      if (o.paymentStatus == 'pending') pendingCount++;
      if (o.paymentStatus == 'failed') failedCount++;

      statusCounts[o.status] = (statusCounts[o.status] ?? 0) + 1;
      peakHours[_istHour(o.createdAt)] += 1;
      orderValues.add(o.totalAmount);
    }

    // ── Convert maps to FlSpot lists ──────────────────────────────────────
    final keys = revenueMap.keys.toList()..sort();

    final revenueTrend = keys
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), revenueMap[e.value] ?? 0))
        .toList();
    final ordersTrend = keys
        .asMap()
        .entries
        .map((e) =>
            FlSpot(e.key.toDouble(), (ordersMap[e.value] ?? 0).toDouble()))
        .toList();
    final dineInTrend = keys
        .asMap()
        .entries
        .map((e) =>
            FlSpot(e.key.toDouble(), (dineInMap[e.value] ?? 0).toDouble()))
        .toList();
    final deliveryTrend = keys
        .asMap()
        .entries
        .map((e) =>
            FlSpot(e.key.toDouble(), (deliveryMap[e.value] ?? 0).toDouble()))
        .toList();

    // ── Ogive (cumulative distribution of order values) ────────────────────
    final ogiveSpots = <FlSpot>[];
    final ogiveBucketLabels = <String>[];
    if (orderValues.isNotEmpty) {
      orderValues.sort();
      const bucketCount = 8;
      final minV = orderValues.first;
      final maxV = orderValues.last;
      final step = (maxV - minV) / bucketCount;
      final total = orderValues.length;
      var cumulative = 0;
      for (var i = 0; i <= bucketCount; i++) {
        final threshold = minV + step * i;
        cumulative = orderValues.where((v) => v <= threshold).length;
        ogiveSpots.add(FlSpot(i.toDouble(), (cumulative / total * 100)));
        ogiveBucketLabels.add('₹${threshold.round()}');
      }
    }

    // ── Bucket labels ──────────────────────────────────────────────────────
    final List<String> bucketLabels;
    if (isHourly) {
      bucketLabels = List.generate(24, (h) {
        final period = h < 12 ? 'AM' : 'PM';
        final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
        return '$h12$period';
      });
    } else {
      bucketLabels = keys.map((k) {
        final parts = k.split('-');
        return '${parts[2]}/${parts[1]}';
      }).toList();
    }

    return _ChartData(
      revenueTrend: revenueTrend,
      ordersTrend: ordersTrend,
      dineInTrend: dineInTrend,
      deliveryTrend: deliveryTrend,
      peakHours: peakHours.map((v) => v).toList(),
      ogiveSpots: ogiveSpots,
      ogiveBucketLabels: ogiveBucketLabels,
      dineInCount: dineInCount,
      deliveryCount: deliveryCount,
      paidCount: paidCount,
      pendingCount: pendingCount,
      failedCount: failedCount,
      statusCounts: statusCounts,
      bucketLabels: bucketLabels,
      isHourly: isHourly,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AnalyticsScreen
// ─────────────────────────────────────────────────────────────────────────────

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  TimeRange _range = TimeRange.day7;
  _ChartData _chartData = _ChartData.empty();
  AnalyticsData? _analyticsData;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Fetch aggregated analytics for summary cards
      final repo = ref.read(adminRepositoryProvider);
      final analytics = await repo.fetchAnalytics(
        from: _range.fromUtcISO,
        to: _range.toUtcISO,
      );

      // Fetch raw orders for chart computation (limit 500)
      final orders = await repo.fetchAllOrders(limit: 500);

      // Filter orders to selected range
      final rangeStart = DateTime.parse(_range.fromUtcISO);
      final filtered =
          orders.where((o) => o.createdAt.isAfter(rangeStart)).toList();

      if (mounted) {
        setState(() {
          _analyticsData = analytics;
          _chartData = _ChartData.fromOrders(filtered, _range);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _changeRange(TimeRange r) {
    if (r == _range) return;
    setState(() => _range = r);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header + range selector ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 0),
              child: Row(
                children: [
                  Text(
                    'Analytics',
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
                    onPressed: _loading ? null : _load,
                    tooltip: 'Refresh',
                  ),
                ],
              ),
            ),

            // Range pills
            _TimeRangeSelector(
              selected: _range,
              onChanged: _changeRange,
            ),

            // ── Content ───────────────────────────────────────────────────
            Expanded(
              child: _loading && _analyticsData == null
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2),
                    )
                  : _error != null && _analyticsData == null
                      ? _ErrorView(
                          message: _error!,
                          onRetry: _load,
                        )
                      : RefreshIndicator(
                          color: AppColors.primary,
                          backgroundColor: AppColors.surface,
                          onRefresh: _load,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                            children: [
                              if (_loading) const _LoadingBanner(),

                              // Summary KPI row
                              if (_analyticsData != null)
                                _SummaryRow(data: _analyticsData!),

                              const SizedBox(height: 12),

                              // Revenue trend line chart
                              if (_chartData.revenueTrend.isNotEmpty)
                                _RevenueTrendCard(
                                  spots: _chartData.revenueTrend,
                                  labels: _chartData.bucketLabels,
                                  isHourly: _chartData.isHourly,
                                  range: _range,
                                ),

                              const SizedBox(height: 12),

                              // Orders volume grouped bar chart
                              if (_chartData.ordersTrend.isNotEmpty)
                                _OrdersVolumeCard(
                                  totalSpots: _chartData.ordersTrend,
                                  dineInSpots: _chartData.dineInTrend,
                                  deliverySpots: _chartData.deliveryTrend,
                                  labels: _chartData.bucketLabels,
                                  isHourly: _chartData.isHourly,
                                ),

                              const SizedBox(height: 12),

                              // Peak hours bar chart (always IST 0-23)
                              _PeakHoursCard(
                                hourlyData: _chartData.peakHours,
                              ),

                              const SizedBox(height: 12),

                              // Two pie charts side by side
                              Row(
                                children: [
                                  Expanded(
                                    child: _PieCard(
                                      title: 'Order Type',
                                      sections: [
                                        if (_chartData.dineInCount > 0)
                                          PieChartSectionData(
                                            value: _chartData.dineInCount
                                                .toDouble(),
                                            color: AppColors.warning,
                                            title: '${_chartData.dineInCount}',
                                            titleStyle: GoogleFonts.dmMono(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                            radius: 52,
                                          ),
                                        if (_chartData.deliveryCount > 0)
                                          PieChartSectionData(
                                            value: _chartData.deliveryCount
                                                .toDouble(),
                                            color: AppColors.info,
                                            title:
                                                '${_chartData.deliveryCount}',
                                            titleStyle: GoogleFonts.dmMono(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                            radius: 52,
                                          ),
                                      ],
                                      legend: const [
                                        _LegendItem(
                                            color: AppColors.warning,
                                            label: 'Dine-In'),
                                        _LegendItem(
                                            color: AppColors.info,
                                            label: 'Delivery'),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _PieCard(
                                      title: 'Payment',
                                      sections: [
                                        if (_chartData.paidCount > 0)
                                          PieChartSectionData(
                                            value:
                                                _chartData.paidCount.toDouble(),
                                            color: AppColors.success,
                                            title: '${_chartData.paidCount}',
                                            titleStyle: GoogleFonts.dmMono(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                            radius: 52,
                                          ),
                                        if (_chartData.pendingCount > 0)
                                          PieChartSectionData(
                                            value: _chartData.pendingCount
                                                .toDouble(),
                                            color: AppColors.warning,
                                            title: '${_chartData.pendingCount}',
                                            titleStyle: GoogleFonts.dmMono(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                            radius: 52,
                                          ),
                                        if (_chartData.failedCount > 0)
                                          PieChartSectionData(
                                            value: _chartData.failedCount
                                                .toDouble(),
                                            color: AppColors.error,
                                            title: '${_chartData.failedCount}',
                                            titleStyle: GoogleFonts.dmMono(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                            radius: 52,
                                          ),
                                      ],
                                      legend: const [
                                        _LegendItem(
                                            color: AppColors.success,
                                            label: 'Paid'),
                                        _LegendItem(
                                            color: AppColors.warning,
                                            label: 'Pending'),
                                        _LegendItem(
                                            color: AppColors.error,
                                            label: 'Failed'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              // Status distribution
                              if (_chartData.statusCounts.isNotEmpty)
                                _StatusDistributionCard(
                                  counts: _chartData.statusCounts,
                                ),

                              const SizedBox(height: 12),

                              // Ogive chart
                              if (_chartData.ogiveSpots.length > 2)
                                _OgiveCard(
                                  spots: _chartData.ogiveSpots,
                                  bucketLabels: _chartData.ogiveBucketLabels,
                                ),

                              const SizedBox(height: 12),

                              // Top items
                              if (_analyticsData != null &&
                                  _analyticsData!.topSellingItems.isNotEmpty)
                                _TopItemsCard(
                                    items: _analyticsData!.topSellingItems),

                              const SizedBox(height: 12),

                              // Complaints summary
                              if (_analyticsData != null)
                                _ComplaintsCard(
                                    complaints: _analyticsData!.complaints),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Time range selector
// ─────────────────────────────────────────────────────────────────────────────

class _TimeRangeSelector extends StatelessWidget {
  const _TimeRangeSelector({
    required this.selected,
    required this.onChanged,
  });

  final TimeRange selected;
  final ValueChanged<TimeRange> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Row(
          children: TimeRange.values.map((r) {
            final isSelected = r == selected;
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(r),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  child: Text(
                    r.label,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmMono(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary KPI row
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.data});
  final AnalyticsData data;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Row(
            children: [
              _KpiCard(
                label: 'Revenue',
                value: '₹${_compact(data.summary.totalRevenue)}',
                icon: Icons.currency_rupee_rounded,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              _KpiCard(
                label: 'Orders',
                value: data.summary.totalOrders.toString(),
                icon: Icons.receipt_long_rounded,
                color: AppColors.info,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _KpiCard(
                label: 'Avg Order',
                value: '₹${data.summary.averageOrderValue.toStringAsFixed(0)}',
                icon: Icons.trending_up_rounded,
                color: AppColors.success,
              ),
              const SizedBox(width: 8),
              _KpiCard(
                label: 'Cancelled',
                value: data.summary.cancelledOrders.toString(),
                icon: Icons.cancel_outlined,
                color: AppColors.error,
              ),
            ],
          ),
        ],
      );

  static String _compact(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: GoogleFonts.syne(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    label,
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Revenue trend — LineChart with gradient fill + touch tooltip
// ─────────────────────────────────────────────────────────────────────────────

class _RevenueTrendCard extends StatelessWidget {
  const _RevenueTrendCard({
    required this.spots,
    required this.labels,
    required this.isHourly,
    required this.range,
  });

  final List<FlSpot> spots;
  final List<String> labels;
  final bool isHourly;
  final TimeRange range;

  double get _maxY {
    final m = spots.map((s) => s.y).reduce(math.max);
    return m == 0 ? 100 : m * 1.25;
  }

  @override
  Widget build(BuildContext context) => _ChartCard(
        title: 'Revenue Trend',
        subtitle: isHourly ? 'By hour (IST)' : 'By day (IST)',
        child: SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: spots.last.x,
              minY: 0,
              maxY: _maxY,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => const FlLine(
                  color: AppColors.border,
                  strokeWidth: 1,
                  dashArray: [4, 4],
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 48,
                    interval: _maxY / 4,
                    getTitlesWidget: (v, _) => Text(
                      '₹${_compactNum(v)}',
                      style: GoogleFonts.dmMono(
                        fontSize: 9,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    interval: _xInterval,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= labels.length) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          labels[i],
                          style: GoogleFonts.dmMono(
                            fontSize: 8,
                            color: AppColors.textMuted,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.3,
                  color: AppColors.primary,
                  barWidth: 2.5,
                  dotData: FlDotData(
                    show: spots.length <= 10,
                    getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                      radius: 3,
                      color: AppColors.primary,
                      strokeColor: AppColors.background,
                      strokeWidth: 1.5,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.25),
                        AppColors.primary.withValues(alpha: 0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => AppColors.surfaceHigh,
                  tooltipRoundedRadius: 8,
                  getTooltipItems: (spots) => spots.map((s) {
                    final i = s.spotIndex;
                    final label = i < labels.length ? labels[i] : '';
                    return LineTooltipItem(
                      '$label\n₹${s.y.toStringAsFixed(0)}',
                      GoogleFonts.dmMono(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      );

  double get _xInterval {
    if (spots.length <= 8) return 1;
    if (spots.length <= 16) return 2;
    return (spots.length / 6).ceilToDouble();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Orders volume — grouped BarChart (dine-in vs delivery)
// ─────────────────────────────────────────────────────────────────────────────

class _OrdersVolumeCard extends StatelessWidget {
  const _OrdersVolumeCard({
    required this.totalSpots,
    required this.dineInSpots,
    required this.deliverySpots,
    required this.labels,
    required this.isHourly,
  });

  final List<FlSpot> totalSpots;
  final List<FlSpot> dineInSpots;
  final List<FlSpot> deliverySpots;
  final List<String> labels;
  final bool isHourly;

  List<BarChartGroupData> get _groups => List.generate(
        totalSpots.length,
        (i) => BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: dineInSpots[i].y,
              color: AppColors.warning.withValues(alpha: 0.85),
              width: isHourly ? 5 : 8,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(3)),
            ),
            BarChartRodData(
              toY: deliverySpots[i].y,
              color: AppColors.info.withValues(alpha: 0.85),
              width: isHourly ? 5 : 8,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(3)),
            ),
          ],
          barsSpace: 2,
        ),
      );

  double get _maxY {
    final m = totalSpots.map((s) => s.y).reduce(math.max);
    return m == 0 ? 5 : m * 1.3;
  }

  @override
  Widget build(BuildContext context) => _ChartCard(
        title: 'Orders Volume',
        subtitle: 'Orange = Dine-In · Blue = Delivery',
        child: SizedBox(
          height: 180,
          child: BarChart(
            BarChartData(
              maxY: _maxY,
              barGroups: _groups,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => const FlLine(
                  color: AppColors.border,
                  strokeWidth: 1,
                  dashArray: [4, 4],
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: math.max(1, (_maxY / 4).ceilToDouble()),
                    getTitlesWidget: (v, _) => Text(
                      v.toInt().toString(),
                      style: GoogleFonts.dmMono(
                          fontSize: 9, color: AppColors.textMuted),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 20,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (labels.isEmpty || i < 0 || i >= labels.length) {
                        return const SizedBox();
                      }
                      final interval = isHourly ? 4 : 1;
                      if (i % interval != 0) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          labels[i],
                          style: GoogleFonts.dmMono(
                              fontSize: 8, color: AppColors.textMuted),
                        ),
                      );
                    },
                  ),
                ),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => AppColors.surfaceHigh,
                  tooltipRoundedRadius: 8,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final label =
                        groupIndex < labels.length ? labels[groupIndex] : '';
                    final type = rodIndex == 0 ? 'Dine-In' : 'Delivery';
                    return BarTooltipItem(
                      '$label\n$type: ${rod.toY.toInt()}',
                      GoogleFonts.dmMono(
                        fontSize: 11,
                        color:
                            rodIndex == 0 ? AppColors.warning : AppColors.info,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Peak hours — BarChart with IST hour labels + color gradient
// ─────────────────────────────────────────────────────────────────────────────

class _PeakHoursCard extends StatelessWidget {
  const _PeakHoursCard({required this.hourlyData});
  final List<double> hourlyData;

  double get _maxY {
    if (hourlyData.isEmpty) return 5;
    final m = hourlyData.reduce(math.max);
    return m == 0 ? 5 : m * 1.3;
  }

  List<BarChartGroupData> get _groups => List.generate(24, (h) {
        final val = h < hourlyData.length ? hourlyData[h] : 0.0;
        final ratio = _maxY > 0 ? val / _maxY : 0.0;
        final color = Color.lerp(
          AppColors.primary.withValues(alpha: 0.25),
          AppColors.primary,
          ratio,
        )!;
        return BarChartGroupData(
          x: h,
          barRods: [
            BarChartRodData(
              toY: val,
              color: color,
              width: 10,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(3)),
            ),
          ],
        );
      });

  @override
  Widget build(BuildContext context) => _ChartCard(
        title: 'Peak Hours',
        subtitle: 'Order volume by IST hour',
        child: SizedBox(
          height: 160,
          child: BarChart(
            BarChartData(
              maxY: _maxY,
              barGroups: _groups,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => const FlLine(
                  color: AppColors.border,
                  strokeWidth: 1,
                  dashArray: [4, 4],
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    interval: math.max(1, (_maxY / 3).ceilToDouble()),
                    getTitlesWidget: (v, _) => Text(
                      v.toInt().toString(),
                      style: GoogleFonts.dmMono(
                          fontSize: 9, color: AppColors.textMuted),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 18,
                    interval: 3,
                    getTitlesWidget: (v, _) {
                      final h = v.toInt();
                      if (h % 3 != 0) return const SizedBox();
                      final label = h == 0
                          ? '12AM'
                          : h < 12
                              ? '${h}AM'
                              : h == 12
                                  ? '12PM'
                                  : '${h - 12}PM';
                      return Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          label,
                          style: GoogleFonts.dmMono(
                              fontSize: 8, color: AppColors.textMuted),
                        ),
                      );
                    },
                  ),
                ),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => AppColors.surfaceHigh,
                  tooltipRoundedRadius: 8,
                  getTooltipItem: (group, _, rod, __) {
                    final h = group.x;
                    final label = h == 0
                        ? '12 AM'
                        : h < 12
                            ? '$h AM'
                            : h == 12
                                ? '12 PM'
                                : '${h - 12} PM';
                    return BarTooltipItem(
                      '$label (IST)\n${rod.toY.toInt()} orders',
                      GoogleFonts.dmMono(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Pie chart card
// ─────────────────────────────────────────────────────────────────────────────

class _PieCard extends StatefulWidget {
  const _PieCard({
    required this.title,
    required this.sections,
    required this.legend,
  });

  final String title;
  final List<PieChartSectionData> sections;
  final List<_LegendItem> legend;

  @override
  State<_PieCard> createState() => _PieCardState();
}

class _PieCardState extends State<_PieCard> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) => _ChartCard(
        title: widget.title,
        child: Column(
          children: [
            SizedBox(
              height: 140,
              child: widget.sections.isEmpty
                  ? Center(
                      child: Text(
                        'No data',
                        style: GoogleFonts.dmSans(
                            fontSize: 12, color: AppColors.textMuted),
                      ),
                    )
                  : PieChart(
                      PieChartData(
                        sections: widget.sections
                            .asMap()
                            .entries
                            .map(
                              (e) => PieChartSectionData(
                                value: e.value.value,
                                color: e.value.color,
                                title: e.value.title,
                                titleStyle: e.value.titleStyle,
                                radius: _touchedIndex == e.key
                                    ? 60
                                    : e.value.radius,
                              ),
                            )
                            .toList(),
                        pieTouchData: PieTouchData(
                          touchCallback:
                              (FlTouchEvent event, pieTouchResponse) {
                            setState(() {
                              if (!event.isInterestedForInteractions ||
                                  pieTouchResponse == null ||
                                  pieTouchResponse.touchedSection == null) {
                                _touchedIndex = -1;
                                return;
                              }
                              _touchedIndex = pieTouchResponse
                                  .touchedSection!.touchedSectionIndex;
                            });
                          },
                        ),
                        centerSpaceRadius: 30,
                        sectionsSpace: 2,
                      ),
                    ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: widget.legend,
            ),
          ],
        ),
      );
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 10,
              color: AppColors.textMuted,
            ),
          ),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Status distribution — horizontal progress bars
// ─────────────────────────────────────────────────────────────────────────────

class _StatusDistributionCard extends StatelessWidget {
  const _StatusDistributionCard({required this.counts});
  final Map<String, int> counts;

  static const _statusOrder = [
    'pending',
    'confirmed',
    'preparing',
    'ready',
    'out_for_delivery',
    'delivered',
    'cancelled',
  ];

  static Color _color(String s) => switch (s) {
        'pending' => AppColors.warning,
        'confirmed' => AppColors.info,
        'preparing' => AppColors.primary,
        'ready' => AppColors.success,
        'out_for_delivery' => AppColors.info,
        'delivered' => AppColors.success,
        'cancelled' => AppColors.error,
        _ => AppColors.textMuted,
      };

  @override
  Widget build(BuildContext context) {
    final total = counts.values.fold(0, (a, b) => a + b);
    final ordered = _statusOrder
        .where(counts.containsKey)
        .map((s) => MapEntry(s, counts[s]!))
        .toList();

    return _ChartCard(
      title: 'Order Status Distribution',
      child: Column(
        children: ordered.map((entry) {
          final pct = total > 0 ? entry.value / total : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 90,
                  child: Text(
                    entry.key.replaceAll('_', ' '),
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: AppColors.border,
                      valueColor: AlwaysStoppedAnimation(_color(entry.key)),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 28,
                  child: Text(
                    '${entry.value}',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.dmMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _color(entry.key),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ogive — cumulative distribution of order values
// ─────────────────────────────────────────────────────────────────────────────

class _OgiveCard extends StatelessWidget {
  const _OgiveCard({
    required this.spots,
    required this.bucketLabels,
  });

  final List<FlSpot> spots;
  final List<String> bucketLabels;

  @override
  Widget build(BuildContext context) => _ChartCard(
        title: 'Order Value Distribution',
        subtitle: 'Cumulative % of orders by amount',
        child: SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: spots.last.x,
              minY: 0,
              maxY: 105,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (v) {
                  if (v == 25 || v == 50 || v == 75 || v == 100) {
                    return const FlLine(
                      color: AppColors.border,
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    );
                  }
                  return const FlLine(
                      color: Colors.transparent, strokeWidth: 0);
                },
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    interval: 25,
                    getTitlesWidget: (v, _) => Text(
                      '${v.toInt()}%',
                      style: GoogleFonts.dmMono(
                          fontSize: 9, color: AppColors.textMuted),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= bucketLabels.length) {
                        return const SizedBox();
                      }
                      if (spots.length > 6 && i % 2 != 0) {
                        return const SizedBox();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          bucketLabels[i],
                          style: GoogleFonts.dmMono(
                              fontSize: 8, color: AppColors.textMuted),
                        ),
                      );
                    },
                  ),
                ),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.4,
                  color: AppColors.success,
                  barWidth: 2.5,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        AppColors.success.withValues(alpha: 0.2),
                        AppColors.success.withValues(alpha: 0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                // Reference lines at 25%, 50%, 75%
                LineChartBarData(
                  spots: [
                    const FlSpot(0, 50),
                    FlSpot(spots.last.x, 50),
                  ],
                  isCurved: false,
                  color: AppColors.textDisabled,
                  barWidth: 1,
                  dashArray: [4, 4],
                  dotData: const FlDotData(show: false),
                ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => AppColors.surfaceHigh,
                  tooltipRoundedRadius: 8,
                  getTooltipItems: (spots) => spots.map((s) {
                    if (s.barIndex == 1) return null; // skip reference line
                    final i = s.spotIndex;
                    final label =
                        i < bucketLabels.length ? bucketLabels[i] : '';
                    return LineTooltipItem(
                      '$label\n${s.y.toStringAsFixed(1)}% of orders',
                      GoogleFonts.dmMono(
                        fontSize: 11,
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Top items — horizontal bar chart with custom painting
// ─────────────────────────────────────────────────────────────────────────────

class _TopItemsCard extends StatelessWidget {
  const _TopItemsCard({required this.items});
  final List<TopItem> items;

  @override
  Widget build(BuildContext context) {
    final topN = items.take(10).toList();
    final maxQty = topN.map((i) => i.totalQuantitySold).reduce(math.max);

    return _ChartCard(
      title: 'Top Selling Items',
      subtitle: 'By quantity sold',
      child: Column(
        children: topN.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          final ratio = maxQty > 0 ? item.totalQuantitySold / maxQty : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  child: Text(
                    '${i + 1}',
                    style: GoogleFonts.dmMono(
                      fontSize: 10,
                      color: i < 3 ? AppColors.primary : AppColors.textMuted,
                      fontWeight: i < 3 ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 3,
                  child: Text(
                    item.itemName,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: Stack(
                    children: [
                      Container(
                        height: 16,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: ratio.clamp(0.0, 1.0),
                        child: Container(
                          height: 16,
                          decoration: BoxDecoration(
                            color: i < 3
                                ? AppColors.primary
                                : AppColors.primary.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 28,
                  child: Text(
                    '×${item.totalQuantitySold}',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.dmMono(
                      fontSize: 10,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 44,
                  child: Text(
                    '₹${_compact(item.totalRevenue)}',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.dmMono(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  static String _compact(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Complaints summary
// ─────────────────────────────────────────────────────────────────────────────

class _ComplaintsCard extends StatelessWidget {
  const _ComplaintsCard({required this.complaints});
  final ComplaintsSummary complaints;

  static Color _priorityColor(String p) => switch (p) {
        'critical' => AppColors.error,
        'high' => AppColors.warning,
        'medium' => AppColors.info,
        _ => AppColors.textMuted,
      };

  @override
  Widget build(BuildContext context) {
    final total = complaints.total;

    return _ChartCard(
      title: 'Complaints',
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '$total',
                style: GoogleFonts.syne(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: total == 0 ? AppColors.success : AppColors.error,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'total complaints',
                style: GoogleFonts.dmSans(
                    fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
          if (complaints.byPriority.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...['critical', 'high', 'medium', 'low']
                .where(complaints.byPriority.containsKey)
                .map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _priorityColor(p),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          p.substring(0, 1).toUpperCase() + p.substring(1),
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${complaints.byPriority[p]}',
                          style: GoogleFonts.dmMono(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _priorityColor(p),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared chart card container
// ─────────────────────────────────────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: GoogleFonts.dmMono(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
                letterSpacing: 1.2,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: AppColors.textDisabled,
                ),
              ),
            ],
            const SizedBox(height: 14),
            child,
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Utility widgets
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingBanner extends StatelessWidget {
  const _LoadingBanner();

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primaryTint,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Refreshing analytics…',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bar_chart_outlined,
                  size: 48, color: AppColors.textDisabled),
              const SizedBox(height: 12),
              Text(
                'Could not load analytics',
                style: GoogleFonts.syne(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                style: GoogleFonts.dmSans(
                    fontSize: 12, color: AppColors.textDisabled),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.primary,
                  elevation: 0,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

String _compactNum(double v) {
  if (v >= 100000) return '${(v / 100000).toStringAsFixed(0)}L';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
  return v.toStringAsFixed(0);
}
