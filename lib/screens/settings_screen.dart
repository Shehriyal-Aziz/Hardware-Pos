import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/database_helper.dart';
import '../services/printer_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _printerIpController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = true;

  // Printer connection mode: network (IP) or windows (USB/Bluetooth via
  // whatever is installed/paired in Windows).
  PrinterMode _printerMode = PrinterMode.network;
  List<String> _windowsPrinters = [];
  String? _selectedWindowsPrinter;
  bool _loadingWindowsPrinters = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final ip = await DatabaseHelper.instance.getSetting('printer_ip');
    final pass = await DatabaseHelper.instance.getSetting('inventory_password');
    final mode = await DatabaseHelper.instance.getSetting('printer_mode');
    final winPrinter =
        await DatabaseHelper.instance.getSetting('windows_printer_name');
    _printerIpController.text = ip ?? '';
    _passwordController.text = pass ?? '';
    _printerMode =
        mode == 'windows' ? PrinterMode.windows : PrinterMode.network;
    _selectedWindowsPrinter =
        (winPrinter != null && winPrinter.isNotEmpty) ? winPrinter : null;
    setState(() => _loading = false);
    if (_printerMode == PrinterMode.windows) {
      _refreshWindowsPrinters();
    }
  }

  Future<void> _refreshWindowsPrinters() async {
    setState(() => _loadingWindowsPrinters = true);
    final printers = await PrinterService.getWindowsPrinters();
    if (!mounted) return;
    setState(() {
      _windowsPrinters = printers;
      _loadingWindowsPrinters = false;
      // Keep the saved selection if it's still available; otherwise fall
      // back to nothing selected rather than silently picking a wrong one.
      if (_selectedWindowsPrinter != null &&
          !printers.contains(_selectedWindowsPrinter)) {
        _selectedWindowsPrinter = null;
      }
    });
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
    await DatabaseHelper.instance.updateSetting(
      'printer_mode',
      _printerMode == PrinterMode.windows ? 'windows' : 'network',
    );
    await DatabaseHelper.instance.updateSetting(
      'windows_printer_name',
      _selectedWindowsPrinter ?? '',
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
              'Receipt Printer',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SegmentedButton<PrinterMode>(
              segments: const [
                ButtonSegment(
                  value: PrinterMode.network,
                  label: Text('Network (Wi-Fi/IP)'),
                  icon: Icon(Icons.wifi),
                ),
                ButtonSegment(
                  value: PrinterMode.windows,
                  label: Text('USB / Bluetooth'),
                  icon: Icon(Icons.usb),
                ),
              ],
              selected: {_printerMode},
              onSelectionChanged: (selected) {
                setState(() => _printerMode = selected.first);
                if (_printerMode == PrinterMode.windows &&
                    _windowsPrinters.isEmpty) {
                  _refreshWindowsPrinters();
                }
              },
            ),
            const SizedBox(height: 16),
            if (_printerMode == PrinterMode.network) ...[
              TextField(
                controller: _printerIpController,
                decoration: const InputDecoration(
                  labelText: 'Printer IP Address',
                  hintText: 'e.g. 192.168.1.50',
                  border: OutlineInputBorder(),
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _windowsPrinters.contains(_selectedWindowsPrinter)
                          ? _selectedWindowsPrinter
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Windows Printer',
                        border: OutlineInputBorder(),
                      ),
                      hint: Text(_loadingWindowsPrinters
                          ? 'Scanning...'
                          : (_windowsPrinters.isEmpty
                              ? 'No printers found'
                              : 'Select a printer')),
                      items: _windowsPrinters
                          .map((name) => DropdownMenuItem(
                                value: name,
                                child: Text(name, overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() => _selectedWindowsPrinter = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Rescan printers',
                    icon: _loadingWindowsPrinters
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    onPressed:
                        _loadingWindowsPrinters ? null : _refreshWindowsPrinters,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Pair or connect the printer in Windows first (Settings > '
                'Bluetooth & devices, or plug in via USB and install its '
                'driver), then tap refresh to see it here.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
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
