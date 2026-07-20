import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/customer.dart';
import 'customer_detail_screen.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  List<Customer> _customers = [];
  Map<String, double> _balances = {};
  bool _loading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final maps = await DatabaseHelper.instance.getAllCustomers();
    final balances = await DatabaseHelper.instance.getAllCustomerBalances();
    final customers = maps.map((m) => Customer.fromMap(m)).toList();

    // People who owe the most float to the top — that's who the owner
    // actually needs to see first.
    customers.sort((a, b) {
      final balA = balances[a.id] ?? 0;
      final balB = balances[b.id] ?? 0;
      return balB.compareTo(balA);
    });

    if (!mounted) return;
    setState(() {
      _customers = customers;
      _balances = balances;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _searchQuery.isEmpty
        ? _customers
        : _customers
            .where((c) =>
                c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                (c.phone ?? '').contains(_searchQuery))
            .toList();

    final totalOwed = _balances.values.fold(0.0, (sum, b) => sum + b);

    return Scaffold(
      appBar: AppBar(title: const Text('Customers (Udhar)')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Colors.red[50],
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Outstanding Udhar',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Rs ${totalOwed.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.red[700],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search customer...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('No customers yet'))
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final customer = filtered[index];
                              final balance = _balances[customer.id] ?? 0;
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: balance > 0
                                      ? Colors.red[100]
                                      : Colors.green[100],
                                  child: Icon(
                                    Icons.person,
                                    color: balance > 0
                                        ? Colors.red[700]
                                        : Colors.green[700],
                                  ),
                                ),
                                title: Text(customer.name),
                                subtitle: customer.phone != null
                                    ? Text(customer.phone!)
                                    : null,
                                trailing: Text(
                                  balance > 0
                                      ? 'Rs ${balance.toStringAsFixed(0)}'
                                      : 'Clear',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: balance > 0
                                        ? Colors.red[700]
                                        : Colors.green[700],
                                  ),
                                ),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          CustomerDetailScreen(
                                              customer: customer),
                                    ),
                                  );
                                  // Balance may have changed (payment
                                  // recorded) while on the detail screen.
                                  _load();
                                },
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}
