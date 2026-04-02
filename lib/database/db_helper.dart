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

  /// Insert a new customer
  Future<int> insertCustomer(Customer customer) async {
    final db = await database;
    return await db.insert('customers', customer.toMap());
  }

  /// Update an existing customer
  Future<int> updateCustomer(Customer customer) async {
    final db = await database;
    return await db.update(
      'customers',
      customer.toMap(),
      where: 'id = ?',
      whereArgs: [customer.id],
    );
  }

  /// Get all customers
  Future<List<Customer>> getCustomers() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('customers');
    return List.generate(maps.length, (i) => Customer.fromMap(maps[i]));
  }

  /// Delete a customer
  Future<int> deleteCustomer(int id) async {
    final db = await database;
    return await db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }

  /// Insert or replace a milk record
  /// Used for auto normal milk or editing existing record
  Future<int> insertMilkRecord(MilkRecord record) async {
    final db = await database;
    return await db.insert(
      'milk_records',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update an existing milk record
  Future<int> updateMilkRecord(MilkRecord record) async {
    final db = await database;
    return await db.update(
      'milk_records',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  /// Get all milk records of a customer
  Future<List<MilkRecord>> getRecords(int customerId) async {
    final db = await database;
    final maps = await db.query(
      'milk_records',
      where: 'customerId = ?',
      whereArgs: [customerId],
      orderBy: 'date ASC',
    );
    return List.generate(maps.length, (i) => MilkRecord.fromMap(maps[i]));
  }

  /// Get milk record by specific date
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

  /// Ensure today's normal milk is present, used for auto daily insertion
  Future<void> ensureTodayMilk(int customerId, double milkQuantity) async {
    String today = DateTime.now().toIso8601String().split('T')[0];
    MilkRecord? todayRecord = await getRecordByDate(customerId, today);
    if (todayRecord == null) {
      MilkRecord record = MilkRecord(
        customerId: customerId,
        date: today,
        milkQuantity: milkQuantity,
        extraMilk: 0,
        status: 'taken',
      );
      await insertMilkRecord(record);
    }
  }
}
