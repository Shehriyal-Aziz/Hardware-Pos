import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

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

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        price REAL NOT NULL,
        stock INTEGER NOT NULL,
        barcode TEXT,
        imagePath TEXT,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        totalAmount REAL NOT NULL,
        discount REAL NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL,
        paymentType TEXT NOT NULL DEFAULT 'cash',
        customerId INTEGER,
        FOREIGN KEY (customerId) REFERENCES customers (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        saleId INTEGER NOT NULL,
        productId INTEGER NOT NULL,
        productName TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        priceAtSale REAL NOT NULL,
        FOREIGN KEY (saleId) REFERENCES sales (id),
        FOREIGN KEY (productId) REFERENCES products (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE udhar_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customerId INTEGER NOT NULL,
        amount REAL NOT NULL,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (customerId) REFERENCES customers (id)
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
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          category TEXT NOT NULL,
          price REAL NOT NULL,
          stock INTEGER NOT NULL,
          barcode TEXT,
          imagePath TEXT,
          updatedAt TEXT NOT NULL
        )
      ''',
      'sales': '''
        CREATE TABLE sales (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          totalAmount REAL NOT NULL,
          discount REAL NOT NULL DEFAULT 0,
          createdAt TEXT NOT NULL,
          paymentType TEXT NOT NULL DEFAULT 'cash',
          customerId INTEGER
        )
      ''',
      'sale_items': '''
        CREATE TABLE sale_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          saleId INTEGER NOT NULL,
          productId INTEGER NOT NULL,
          productName TEXT NOT NULL,
          quantity INTEGER NOT NULL,
          priceAtSale REAL NOT NULL
        )
      ''',
      'customers': '''
        CREATE TABLE customers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          phone TEXT,
          createdAt TEXT NOT NULL
        )
      ''',
      'udhar_payments': '''
        CREATE TABLE udhar_payments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          customerId INTEGER NOT NULL,
          amount REAL NOT NULL,
          createdAt TEXT NOT NULL
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
        'imagePath': 'TEXT',
      },
      'sales': {
        'paymentType': "TEXT NOT NULL DEFAULT 'cash'",
        'customerId': 'INTEGER',
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

  Future<int> insertProduct(Map<String, dynamic> product) async {
    final db = await instance.database;
    return await db.insert('products', product);
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
        'name': name,
        'category': categories[i % categories.length],
        'price': (100 + (i * 37) % 5000).toDouble(),
        'stock': (i * 3) % 60,
        'barcode': null,
        'imagePath': null,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    }
    await batch.commit(noResult: true);
  }
  // remove till here

  Future<int> updateStock(int productId, int newStock) async {
    final db = await instance.database;
    return await db.update(
      'products',
      {'stock': newStock, 'updatedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [productId],
    );
  }

  Future<int> deleteProduct(int id) async {
    final db = await instance.database;
    return await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertSale(Map<String, dynamic> sale) async {
    final db = await instance.database;
    return await db.insert('sales', sale);
  }

  Future<int> insertSaleItem(Map<String, dynamic> item) async {
    final db = await instance.database;
    return await db.insert('sale_items', item);
  }

  // ---------- Customers & Udhar ----------

  Future<int> insertCustomer(Map<String, dynamic> customer) async {
    final db = await instance.database;
    return await db.insert('customers', customer);
  }

  Future<List<Map<String, dynamic>>> getAllCustomers() async {
    final db = await instance.database;
    return await db.query('customers', orderBy: 'name ASC');
  }

  Future<Map<String, dynamic>?> getCustomer(int id) async {
    final db = await instance.database;
    final result =
        await db.query('customers', where: 'id = ?', whereArgs: [id]);
    return result.isEmpty ? null : result.first;
  }

  Future<int> insertUdharPayment(Map<String, dynamic> payment) async {
    final db = await instance.database;
    return await db.insert('udhar_payments', payment);
  }

  Future<List<Map<String, dynamic>>> getCustomerLedger(int customerId) async {
    final db = await instance.database;

    final sales = await db.query(
      'sales',
      where: 'customerId = ? AND paymentType = ?',
      whereArgs: [customerId, 'udhar'],
      orderBy: 'createdAt DESC',
    );
    final payments = await db.query(
      'udhar_payments',
      where: 'customerId = ?',
      whereArgs: [customerId],
      orderBy: 'createdAt DESC',
    );

    final entries = [
      for (final s in sales)
        {
          'type': 'sale',
          'id': s['id'],
          'amount': s['totalAmount'],
          'createdAt': s['createdAt'],
        },
      for (final p in payments)
        {
          'type': 'payment',
          'id': p['id'],
          'amount': p['amount'],
          'createdAt': p['createdAt'],
        },
    ];
    entries.sort((a, b) =>
        (b['createdAt'] as String).compareTo(a['createdAt'] as String));
    return entries;
  }

  Future<double> getCustomerBalance(int customerId) async {
    final db = await instance.database;

    final salesResult = await db.rawQuery(
      "SELECT COALESCE(SUM(totalAmount), 0) as total FROM sales "
      "WHERE customerId = ? AND paymentType = 'udhar'",
      [customerId],
    );
    final paymentsResult = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total FROM udhar_payments '
      'WHERE customerId = ?',
      [customerId],
    );

    final totalUdhar = (salesResult.first['total'] as num).toDouble();
    final totalPaid = (paymentsResult.first['total'] as num).toDouble();
    return totalUdhar - totalPaid;
  }

  Future<Map<int, double>> getAllCustomerBalances() async {
    final db = await instance.database;

    final salesRows = await db.rawQuery(
      "SELECT customerId, COALESCE(SUM(totalAmount), 0) as total FROM sales "
      "WHERE paymentType = 'udhar' AND customerId IS NOT NULL "
      "GROUP BY customerId",
    );
    final paymentRows = await db.rawQuery(
      'SELECT customerId, COALESCE(SUM(amount), 0) as total '
      'FROM udhar_payments GROUP BY customerId',
    );

    final balances = <int, double>{};
    for (final row in salesRows) {
      final id = row['customerId'] as int;
      balances[id] = (row['total'] as num).toDouble();
    }
    for (final row in paymentRows) {
      final id = row['customerId'] as int;
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
      "SELECT COALESCE(SUM(totalAmount), 0) as total, COUNT(*) as cnt "
      "FROM sales WHERE paymentType = 'cash' "
      "AND createdAt >= ? AND createdAt < ?",
      [startStr, endStr],
    );
    final udharResult = await db.rawQuery(
      "SELECT COALESCE(SUM(totalAmount), 0) as total, COUNT(*) as cnt "
      "FROM sales WHERE paymentType = 'udhar' "
      "AND createdAt >= ? AND createdAt < ?",
      [startStr, endStr],
    );
    final paymentsResult = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total FROM udhar_payments '
      'WHERE createdAt >= ? AND createdAt < ?',
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
      SELECT si.productName as name, SUM(si.quantity) as totalQty,
             SUM(si.quantity * si.priceAtSale) as totalRevenue
      FROM sale_items si
      INNER JOIN sales s ON si.saleId = s.id
      WHERE s.createdAt >= ? AND s.createdAt < ?
      GROUP BY si.productName
      ORDER BY totalQty DESC
      LIMIT ?
    ''', [start.toIso8601String(), end.toIso8601String(), limit]);
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}