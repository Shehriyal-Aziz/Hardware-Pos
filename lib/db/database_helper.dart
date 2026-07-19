import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return await openDatabase(path, version: 1, onCreate: _createDB);
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
        createdAt TEXT NOT NULL
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
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Default inventory password: 1234 (owner can change later)
    await db.insert('settings', {'key': 'inventory_password', 'value': '1234'});
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
    await db.update(
      'settings',
      {'value': value},
      where: 'key = ?',
      whereArgs: [key],
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

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
