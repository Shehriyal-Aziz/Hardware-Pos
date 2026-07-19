import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/database_helper.dart';
import '../providers/product_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _printerIpController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final ip = await DatabaseHelper.instance.getSetting('printer_ip');
    final pass = await DatabaseHelper.instance.getSetting('inventory_password');
    _printerIpController.text = ip ?? '';
    _passwordController.text = pass ?? '';
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    await DatabaseHelper.instance.updateSetting(
      'printer_ip',
      _printerIpController.text.trim(),
    );
    await DatabaseHelper.instance.updateSetting(
      'inventory_password',
      _passwordController.text.trim(),
    );
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Settings saved')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Thermal Printer IP Address',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _printerIpController,
              decoration: const InputDecoration(
                hintText: 'e.g. 192.168.1.50',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () async {
                await DatabaseHelper.instance.seedDummyProducts();
                await ref.read(productProvider.notifier).loadProducts();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('100 dummy products added')),
                  );
                }
              },
              child: const Text('Seed 100 Dummy Products (dev only)'),
            ),
            const SizedBox(height: 24),
            const Text(
              'Inventory Password',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _save,
              child: const Text('Save Settings'),
            ),
          ],
        ),
      ),
    );
  }
}
