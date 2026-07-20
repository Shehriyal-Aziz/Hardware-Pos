import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static const _uuid = Uuid();

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('hardware_pos.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    // Desktop platforms need the FFI SQLite implementation
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final Directory appSupportDir = await getApplicationSupportDirectory();
    final dbPath = appSupportDir.path;
    final path = join(dbPath, fileName);

    // version stays fixed — schema is kept in sync by _ensureSchema below,
    // so new columns/tables never need a manual version bump.
    final db = await openDatabase(path, version: 1, onCreate: _createDB);
    await _ensureSchema(db);
    return db;
  }

  // NOTE: all tables now use TEXT (UUID) primary keys instead of
  // INTEGER AUTOINCREMENT, and all column names are lowercase — both to
  // match the Supabase/PowerSync schema (Postgres lowercases unquoted
  // identifiers) so the future PowerSync migration is a drop-in swap.
  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        price REAL NOT NULL,
        stock INTEGER NOT NULL,
        barcode TEXT,
        imagepath TEXT,
        updatedat TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sales (
        id TEXT PRIMARY KEY,
        totalamount REAL NOT NULL,
        discount REAL NOT NULL DEFAULT 0,
        createdat TEXT NOT NULL,
        paymenttype TEXT NOT NULL DEFAULT 'cash',
        customerid TEXT,
        FOREIGN KEY (customerid) REFERENCES customers (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE sale_items (
        id TEXT PRIMARY KEY,
        saleid TEXT NOT NULL,
        productid TEXT NOT NULL,
        productname TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        priceatsale REAL NOT NULL,
        FOREIGN KEY (saleid) REFERENCES sales (id),
        FOREIGN KEY (productid) REFERENCES products (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        createdat TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE udhar_payments (
        id TEXT PRIMARY KEY,
        customerid TEXT NOT NULL,
        amount REAL NOT NULL,
        createdat TEXT NOT NULL,
        FOREIGN KEY (customerid) REFERENCES customers (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Default inventory password: 1234 (owner can change later)
    await db.insert('settings', {'key': 'inventory_password', 'value': '1234'});
  }

  /// Self-healing schema check. Runs on every app start. For each table
  /// this app expects, create it if missing; for each column a table
  /// expects, add it if missing. This means adding a new column/table to
  /// the app in the future never requires bumping the DB version number
  /// or writing a new onUpgrade branch — just add it to the maps below
  /// and it will be applied automatically on the client's next launch,
  /// with all existing data left untouched.
  Future<void> _ensureSchema(Database db) async {
    final expectedTables = <String, String>{
      'products': '''
        CREATE TABLE products (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          category TEXT NOT NULL,
          price REAL NOT NULL,
          stock INTEGER NOT NULL,
          barcode TEXT,
          imagepath TEXT,
          updatedat TEXT NOT NULL
        )
      ''',
      'sales': '''
        CREATE TABLE sales (
          id TEXT PRIMARY KEY,
          totalamount REAL NOT NULL,
          discount REAL NOT NULL DEFAULT 0,
          createdat TEXT NOT NULL,
          paymenttype TEXT NOT NULL DEFAULT 'cash',
          customerid TEXT
        )
      ''',
      'sale_items': '''
        CREATE TABLE sale_items (
          id TEXT PRIMARY KEY,
          saleid TEXT NOT NULL,
          productid TEXT NOT NULL,
          productname TEXT NOT NULL,
          quantity INTEGER NOT NULL,
          priceatsale REAL NOT NULL
        )
      ''',
      'customers': '''
        CREATE TABLE customers (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          phone TEXT,
          createdat TEXT NOT NULL
        )
      ''',
      'udhar_payments': '''
        CREATE TABLE udhar_payments (
          id TEXT PRIMARY KEY,
          customerid TEXT NOT NULL,
          amount REAL NOT NULL,
          createdat TEXT NOT NULL
        )
      ''',
      'settings': '''
        CREATE TABLE settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''',
    };

    // columns beyond each table's minimal CREATE above, keyed by table.
    final expectedColumns = <String, Map<String, String>>{
      'products': {
        'imagepath': 'TEXT',
      },
      'sales': {
        'paymenttype': "TEXT NOT NULL DEFAULT 'cash'",
        'customerid': 'TEXT',
      },
    };

    final existingTables = (await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table'",
    ))
        .map((row) => row['name'] as String)
        .toSet();

    for (final entry in expectedTables.entries) {
      if (!existingTables.contains(entry.key)) {
        await db.execute(entry.value);
      }
    }

    for (final tableEntry in expectedColumns.entries) {
      final table = tableEntry.key;
      final existingColumns = (await db.rawQuery('PRAGMA table_info($table)'))
          .map((row) => row['name'] as String)
          .toSet();

      for (final colEntry in tableEntry.value.entries) {
        if (!existingColumns.contains(colEntry.key)) {
          await db.execute(
            'ALTER TABLE $table ADD COLUMN ${colEntry.key} ${colEntry.value}',
          );
        }
      }
    }

    // Ensure default password exists even on databases created before
    // settings existed.
    final passwordRow = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['inventory_password'],
    );
    if (passwordRow.isEmpty) {
      await db.insert('settings', {'key': 'inventory_password', 'value': '1234'});
    }
  }

  Future<String> insertProduct(Map<String, dynamic> product) async {
    final db = await instance.database;
    final id = (product['id'] as String?) ?? _uuid.v4();
    final data = {...product, 'id': id};
    await db.insert('products', data);
    return id;
  }

  Future<List<Map<String, dynamic>>> getAllProducts() async {
    final db = await instance.database;
    return await db.query('products', orderBy: 'name ASC');
  }

  Future<int> updateProduct(Map<String, dynamic> product) async {
    final db = await instance.database;
    return await db.update(
      'products',
      product,
      where: 'id = ?',
      whereArgs: [product['id']],
    );
  }

  Future<String?> getSetting(String key) async {
    final db = await instance.database;
    final result = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (result.isEmpty) return null;
    return result.first['value'] as String;
  }

  Future<void> updateSetting(String key, String value) async {
    final db = await instance.database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // will get remove bcz adding dummy data
  Future<void> seedDummyProducts() async {
    final db = await instance.database;
    final categories = ['Tools', 'Plumbing', 'Electrical', 'Paint', 'Hardware'];
    final adjectives = ['Heavy Duty', 'Mini', 'Pro', 'Standard', 'Deluxe'];
    final items = [
      'Hammer',
      'Wrench',
      'Screwdriver',
      'Pipe',
      'Wire',
      'Bulb',
      'Drill',
      'Nail',
      'Bolt',
      'Tape',
    ];

    final batch = db.batch();
    for (int i = 0; i < 100; i++) {
      final name =
          '${adjectives[i % adjectives.length]} ${items[i % items.length]} ${i + 1}';
      batch.insert('products', {
        'id': _uuid.v4(),
        'name': name,
        'category': categories[i % categories.length],
        'price': (100 + (i * 37) % 5000).toDouble(),
        'stock': (i * 3) % 60,
        'barcode': null,
        'imagepath': null,
        'updatedat': DateTime.now().toIso8601String(),
      });
    }
    await batch.commit(noResult: true);
  }
  // remove till here

  Future<int> updateStock(String productId, int newStock) async {
    final db = await instance.database;
    return await db.update(
      'products',
      {'stock': newStock, 'updatedat': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [productId],
    );
  }

  Future<int> deleteProduct(String id) async {
    final db = await instance.database;
    return await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<String> insertSale(Map<String, dynamic> sale) async {
    final db = await instance.database;
    final id = (sale['id'] as String?) ?? _uuid.v4();
    final data = {...sale, 'id': id};
    await db.insert('sales', data);
    return id;
  }

  Future<String> insertSaleItem(Map<String, dynamic> item) async {
    final db = await instance.database;
    final id = (item['id'] as String?) ?? _uuid.v4();
    final data = {...item, 'id': id};
    await db.insert('sale_items', data);
    return id;
  }

  // ---------- Customers & Udhar ----------

  Future<String> insertCustomer(Map<String, dynamic> customer) async {
    final db = await instance.database;
    final id = (customer['id'] as String?) ?? _uuid.v4();
    final data = {...customer, 'id': id};
    await db.insert('customers', data);
    return id;
  }

  Future<List<Map<String, dynamic>>> getAllCustomers() async {
    final db = await instance.database;
    return await db.query('customers', orderBy: 'name ASC');
  }

  Future<Map<String, dynamic>?> getCustomer(String id) async {
    final db = await instance.database;
    final result =
        await db.query('customers', where: 'id = ?', whereArgs: [id]);
    return result.isEmpty ? null : result.first;
  }

  Future<String> insertUdharPayment(Map<String, dynamic> payment) async {
    final db = await instance.database;
    final id = (payment['id'] as String?) ?? _uuid.v4();
    final data = {...payment, 'id': id};
    await db.insert('udhar_payments', data);
    return id;
  }

  Future<List<Map<String, dynamic>>> getCustomerLedger(
      String customerId) async {
    final db = await instance.database;

    final sales = await db.query(
      'sales',
      where: 'customerid = ? AND paymenttype = ?',
      whereArgs: [customerId, 'udhar'],
      orderBy: 'createdat DESC',
    );
    final payments = await db.query(
      'udhar_payments',
      where: 'customerid = ?',
      whereArgs: [customerId],
      orderBy: 'createdat DESC',
    );

    final entries = [
      for (final s in sales)
        {
          'type': 'sale',
          'id': s['id'],
          'amount': s['totalamount'],
          'createdAt': s['createdat'],
        },
      for (final p in payments)
        {
          'type': 'payment',
          'id': p['id'],
          'amount': p['amount'],
          'createdAt': p['createdat'],
        },
    ];
    entries.sort((a, b) =>
        (b['createdAt'] as String).compareTo(a['createdAt'] as String));
    return entries;
  }

  Future<double> getCustomerBalance(String customerId) async {
    final db = await instance.database;

    final salesResult = await db.rawQuery(
      "SELECT COALESCE(SUM(totalamount), 0) as total FROM sales "
      "WHERE customerid = ? AND paymenttype = 'udhar'",
      [customerId],
    );
    final paymentsResult = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total FROM udhar_payments '
      'WHERE customerid = ?',
      [customerId],
    );

    final totalUdhar = (salesResult.first['total'] as num).toDouble();
    final totalPaid = (paymentsResult.first['total'] as num).toDouble();
    return totalUdhar - totalPaid;
  }

  Future<Map<String, double>> getAllCustomerBalances() async {
    final db = await instance.database;

    final salesRows = await db.rawQuery(
      "SELECT customerid, COALESCE(SUM(totalamount), 0) as total FROM sales "
      "WHERE paymenttype = 'udhar' AND customerid IS NOT NULL "
      "GROUP BY customerid",
    );
    final paymentRows = await db.rawQuery(
      'SELECT customerid, COALESCE(SUM(amount), 0) as total '
      'FROM udhar_payments GROUP BY customerid',
    );

    final balances = <String, double>{};
    for (final row in salesRows) {
      final id = row['customerid'] as String;
      balances[id] = (row['total'] as num).toDouble();
    }
    for (final row in paymentRows) {
      final id = row['customerid'] as String;
      balances[id] = (balances[id] ?? 0) - (row['total'] as num).toDouble();
    }
    return balances;
  }

  // ---------- Reports ----------

  Future<Map<String, double>> getSalesSummary(
      DateTime start, DateTime end) async {
    final db = await instance.database;
    final startStr = start.toIso8601String();
    final endStr = end.toIso8601String();

    final cashResult = await db.rawQuery(
      "SELECT COALESCE(SUM(totalamount), 0) as total, COUNT(*) as cnt "
      "FROM sales WHERE paymenttype = 'cash' "
      "AND createdat >= ? AND createdat < ?",
      [startStr, endStr],
    );
    final udharResult = await db.rawQuery(
      "SELECT COALESCE(SUM(totalamount), 0) as total, COUNT(*) as cnt "
      "FROM sales WHERE paymenttype = 'udhar' "
      "AND createdat >= ? AND createdat < ?",
      [startStr, endStr],
    );
    final paymentsResult = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total FROM udhar_payments '
      'WHERE createdat >= ? AND createdat < ?',
      [startStr, endStr],
    );

    return {
      'cashTotal': (cashResult.first['total'] as num).toDouble(),
      'cashCount': (cashResult.first['cnt'] as num).toDouble(),
      'udharTotal': (udharResult.first['total'] as num).toDouble(),
      'udharCount': (udharResult.first['cnt'] as num).toDouble(),
      'udharPaymentsReceived':
          (paymentsResult.first['total'] as num).toDouble(),
    };
  }

  Future<List<Map<String, dynamic>>> getTopProducts(
      DateTime start, DateTime end,
      {int limit = 10}) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT si.productname as name, SUM(si.quantity) as totalQty,
             SUM(si.quantity * si.priceatsale) as totalRevenue
      FROM sale_items si
      INNER JOIN sales s ON si.saleid = s.id
      WHERE s.createdat >= ? AND s.createdat < ?
      GROUP BY si.productname
      ORDER BY totalQty DESC
      LIMIT ?
    ''', [start.toIso8601String(), end.toIso8601String(), limit]);
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
