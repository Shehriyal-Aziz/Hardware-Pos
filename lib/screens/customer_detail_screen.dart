import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/customer.dart';
import '../services/export_service.dart';

class CustomerDetailScreen extends StatefulWidget {
  final Customer customer;
  const CustomerDetailScreen({super.key, required this.customer});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  double _balance = 0;
  List<Map<String, dynamic>> _ledger = [];
  // saleId -> its line items, loaded lazily when a sale entry is expanded.
  final Map<String, List<Map<String, dynamic>>> _saleItemsCache = {};
  bool _loading = true;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final balance =
        await DatabaseHelper.instance.getCustomerBalance(widget.customer.id!);
    final ledger =
        await DatabaseHelper.instance.getCustomerLedger(widget.customer.id!);
    if (!mounted) return;
    setState(() {
      _balance = balance;
      _ledger = ledger;
      _loading = false;
    });
  }

  Future<List<Map<String, dynamic>>> _loadSaleItems(String saleId) async {
    if (_saleItemsCache.containsKey(saleId)) {
      return _saleItemsCache[saleId]!;
    }
    final db = await DatabaseHelper.instance.database;
    final items = await db.query(
      'sale_items',
      where: 'saleid = ?',
      whereArgs: [saleId],
    );
    _saleItemsCache[saleId] = items;
    return items;
  }

  /// Export needs every sale's items up front (not just whichever the user
  /// has expanded), so this fills the cache for every sale entry first.
  Future<void> _preloadAllSaleItems() async {
    for (final entry in _ledger) {
      if (entry['type'] == 'sale') {
        await _loadSaleItems(entry['id'] as String);
      }
    }
  }

  Future<void> _export(Future<void> Function() exportFn) async {
    setState(() => _exporting = true);
    try {
      await _preloadAllSaleItems();
      await exportFn();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _recordPayment() async {
    final amountController = TextEditingController();
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Record Payment - ${widget.customer.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Current balance: Rs ${_balance.toStringAsFixed(0)}',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount Received',
                prefixText: 'Rs ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text);
              if (amount != null && amount > 0) {
                Navigator.pop(context, amount);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      // NOTE: map keys are lowercase to match the Supabase/PowerSync schema.
      await DatabaseHelper.instance.insertUdharPayment({
        'customerid': widget.customer.id,
        'amount': result,
        'createdat': DateTime.now().toIso8601String(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment of Rs ${result.toStringAsFixed(0)} recorded')),
        );
      }
      _load();
    }
  }

  String _formatDate(String iso) {
    final dt = DateTime.parse(iso);
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.customer.name),
        actions: [
          if (_exporting)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (!_loading && _ledger.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Export Statement',
              onSelected: (value) {
                if (value == 'pdf') {
                  _export(() => ExportService.exportLedgerPdf(
                        customerName: widget.customer.name,
                        customerPhone: widget.customer.phone,
                        balance: _balance,
                        ledger: _ledger,
                        saleItemsBySaleId: _saleItemsCache,
                      ));
                } else {
                  _export(() => ExportService.exportLedgerExcel(
                        customerName: widget.customer.name,
                        customerPhone: widget.customer.phone,
                        balance: _balance,
                        ledger: _ledger,
                        saleItemsBySaleId: _saleItemsCache,
                      ));
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'pdf', child: Text('Export as PDF')),
                PopupMenuItem(value: 'excel', child: Text('Export as Excel')),
              ],
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  color: _balance > 0 ? Colors.red[50] : Colors.green[50],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _balance > 0 ? 'Outstanding Balance' : 'All Clear',
                        style: const TextStyle(
                            fontSize: 13, color: Colors.black54),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Rs ${_balance.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: _balance > 0
                              ? Colors.red[700]
                              : Colors.green[700],
                        ),
                      ),
                      if (widget.customer.phone != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.customer.phone!,
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _recordPayment,
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Record Payment'),
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'History',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: _ledger.isEmpty
                      ? const Center(child: Text('No udhar history yet'))
                      : ListView.builder(
                          itemCount: _ledger.length,
                          itemBuilder: (context, index) {
                            final entry = _ledger[index];
                            final isSale = entry['type'] == 'sale';
                            final amount = (entry['amount'] as num).toDouble();

                            if (!isSale) {
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.green[100],
                                  child: Icon(Icons.arrow_downward,
                                      color: Colors.green[700], size: 18),
                                ),
                                title: const Text('Payment received'),
                                subtitle:
                                    Text(_formatDate(entry['createdAt'])),
                                trailing: Text(
                                  '- Rs ${amount.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[700],
                                  ),
                                ),
                              );
                            }

                            return ExpansionTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.red[100],
                                child: Icon(Icons.arrow_upward,
                                    color: Colors.red[700], size: 18),
                              ),
                              title: const Text('Udhar sale'),
                              subtitle: Text(_formatDate(entry['createdAt'])),
                              trailing: Text(
                                '+ Rs ${amount.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red[700],
                                ),
                              ),
                              children: [
                                FutureBuilder<List<Map<String, dynamic>>>(
                                  future: _loadSaleItems(entry['id'] as String),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData) {
                                      return const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: LinearProgressIndicator(),
                                      );
                                    }
                                    final items = snapshot.data!;
                                    return Column(
                                      children: items.map((item) {
                                        final qty = item['quantity'] as int;
                                        final price =
                                            (item['priceatsale'] as num)
                                                .toDouble();
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 20, vertical: 4),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment
                                                    .spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  '${item['productname']} x$qty',
                                                  style: const TextStyle(
                                                      fontSize: 13),
                                                ),
                                              ),
                                              Text(
                                                'Rs ${(price * qty).toStringAsFixed(0)}',
                                                style: const TextStyle(
                                                    fontSize: 13),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    );
                                  },
                                ),
                                const SizedBox(height: 8),
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
