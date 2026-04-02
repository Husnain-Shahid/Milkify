import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/customer_model.dart';
import '../models/milk_record_model.dart';

class DBHelper {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await initDB();
    return _database!;
  }

  Future<Database> initDB() async {
    String path = join(await getDatabasesPath(), 'milk.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE customers(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            phone TEXT,
            address TEXT,
            milkQuantity REAL,
            pricePerLiter REAL,
            time TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE milk_records(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            customerId INTEGER,
            date TEXT,
            milkQuantity REAL,
            extraMilk REAL,
            status TEXT
          )
        ''');
      },
    );
  }

  // Insert Customer
  Future<int> insertCustomer(Customer customer) async {
    final db = await database;
    return await db.insert('customers', customer.toMap());
  }

  // Get All Customers
  Future<List<Customer>> getCustomers() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('customers');

    return List.generate(maps.length, (i) {
      return Customer.fromMap(maps[i]);
    });
  }

  // Delete Customer
  Future<int> deleteCustomer(int id) async {
    final db = await database;
    return await db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }

  // Insert Milk Record
  Future<int> insertMilkRecord(MilkRecord record) async {
    final db = await database;
    return await db.insert(
      'milk_records',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Get Records for a Customer
  Future<List<MilkRecord>> getRecords(int customerId) async {
    final db = await database;

    final maps = await db.query(
      'milk_records',
      where: 'customerId = ?',
      whereArgs: [customerId],
    );

    return List.generate(maps.length, (i) {
      return MilkRecord.fromMap(maps[i]);
    });
  }

  // Get record by date
  Future<MilkRecord?> getRecordByDate(int customerId, String date) async {
    final db = await database;
    final maps = await db.query(
      'milk_records',
      where: 'customerId = ? AND date = ?',
      whereArgs: [customerId, date],
    );
    if (maps.isNotEmpty) return MilkRecord.fromMap(maps.first);
    return null;
  }
}