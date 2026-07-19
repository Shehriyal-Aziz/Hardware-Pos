import 'dart:typed_data';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:windows_printer/windows_printer.dart';
import '../models/cart_item.dart';

/// How the receipt printer is connected.
/// - network: existing IP/Wi-Fi printer, talked to directly over TCP (port 9100).
/// - windows: any printer already installed/paired in Windows (USB or
///   Bluetooth) — Windows' own driver/spooler handles the physical
///   connection, we just send it raw ESC/POS bytes.
enum PrinterMode { network, windows }

class PrinterService {
  /// Builds the ESC/POS byte stream for a receipt using esc_pos_utils.
  /// Shared by both network and Windows raw-print paths so the receipt
  /// layout stays identical regardless of connection type.
  static Future<List<int>> _buildReceiptBytes({
    required List<CartItem> items,
    required double total,
    required String storeName,
    required CapabilityProfile profile,
  }) async {
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    bytes += generator.text(
      storeName,
      styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
    );
    bytes += generator.text(
      DateTime.now().toString().substring(0, 16),
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.hr();

    for (final item in items) {
      bytes += generator.text('${item.product.name} x${item.quantity}');
      bytes += generator.row([
        PosColumn(text: '', width: 8),
        PosColumn(
          text: 'Rs ${item.lineTotal.toStringAsFixed(0)}',
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    bytes += generator.hr();
    bytes += generator.row([
      PosColumn(text: 'TOTAL', width: 6, styles: const PosStyles(bold: true, height: PosTextSize.size2)),
      PosColumn(
        text: 'Rs ${total.toStringAsFixed(0)}',
        width: 6,
        styles: const PosStyles(align: PosAlign.right, bold: true, height: PosTextSize.size2),
      ),
    ]);

    bytes += generator.hr();
    bytes += generator.text(
      'Thank you for your purchase!',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.feed(2);
    bytes += generator.cut();

    return bytes;
  }

  /// Network (IP) printer — unchanged from before, just refactored to
  /// share the receipt-building code above.
  static Future<PosPrintResult> _printNetwork({
    required String printerIp,
    required List<CartItem> items,
    required double total,
    required String storeName,
  }) async {
    final profile = await CapabilityProfile.load();
    final printer = NetworkPrinter(PaperSize.mm58, profile);

    final PosPrintResult connectResult =
        await printer.connect(printerIp, port: 9100);

    if (connectResult != PosPrintResult.success) {
      return connectResult;
    }

    final bytes = await _buildReceiptBytes(
      items: items,
      total: total,
      storeName: storeName,
      profile: profile,
    );
    printer.rawBytes(bytes);
    printer.disconnect();
    return PosPrintResult.success;
  }

  /// USB / Bluetooth printer, reached through the Windows print spooler.
  /// Works for any printer already installed & paired in Windows —
  /// Windows itself owns the USB/Bluetooth connection, we just send it
  /// raw ESC/POS bytes so it behaves like a real thermal printer, not a
  /// regular document printer.
  static Future<bool> _printWindows({
    required String printerName,
    required List<CartItem> items,
    required double total,
    required String storeName,
  }) async {
    final profile = await CapabilityProfile.load();
    final bytes = await _buildReceiptBytes(
      items: items,
      total: total,
      storeName: storeName,
      profile: profile,
    );
    return await WindowsPrinter.printRawData(
      printerName: printerName,
      data: Uint8List.fromList(bytes),
      useRawDatatype: true,
    );
  }

  /// Returns the list of printers Windows currently knows about
  /// (installed USB or paired Bluetooth printers show up here).
  static Future<List<String>> getWindowsPrinters() async {
    try {
      return await WindowsPrinter.getAvailablePrinters();
    } catch (_) {
      return [];
    }
  }

  /// Single entry point used by checkout. Reads which mode + target is
  /// configured and routes accordingly. Never throws — returns true/false
  /// so callers can show a "printed" / "failed" message, matching how the
  /// old network-only version behaved (fire-and-forget from checkout).
  static Future<bool> printReceiptAuto({
    required PrinterMode mode,
    required String target, // IP for network mode, printer name for windows mode
    required List<CartItem> items,
    required double total,
    String storeName = 'Hardware Store',
  }) async {
    try {
      if (mode == PrinterMode.network) {
        final result = await _printNetwork(
          printerIp: target,
          items: items,
          total: total,
          storeName: storeName,
        );
        return result == PosPrintResult.success;
      } else {
        return await _printWindows(
          printerName: target,
          items: items,
          total: total,
          storeName: storeName,
        );
      }
    } catch (_) {
      return false;
    }
  }

  /// Kept for backward compatibility with any existing callers.
  static Future<PosPrintResult> printReceipt({
    required String printerIp,
    required List<CartItem> items,
    required double total,
    String storeName = 'Hardware Store',
  }) {
    return _printNetwork(
      printerIp: printerIp,
      items: items,
      total: total,
      storeName: storeName,
    );
  }
}