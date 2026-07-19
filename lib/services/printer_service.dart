import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import '../models/cart_item.dart';

class PrinterService {
  static Future<PosPrintResult> printReceipt({
    required String printerIp,
    required List<CartItem> items,
    required double total,
    String storeName = 'Hardware Store',
  }) async {
    final profile = await CapabilityProfile.load();
    final printer = NetworkPrinter(PaperSize.mm58, profile);

    final PosPrintResult connectResult =
        await printer.connect(printerIp, port: 9100);

    if (connectResult != PosPrintResult.success) {
      return connectResult;
    }

    printer.text(
      storeName,
      styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
    );
    printer.text(
      DateTime.now().toString().substring(0, 16),
      styles: const PosStyles(align: PosAlign.center),
    );
    printer.hr();

    for (final item in items) {
      printer.text('${item.product.name} x${item.quantity}');
      printer.row([
        PosColumn(text: '', width: 8),
        PosColumn(
          text: 'Rs ${item.lineTotal.toStringAsFixed(0)}',
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    printer.hr();
    printer.row([
      PosColumn(text: 'TOTAL', width: 6, styles: const PosStyles(bold: true, height: PosTextSize.size2)),
      PosColumn(
        text: 'Rs ${total.toStringAsFixed(0)}',
        width: 6,
        styles: const PosStyles(align: PosAlign.right, bold: true, height: PosTextSize.size2),
      ),
    ]);

    printer.hr();
    printer.text(
      'Thank you for your purchase!',
      styles: const PosStyles(align: PosAlign.center),
    );
    printer.feed(2);
    printer.cut();

    printer.disconnect();
    return PosPrintResult.success;
  }
}