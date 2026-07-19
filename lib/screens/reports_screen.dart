import 'package:flutter/material.dart';
import '../db/database_helper.dart';

enum ReportRange { today, thisWeek, thisMonth, custom }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  ReportRange _range = ReportRange.today;
  DateTime _customStart = DateTime.now();
  DateTime _customEnd = DateTime.now();

  Map<String, double>? _summary;
  List<Map<String, dynamic>> _topProducts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  (DateTime, DateTime) _resolveRange() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    switch (_range) {
      case ReportRange.today:
        return (todayStart, todayStart.add(const Duration(days: 1)));
      case ReportRange.thisWeek:
        // Week starts Monday.
        final startOfWeek =
            todayStart.subtract(Duration(days: todayStart.weekday - 1));
        return (startOfWeek, todayStart.add(const Duration(days: 1)));
      case ReportRange.thisMonth:
        final startOfMonth = DateTime(now.year, now.month, 1);
        return (startOfMonth, todayStart.add(const Duration(days: 1)));
      case ReportRange.custom:
        return (
          DateTime(_customStart.year, _customStart.month, _customStart.day),
          DateTime(_customEnd.year, _customEnd.month, _customEnd.day)
              .add(const Duration(days: 1)),
        );
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final (start, end) = _resolveRange();
    final summary = await DatabaseHelper.instance.getSalesSummary(start, end);
    final topProducts =
        await DatabaseHelper.instance.getTopProducts(start, end, limit: 10);
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _topProducts = topProducts;
      _loading = false;
    });
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _customStart, end: _customEnd),
    );
    if (picked != null) {
      setState(() {
        _customStart = picked.start;
        _customEnd = picked.end;
        _range = ReportRange.custom;
      });
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary ??
        {
          'cashTotal': 0,
          'cashCount': 0,
          'udharTotal': 0,
          'udharCount': 0,
          'udharPaymentsReceived': 0,
        };

    final cashTotal = summary['cashTotal']!;
    final udharTotal = summary['udharTotal']!;
    final udharPayments = summary['udharPaymentsReceived']!;
    final grandTotal = cashTotal + udharTotal;
    final transactionCount =
        summary['cashCount']!.toInt() + summary['udharCount']!.toInt();

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Today'),
                  selected: _range == ReportRange.today,
                  onSelected: (_) {
                    setState(() => _range = ReportRange.today);
                    _load();
                  },
                ),
                ChoiceChip(
                  label: const Text('This Week'),
                  selected: _range == ReportRange.thisWeek,
                  onSelected: (_) {
                    setState(() => _range = ReportRange.thisWeek);
                    _load();
                  },
                ),
                ChoiceChip(
                  label: const Text('This Month'),
                  selected: _range == ReportRange.thisMonth,
                  onSelected: (_) {
                    setState(() => _range = ReportRange.thisMonth);
                    _load();
                  },
                ),
                ChoiceChip(
                  label: Text(
                    _range == ReportRange.custom
                        ? '${_customStart.day}/${_customStart.month} - ${_customEnd.day}/${_customEnd.month}'
                        : 'Custom Range',
                  ),
                  selected: _range == ReportRange.custom,
                  onSelected: (_) => _pickCustomRange(),
                ),
              ],
            ),
          ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _SummaryCard(
                    label: 'Total Sales',
                    value: grandTotal,
                    subtitle: '$transactionCount transactions',
                    color: Colors.black87,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          label: 'Cash Sales',
                          value: cashTotal,
                          subtitle: '${summary['cashCount']!.toInt()} sales',
                          color: Colors.green[700]!,
                          compact: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          label: 'Udhar Sales',
                          value: udharTotal,
                          subtitle: '${summary['udharCount']!.toInt()} sales',
                          color: Colors.orange[800]!,
                          compact: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SummaryCard(
                    label: 'Udhar Payments Received',
                    value: udharPayments,
                    subtitle: 'Old debts collected in this period',
                    color: Colors.blue[700]!,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Top Products',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  if (_topProducts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('No sales in this period',
                          style: TextStyle(color: Colors.black54)),
                    )
                  else
                    Card(
                      child: Column(
                        children: _topProducts.asMap().entries.map((entry) {
                          final rank = entry.key + 1;
                          final p = entry.value;
                          final qty = (p['totalQty'] as num).toInt();
                          final revenue =
                              (p['totalRevenue'] as num).toDouble();
                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 14,
                              backgroundColor: Colors.grey[200],
                              child: Text(
                                '$rank',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            title: Text(p['name'] as String),
                            subtitle: Text('$qty sold'),
                            trailing: Text(
                              'Rs ${revenue.toStringAsFixed(0)}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          );
                        }).toList(),
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

class _SummaryCard extends StatelessWidget {
  final String label;
  final double value;
  final String subtitle;
  final Color color;
  final bool compact;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
                fontSize: compact ? 12 : 13, color: Colors.black54),
          ),
          const SizedBox(height: 6),
          Text(
            'Rs ${value.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: compact ? 20 : 26,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: Colors.black38),
          ),
        ],
      ),
    );
  }
}
