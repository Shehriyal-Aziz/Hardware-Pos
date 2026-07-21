import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';
import '../main.dart' show powerSyncDb;

/// Wraps the global PowerSyncDatabase (initialized in main.dart) with the
/// same method names the app already used with plain sqflite, so screens
/// and providers don't need to change how they call this class.
///
/// KEY DIFFERENCE from the old sqflite version: numeric money/quantity
/// fields that PowerSync's schema stores as TEXT (price, totalamount,
/// discount, amount, priceatsale) must be converted:
///   - when WRITING: double -> text (.toString())
///   - when READING: text -> double (double.parse(...))
/// This is because Postgres `numeric` always syncs to PowerSync/SQLite as
/// TEXT (to avoid floating point precision loss on money values).
/// `stock` and `quantity` stay as real integers (Column.integer in schema).
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static const _uuid = Uuid();

  DatabaseHelper._init();

  PowerSyncDatabase get db => powerSyncDb;

  // ---------- Products ----------

  Future<String> insertProduct(Map<String, dynamic> product) async {
    final id = (product['id'] as String?) ?? _uuid.v4();
    await db.execute(
      '''INSERT INTO products (id, name, category, price, stock, barcode, imagepath, updatedat)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        id,
        product['name'],
        product['category'],
        (product['price'] as num).toString(),
        product['stock'],
        product['barcode'],
        product['imagepath'],
        product['updatedat'],
      ],
    );
    return id;
  }

  Future<List<Map<String, dynamic>>> getAllProducts() async {
    final rows = await db.getAll('SELECT * FROM products ORDER BY name ASC');
    return rows.map(_productRowToMap).toList();
  }

  Future<int> updateProduct(Map<String, dynamic> product) async {
    await db.execute(
      '''UPDATE products SET name = ?, category = ?, price = ?, stock = ?,
         barcode = ?, imagepath = ?, updatedat = ? WHERE id = ?''',
      [
        product['name'],
        product['category'],
        (product['price'] as num).toString(),
        product['stock'],
        product['barcode'],
        product['imagepath'],
        product['updatedat'],
        product['id'],
      ],
    );
    return 1;
  }

  Future<int> updateStock(String productId, int newStock) async {
    await db.execute(
      'UPDATE products SET stock = ?, updatedat = ? WHERE id = ?',
      [newStock, DateTime.now().toIso8601String(), productId],
    );
    return 1;
  }

  Future<int> deleteProduct(String id) async {
    await db.execute('DELETE FROM products WHERE id = ?', [id]);
    return 1;
  }

  Map<String, dynamic> _productRowToMap(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'name': row['name'],
      'category': row['category'],
      'price': double.parse(row['price'] as String),
      'stock': row['stock'] is int
          ? row['stock']
          : int.parse(row['stock'].toString()),
      'barcode': row['barcode'],
      'imagepath': row['imagepath'],
      'updatedat': row['updatedat'],
    };
  }

  // ---------- Settings ----------

  Future<String?> getSetting(String key) async {
    final rows = await db.getAll(
      'SELECT value FROM settings WHERE key = ?',
      [key],
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String;
  }

  Future<void> updateSetting(String key, String value) async {
    final existing = await getSetting(key);
    if (existing == null) {
      await db.execute(
        'INSERT INTO settings (id, key, value) VALUES (?, ?, ?)',
        [_uuid.v4(), key, value],
      );
    } else {
      await db.execute(
        'UPDATE settings SET value = ? WHERE key = ?',
        [value, key],
      );
    }
  }

  Future<void> ensureDefaultPassword() async {
    final existing = await getSetting('inventory_password');
    if (existing == null) {
      await updateSetting('inventory_password', '1234');
    }
  }

  // will get removed later — dev-only dummy data seeding
  Future<void> seedDummyProducts() async {
    final categories = ['Tools', 'Plumbing', 'Electrical', 'Paint', 'Hardware'];
    final adjectives = ['Heavy Duty', 'Mini', 'Pro', 'Standard', 'Deluxe'];
    final items = [
      'Hammer', 'Wrench', 'Screwdriver', 'Pipe', 'Wire',
      'Bulb', 'Drill', 'Nail', 'Bolt', 'Tape',
    ];

    for (int i = 0; i < 100; i++) {
      final name =
          '${adjectives[i % adjectives.length]} ${items[i % items.length]} ${i + 1}';
      await insertProduct({
        'name': name,
        'category': categories[i % categories.length],
        'price': (100 + (i * 37) % 5000).toDouble(),
        'stock': (i * 3) % 60,
        'barcode': null,
        'imagepath': null,
        'updatedat': DateTime.now().toIso8601String(),
      });
    }
  }

  // ---------- Sales ----------

  Future<String> insertSale(Map<String, dynamic> sale) async {
    final id = (sale['id'] as String?) ?? _uuid.v4();
    await db.execute(
      '''INSERT INTO sales (id, totalamount, discount, createdat, paymenttype, customerid)
         VALUES (?, ?, ?, ?, ?, ?)''',
      [
        id,
        (sale['totalamount'] as num).toString(),
        (sale['discount'] as num? ?? 0).toString(),
        sale['createdat'],
        sale['paymenttype'] ?? 'cash',
        sale['customerid'],
      ],
    );
    return id;
  }

  Future<String> insertSaleItem(Map<String, dynamic> item) async {
    final id = (item['id'] as String?) ?? _uuid.v4();
    await db.execute(
      '''INSERT INTO sale_items (id, saleid, productid, productname, quantity, priceatsale)
         VALUES (?, ?, ?, ?, ?, ?)''',
      [
        id,
        item['saleid'],
        item['productid'],
        item['productname'],
        item['quantity'],
        (item['priceatsale'] as num).toString(),
      ],
    );
    return id;
  }

  Future<List<Map<String, dynamic>>> getSaleItems(String saleId) async {
    final rows = await db.getAll(
      'SELECT * FROM sale_items WHERE saleid = ?',
      [saleId],
    );
    return rows
        .map((row) => {
              ...row,
              'priceatsale': double.parse(row['priceatsale'] as String),
            })
        .toList();
  }

  // ---------- Customers & Udhar ----------

  Future<String> insertCustomer(Map<String, dynamic> customer) async {
    final id = (customer['id'] as String?) ?? _uuid.v4();
    await db.execute(
      'INSERT INTO customers (id, name, phone, createdat) VALUES (?, ?, ?, ?)',
      [id, customer['name'], customer['phone'], customer['createdat']],
    );
    return id;
  }

  Future<List<Map<String, dynamic>>> getAllCustomers() async {
    return await db.getAll('SELECT * FROM customers ORDER BY name ASC');
  }

  Future<Map<String, dynamic>?> getCustomer(String id) async {
    final rows = await db.getAll(
      'SELECT * FROM customers WHERE id = ?',
      [id],
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<String> insertUdharPayment(Map<String, dynamic> payment) async {
    final id = (payment['id'] as String?) ?? _uuid.v4();
    await db.execute(
      '''INSERT INTO udhar_payments (id, customerid, amount, createdat)
         VALUES (?, ?, ?, ?)''',
      [
        id,
        payment['customerid'],
        (payment['amount'] as num).toString(),
        payment['createdat'],
      ],
    );
    return id;
  }

  Future<List<Map<String, dynamic>>> getCustomerLedger(
      String customerId) async {
    final sales = await db.getAll(
      '''SELECT * FROM sales WHERE customerid = ? AND paymenttype = ?
         ORDER BY createdat DESC''',
      [customerId, 'udhar'],
    );
    final payments = await db.getAll(
      'SELECT * FROM udhar_payments WHERE customerid = ? ORDER BY createdat DESC',
      [customerId],
    );

    final entries = [
      for (final s in sales)
        {
          'type': 'sale',
          'id': s['id'],
          'amount': double.parse(s['totalamount'] as String),
          'createdAt': s['createdat'],
        },
      for (final p in payments)
        {
          'type': 'payment',
          'id': p['id'],
          'amount': double.parse(p['amount'] as String),
          'createdAt': p['createdat'],
        },
    ];
    entries.sort((a, b) =>
        (b['createdAt'] as String).compareTo(a['createdAt'] as String));
    return entries;
  }

  Future<double> getCustomerBalance(String customerId) async {
    final salesRows = await db.getAll(
      "SELECT totalamount FROM sales WHERE customerid = ? AND paymenttype = 'udhar'",
      [customerId],
    );
    final paymentRows = await db.getAll(
      'SELECT amount FROM udhar_payments WHERE customerid = ?',
      [customerId],
    );

    final totalUdhar = salesRows.fold<double>(
      0, (sum, r) => sum + double.parse(r['totalamount'] as String));
    final totalPaid = paymentRows.fold<double>(
      0, (sum, r) => sum + double.parse(r['amount'] as String));

    return totalUdhar - totalPaid;
  }

  Future<Map<String, double>> getAllCustomerBalances() async {
    final salesRows = await db.getAll(
      "SELECT customerid, totalamount FROM sales WHERE paymenttype = 'udhar' AND customerid IS NOT NULL",
    );
    final paymentRows = await db.getAll(
      'SELECT customerid, amount FROM udhar_payments',
    );

    final balances = <String, double>{};
    for (final row in salesRows) {
      final id = row['customerid'] as String;
      final amt = double.parse(row['totalamount'] as String);
      balances[id] = (balances[id] ?? 0) + amt;
    }
    for (final row in paymentRows) {
      final id = row['customerid'] as String;
      final amt = double.parse(row['amount'] as String);
      balances[id] = (balances[id] ?? 0) - amt;
    }
    return balances;
  }

  // ---------- Reports ----------

  Future<Map<String, double>> getSalesSummary(
      DateTime start, DateTime end) async {
    final startStr = start.toIso8601String();
    final endStr = end.toIso8601String();

    final cashRows = await db.getAll(
      "SELECT totalamount FROM sales WHERE paymenttype = 'cash' AND createdat >= ? AND createdat < ?",
      [startStr, endStr],
    );
    final udharRows = await db.getAll(
      "SELECT totalamount FROM sales WHERE paymenttype = 'udhar' AND createdat >= ? AND createdat < ?",
      [startStr, endStr],
    );
    final paymentRows = await db.getAll(
      'SELECT amount FROM udhar_payments WHERE createdat >= ? AND createdat < ?',
      [startStr, endStr],
    );

    final cashTotal = cashRows.fold<double>(
      0, (sum, r) => sum + double.parse(r['totalamount'] as String));
    final udharTotal = udharRows.fold<double>(
      0, (sum, r) => sum + double.parse(r['totalamount'] as String));
    final udharPaymentsReceived = paymentRows.fold<double>(
      0, (sum, r) => sum + double.parse(r['amount'] as String));

    return {
      'cashTotal': cashTotal,
      'cashCount': cashRows.length.toDouble(),
      'udharTotal': udharTotal,
      'udharCount': udharRows.length.toDouble(),
      'udharPaymentsReceived': udharPaymentsReceived,
    };
  }

  Future<List<Map<String, dynamic>>> getTopProducts(
      DateTime start, DateTime end,
      {int limit = 10}) async {
    final rows = await db.getAll(
      '''
      SELECT si.productname as name, si.quantity, si.priceatsale
      FROM sale_items si
      INNER JOIN sales s ON si.saleid = s.id
      WHERE s.createdat >= ? AND s.createdat < ?
      ''',
      [start.toIso8601String(), end.toIso8601String()],
    );

    // Aggregate in Dart since priceatsale/quantity math needs text->double
    // parsing that's awkward to do in raw SQL against a TEXT column.
    final totals = <String, Map<String, double>>{};
    for (final row in rows) {
      final name = row['name'] as String;
      final qty = (row['quantity'] as num).toDouble();
      final price = double.parse(row['priceatsale'] as String);
      final entry = totals.putIfAbsent(
          name, () => {'totalQty': 0, 'totalRevenue': 0});
      entry['totalQty'] = entry['totalQty']! + qty;
      entry['totalRevenue'] = entry['totalRevenue']! + (qty * price);
    }

    final result = totals.entries
        .map((e) => {
              'name': e.key,
              'totalQty': e.value['totalQty'],
              'totalRevenue': e.value['totalRevenue'],
            })
        .toList()
      ..sort((a, b) =>
          (b['totalQty'] as double).compareTo(a['totalQty'] as double));

    return result.take(limit).toList();
  }
}