import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('receipt_app.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    // Products table
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        name TEXT,
        tamilName TEXT NOT NULL,
        price REAL NOT NULL,
        unit TEXT,
        category TEXT,
        barcode TEXT,
        stock REAL,
        lastSynced TEXT,
        isLocal INTEGER DEFAULT 0
      )
    ''');

    // Categories table
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        orderIndex INTEGER
      )
    ''');

    // Receipts table
    await db.execute('''
      CREATE TABLE receipts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        receiptNumber INTEGER,
        timestamp TEXT,
        items TEXT,
        totalAmount REAL,
        shopName TEXT,
        isSynced INTEGER DEFAULT 0,
        firestoreId TEXT
      )
    ''');

    // Cart table (for persistent cart)
    await db.execute('''
      CREATE TABLE cart (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        productId TEXT,
        productName TEXT,
        productTamilName TEXT,
        price REAL,
        quantity REAL,
        unit TEXT
      )
    ''');

    // Sync status table
    await db.execute('''
      CREATE TABLE sync_status (
        id INTEGER PRIMARY KEY,
        lastProductSync TEXT,
        lastReceiptSync TEXT,
        pendingSyncCount INTEGER DEFAULT 0
      )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE products ADD COLUMN isLocal INTEGER DEFAULT 0',
      );
      await db.execute('ALTER TABLE receipts ADD COLUMN firestoreId TEXT');
    }
  }

  // Product Operations
  Future<int> insertProduct(Map<String, dynamic> product) async {
    final db = await database;
    return await db.insert(
      'products',
      product,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getProducts() async {
    final db = await database;
    return await db.query('products', orderBy: 'tamilName ASC');
  }

  Future<int> updateProduct(Map<String, dynamic> product) async {
    final db = await database;
    return await db.update(
      'products',
      product,
      where: 'id = ?',
      whereArgs: [product['id']],
    );
  }

  Future<int> deleteProduct(String id) async {
    final db = await database;
    return await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  // Category Operations
  Future<int> insertCategory(Map<String, dynamic> category) async {
    final db = await database;
    return await db.insert(
      'categories',
      category,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await database;
    return await db.query('categories', orderBy: 'orderIndex ASC');
  }

  // Receipt Operations
  Future<int> insertReceipt(Map<String, dynamic> receipt) async {
    final db = await database;
    return await db.insert('receipts', receipt);
  }

  Future<List<Map<String, dynamic>>> getUnsyncedReceipts() async {
    final db = await database;
    return await db.query('receipts', where: 'isSynced = ?', whereArgs: [0]);
  }

  Future<int> markReceiptSynced(int id, String firestoreId) async {
    final db = await database;
    return await db.update(
      'receipts',
      {'isSynced': 1, 'firestoreId': firestoreId},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Cart Operations
  Future<int> addToCart(Map<String, dynamic> item) async {
    final db = await database;

    // Check if item already exists
    final existing = await db.query(
      'cart',
      where: 'productId = ?',
      whereArgs: [item['productId']],
    );

    if (existing.isNotEmpty) {
      // Update quantity
      final currentQty = existing.first['quantity'] as double;
      return await db.update(
        'cart',
        {'quantity': currentQty + (item['quantity'] ?? 1)},
        where: 'productId = ?',
        whereArgs: [item['productId']],
      );
    } else {
      return await db.insert('cart', item);
    }
  }

  Future<List<Map<String, dynamic>>> getCartItems() async {
    final db = await database;
    return await db.query('cart');
  }

  Future<int> updateCartItem(String productId, double quantity) async {
    final db = await database;
    if (quantity <= 0) {
      return await db.delete(
        'cart',
        where: 'productId = ?',
        whereArgs: [productId],
      );
    }
    return await db.update(
      'cart',
      {'quantity': quantity},
      where: 'productId = ?',
      whereArgs: [productId],
    );
  }

  Future<int> clearCart() async {
    final db = await database;
    return await db.delete('cart');
  }

  // Sync Operations
  Future<void> updateSyncStatus(String type, DateTime time) async {
    final db = await database;
    final existing = await db.query('sync_status');

    if (existing.isEmpty) {
      await db.insert('sync_status', {
        'id': 1,
        type == 'products' ? 'lastProductSync' : 'lastReceiptSync': time
            .toIso8601String(),
      });
    } else {
      await db.update(
        'sync_status',
        {
          type == 'products' ? 'lastProductSync' : 'lastReceiptSync': time
              .toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [1],
      );
    }
  }

  Future<Map<String, dynamic>?> getSyncStatus() async {
    final db = await database;
    final result = await db.query('sync_status');
    return result.isNotEmpty ? result.first : null;
  }

  // Batch operations for sync
  Future<void> batchInsertProducts(List<Map<String, dynamic>> products) async {
    final db = await database;
    final batch = db.batch();

    for (var product in products) {
      batch.insert(
        'products',
        product,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }
}
