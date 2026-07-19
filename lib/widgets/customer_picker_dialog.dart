import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/customer.dart';

/// Shown at checkout when the cashier picks "Udhar" as payment type.
/// Returns the selected/created Customer, or null if cancelled.
class CustomerPickerDialog extends StatefulWidget {
  const CustomerPickerDialog({super.key});

  @override
  State<CustomerPickerDialog> createState() => _CustomerPickerDialogState();
}

class _CustomerPickerDialogState extends State<CustomerPickerDialog> {
  List<Customer> _customers = [];
  List<Customer> _filtered = [];
  bool _loading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final maps = await DatabaseHelper.instance.getAllCustomers();
    final customers = maps.map((m) => Customer.fromMap(m)).toList();
    setState(() {
      _customers = customers;
      _filtered = customers;
      _loading = false;
    });
  }

  void _filter(String query) {
    setState(() {
      _filtered = query.isEmpty
          ? _customers
          : _customers
              .where((c) =>
                  c.name.toLowerCase().contains(query.toLowerCase()) ||
                  (c.phone ?? '').contains(query))
              .toList();
    });
  }

  Future<void> _addNewCustomer() async {
    final nameController = TextEditingController(text: _searchController.text);
    final phoneController = TextEditingController();

    final result = await showDialog<Customer>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Customer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration:
                  const InputDecoration(labelText: 'Phone (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              final phone = phoneController.text.trim();
              final customer = Customer(
                name: name,
                phone: phone.isEmpty ? null : phone,
              );
              final id = await DatabaseHelper.instance
                  .insertCustomer(customer.toMap());
              if (context.mounted) {
                Navigator.pop(
                  context,
                  Customer(
                    id: id,
                    name: customer.name,
                    phone: customer.phone,
                    createdAt: customer.createdAt,
                  ),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Customer (Udhar)'),
      content: SizedBox(
        width: 360,
        height: 420,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search customer by name or phone',
                border: OutlineInputBorder(),
              ),
              onChanged: _filter,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('No matching customer'),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: _addNewCustomer,
                                icon: const Icon(Icons.person_add),
                                label: const Text('Add New Customer'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filtered.length,
                          itemBuilder: (context, index) {
                            final c = _filtered[index];
                            return ListTile(
                              leading: const Icon(Icons.person_outline),
                              title: Text(c.name),
                              subtitle:
                                  c.phone != null ? Text(c.phone!) : null,
                              onTap: () => Navigator.pop(context, c),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (!_loading && _filtered.isNotEmpty)
          TextButton.icon(
            onPressed: _addNewCustomer,
            icon: const Icon(Icons.person_add, size: 18),
            label: const Text('New Customer'),
          ),
      ],
    );
  }
}
