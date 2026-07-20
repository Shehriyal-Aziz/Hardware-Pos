import 'dart:typed_data';
import 'package:excel/excel.dart' as xl;
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Builds and hands off PDF/Excel exports for the Reports screen and the
/// Customer (udhar) ledger. Kept as pure "build bytes, then send them
/// somewhere" functions so the UI layer stays simple.
class ExportService {
  // ---------- Sales Report ----------

  static Future<Uint8List> _buildReportPdf({
    required String rangeLabel,
    required Map<String, double> summary,
    required List<Map<String, dynamic>> topProducts,
    String storeName = 'Hardware Store',
  }) async {
    final doc = pw.Document();
    final cashTotal = summary['cashTotal'] ?? 0;
    final udharTotal = summary['udharTotal'] ?? 0;
    final udharPayments = summary['udharPaymentsReceived'] ?? 0;
    final grandTotal = cashTotal + udharTotal;
    final transactionCount =
        (summary['cashCount'] ?? 0).toInt() + (summary['udharCount'] ?? 0).toInt();

    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text(storeName,
              style:
                  pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.Text('Sales Report — $rangeLabel',
              style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
          pw.SizedBox(height: 16),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            columnWidths: const {
              0: pw.FlexColumnWidth(2),
              1: pw.FlexColumnWidth(1),
            },
            children: [
              _summaryRow('Total Sales', grandTotal),
              _summaryRow('  Cash Sales', cashTotal),
              _summaryRow('  Udhar Sales (credit given)', udharTotal),
              _summaryRow('Udhar Payments Received', udharPayments),
              _summaryRow('Transactions', transactionCount.toDouble(),
                  isCount: true),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Text('Top Products',
              style:
                  pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          if (topProducts.isEmpty)
            pw.Text('No sales in this period')
          else
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              columnWidths: const {
                0: pw.FlexColumnWidth(3),
                1: pw.FlexColumnWidth(1),
                2: pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _cell('Product', bold: true),
                    _cell('Qty', bold: true),
                    _cell('Revenue', bold: true),
                  ],
                ),
                for (final p in topProducts)
                  pw.TableRow(children: [
                    _cell(p['name'] as String),
                    _cell('${(p['totalQty'] as num).toInt()}'),
                    _cell(
                        'Rs ${(p['totalRevenue'] as num).toStringAsFixed(0)}'),
                  ]),
              ],
            ),
          pw.SizedBox(height: 24),
          pw.Text(
            'Generated ${DateTime.now().toString().substring(0, 16)}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
          ),
        ],
      ),
    );

    return doc.save();
  }

  static pw.TableRow _summaryRow(String label, double value,
      {bool isCount = false}) {
    return pw.TableRow(children: [
      _cell(label),
      _cell(isCount ? value.toInt().toString() : 'Rs ${value.toStringAsFixed(0)}'),
    ]);
  }

  static pw.Widget _cell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
            fontSize: 10,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
      ),
    );
  }

  static Future<void> exportReportPdf({
    required String rangeLabel,
    required Map<String, double> summary,
    required List<Map<String, dynamic>> topProducts,
  }) async {
    final bytes = await _buildReportPdf(
      rangeLabel: rangeLabel,
      summary: summary,
      topProducts: topProducts,
    );
    final safeLabel = rangeLabel.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_');
    await Printing.sharePdf(bytes: bytes, filename: 'Sales_Report_$safeLabel.pdf');
  }

  static Future<void> exportReportExcel({
    required String rangeLabel,
    required Map<String, double> summary,
    required List<Map<String, dynamic>> topProducts,
  }) async {
    final excel = xl.Excel.createExcel();
    final sheet = excel['Report'];
    excel.setDefaultSheet('Report');

    sheet.appendRow([xl.TextCellValue('Sales Report - $rangeLabel')]);
    sheet.appendRow([]);
    sheet.appendRow([
      xl.TextCellValue('Cash Sales'),
      xl.DoubleCellValue(summary['cashTotal'] ?? 0),
    ]);
    sheet.appendRow([
      xl.TextCellValue('Udhar Sales'),
      xl.DoubleCellValue(summary['udharTotal'] ?? 0),
    ]);
    sheet.appendRow([
      xl.TextCellValue('Udhar Payments Received'),
      xl.DoubleCellValue(summary['udharPaymentsReceived'] ?? 0),
    ]);
    sheet.appendRow([
      xl.TextCellValue('Total Sales'),
      xl.DoubleCellValue(
          (summary['cashTotal'] ?? 0) + (summary['udharTotal'] ?? 0)),
    ]);
    sheet.appendRow([]);
    sheet.appendRow([xl.TextCellValue('Top Products')]);
    sheet.appendRow([
      xl.TextCellValue('Product'),
      xl.TextCellValue('Qty Sold'),
      xl.TextCellValue('Revenue'),
    ]);
    for (final p in topProducts) {
      sheet.appendRow([
        xl.TextCellValue(p['name'] as String),
        xl.IntCellValue((p['totalQty'] as num).toInt()),
        xl.DoubleCellValue((p['totalRevenue'] as num).toDouble()),
      ]);
    }

    final bytes = excel.save();
    if (bytes == null) return;

    final safeLabel = rangeLabel.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_');
    await FilePicker.platform.saveFile(
      dialogTitle: 'Save Sales Report',
      fileName: 'Sales_Report_$safeLabel.xlsx',
      bytes: Uint8List.fromList(bytes),
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
  }

  // ---------- Customer Udhar Ledger ----------

  static Future<Uint8List> _buildLedgerPdf({
    required String customerName,
    String? customerPhone,
    required double balance,
    required List<Map<String, dynamic>> ledger,
    required Map<String, List<Map<String, dynamic>>> saleItemsBySaleId,
    String storeName = 'Hardware Store',
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text(storeName,
              style:
                  pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.Text('Udhar Statement — $customerName',
              style: const pw.TextStyle(fontSize: 13)),
          if (customerPhone != null)
            pw.Text(customerPhone,
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.SizedBox(height: 8),
          pw.Text(
            'Current Balance: Rs ${balance.toStringAsFixed(0)}',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: balance > 0 ? PdfColors.red700 : PdfColors.green700,
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            columnWidths: const {
              0: pw.FlexColumnWidth(1.5),
              1: pw.FlexColumnWidth(1),
              2: pw.FlexColumnWidth(2.5),
              3: pw.FlexColumnWidth(1.2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _cell('Date', bold: true),
                  _cell('Type', bold: true),
                  _cell('Details', bold: true),
                  _cell('Amount', bold: true),
                ],
              ),
              for (final entry in ledger)
                pw.TableRow(children: [
                  _cell(_formatDate(entry['createdAt'] as String)),
                  _cell(entry['type'] == 'sale' ? 'Udhar Sale' : 'Payment'),
                  _cell(entry['type'] == 'sale'
                      ? _itemsSummary(
                          saleItemsBySaleId[entry['id'] as String] ?? [])
                      : '-'),
                  _cell(
                    '${entry['type'] == 'sale' ? '+' : '-'} Rs '
                    '${(entry['amount'] as num).toStringAsFixed(0)}',
                  ),
                ]),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Text(
            'Generated ${DateTime.now().toString().substring(0, 16)}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
          ),
        ],
      ),
    );

    return doc.save();
  }

  static String _formatDate(String iso) {
    final dt = DateTime.parse(iso);
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  static String _itemsSummary(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return '-';
    return items
        .map((i) => '${i['productname']} x${i['quantity']}')
        .join(', ');
  }

  static Future<void> exportLedgerPdf({
    required String customerName,
    String? customerPhone,
    required double balance,
    required List<Map<String, dynamic>> ledger,
    required Map<String, List<Map<String, dynamic>>> saleItemsBySaleId,
  }) async {
    final bytes = await _buildLedgerPdf(
      customerName: customerName,
      customerPhone: customerPhone,
      balance: balance,
      ledger: ledger,
      saleItemsBySaleId: saleItemsBySaleId,
    );
    final safeName = customerName.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_');
    await Printing.sharePdf(bytes: bytes, filename: 'Udhar_$safeName.pdf');
  }

  static Future<void> exportLedgerExcel({
    required String customerName,
    String? customerPhone,
    required double balance,
    required List<Map<String, dynamic>> ledger,
    required Map<String, List<Map<String, dynamic>>> saleItemsBySaleId,
  }) async {
    final excel = xl.Excel.createExcel();
    final sheet = excel['Ledger'];
    excel.setDefaultSheet('Ledger');

    sheet.appendRow([xl.TextCellValue('Udhar Statement - $customerName')]);
    if (customerPhone != null) {
      sheet.appendRow([xl.TextCellValue(customerPhone)]);
    }
    sheet.appendRow([
      xl.TextCellValue('Current Balance'),
      xl.DoubleCellValue(balance),
    ]);
    sheet.appendRow([]);
    sheet.appendRow([
      xl.TextCellValue('Date'),
      xl.TextCellValue('Type'),
      xl.TextCellValue('Details'),
      xl.TextCellValue('Amount'),
    ]);
    for (final entry in ledger) {
      final isSale = entry['type'] == 'sale';
      sheet.appendRow([
        xl.TextCellValue(_formatDate(entry['createdAt'] as String)),
        xl.TextCellValue(isSale ? 'Udhar Sale' : 'Payment'),
        xl.TextCellValue(isSale
            ? _itemsSummary(saleItemsBySaleId[entry['id'] as String] ?? [])
            : '-'),
        xl.DoubleCellValue((entry['amount'] as num).toDouble() *
            (isSale ? 1 : -1)),
      ]);
    }

    final bytes = excel.save();
    if (bytes == null) return;

    final safeName = customerName.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_');
    await FilePicker.platform.saveFile(
      dialogTitle: 'Save Udhar Statement',
      fileName: 'Udhar_$safeName.xlsx',
      bytes: Uint8List.fromList(bytes),
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
  }
}
