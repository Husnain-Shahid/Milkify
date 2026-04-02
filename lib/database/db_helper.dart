import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/customer_model.dart';
import '../models/milk_record_model.dart';
import '../models/bill_model.dart';

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
      version: 3,
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

        await db.execute('''
          CREATE TABLE bills(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            customerId INTEGER,
            billMonth TEXT,
            totalAmount REAL,
            dueAmount REAL,
            isPaid INTEGER,
            paymentDate TEXT,
            createdAt TEXT,
            UNIQUE(customerId, billMonth)
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE bills(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              customerId INTEGER,
              billMonth TEXT,
              totalAmount REAL,
              dueAmount REAL,
              isPaid INTEGER,
              paymentDate TEXT,
              createdAt TEXT,
              UNIQUE(customerId, billMonth)
            )
          ''');
        }
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

  /// Ensure today's normal milk is present
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

  // --------------------------------------------------
  // BILL / PAYMENT TRACKING
  // --------------------------------------------------

  /// Get bill by customer + month
  Future<BillRecord?> getBillByMonth(int customerId, String billMonth) async {
    final db = await database;
    final maps = await db.query(
      'bills',
      where: 'customerId = ? AND billMonth = ?',
      whereArgs: [customerId, billMonth],
    );

    if (maps.isNotEmpty) {
      return BillRecord.fromMap(maps.first);
    }
    return null;
  }

  /// Get bill by id
  Future<BillRecord?> getBillById(int id) async {
    final db = await database;
    final maps = await db.query(
      'bills',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return BillRecord.fromMap(maps.first);
    }
    return null;
  }

  /// Insert or update a bill
  Future<int> upsertBill(BillRecord bill) async {
    final db = await database;
    final existing = await getBillByMonth(bill.customerId, bill.billMonth);

    if (existing == null) {
      final id = await db.insert('bills', bill.toMap());
      bill.id = id;
      return id;
    } else {
      bill.id = existing.id;
      return await db.update(
        'bills',
        bill.toMap(),
        where: 'id = ?',
        whereArgs: [existing.id],
      );
    }
  }

  /// Mark bill as paid
  Future<int> markBillPaid(int billId, {String? paymentDate}) async {
    final db = await database;
    return await db.update(
      'bills',
      {
        'isPaid': 1,
        'dueAmount': 0.0,
        'paymentDate': paymentDate ?? DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [billId],
    );
  }

  /// Mark bill as unpaid
  Future<int> markBillUnpaid(int billId) async {
    final db = await database;
    final bill = await getBillById(billId);

    if (bill == null) return 0;

    return await db.update(
      'bills',
      {
        'isPaid': 0,
        'dueAmount': bill.totalAmount,
        'paymentDate': null,
      },
      where: 'id = ?',
      whereArgs: [billId],
    );
  }

  /// Get all bills for a customer
  Future<List<BillRecord>> getBillsForCustomer(int customerId) async {
    final db = await database;
    final maps = await db.query(
      'bills',
      where: 'customerId = ?',
      whereArgs: [customerId],
      orderBy: 'billMonth DESC',
    );
    return List.generate(maps.length, (i) => BillRecord.fromMap(maps[i]));
  }
  /// Get all bills for a month
  Future<List<BillRecord>> getBillsByMonth(String billMonth) async {
    final db = await database;
    final maps = await db.query(
      'bills',
      where: 'billMonth = ?',
      whereArgs: [billMonth],
      orderBy: 'id ASC',
    );
    return List.generate(maps.length, (i) => BillRecord.fromMap(maps[i]));
  }

  /// Add a payment to a bill (supports installment-style payments)
  Future<int> addBillPayment(int billId, double amount) async {
    final db = await database;
    final bill = await getBillById(billId);

    if (bill == null) return 0;

    double newDue = bill.dueAmount - amount;
    if (newDue < 0) newDue = 0;

    return await db.update(
      'bills',
      {
        'dueAmount': newDue,
        'isPaid': newDue == 0 ? 1 : 0,
        'paymentDate': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [billId],
    );
  }

}
