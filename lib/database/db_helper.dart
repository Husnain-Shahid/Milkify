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
      version: 7,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE customers(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            phone TEXT,
            address TEXT,
            milkQuantity REAL,
            pricePerLiter REAL,
            time TEXT,
            createdAt TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE milk_records(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            customerId INTEGER,
            date TEXT,
            milkQuantity REAL,
            actualMilkQuantity REAL,
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
            collectedAmount REAL DEFAULT 0.0,
            dueAmount REAL,
            isPaid INTEGER,
            paymentDate TEXT,
            createdAt TEXT,
            UNIQUE(customerId, billMonth)
          )
        ''');

        await db.execute('''
          CREATE TABLE pdf_dispatch_logs(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            customerId INTEGER NOT NULL,
            billMonth TEXT NOT NULL,
            phoneNumber TEXT NOT NULL,
            status TEXT NOT NULL,
            filePath TEXT,
            dispatchedAt TEXT NOT NULL,
            errorMessage TEXT,
            UNIQUE(customerId, billMonth)
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS bills(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              customerId INTEGER,
              billMonth TEXT,
              totalAmount REAL,
              collectedAmount REAL DEFAULT 0.0,
              dueAmount REAL,
              isPaid INTEGER,
              paymentDate TEXT,
              createdAt TEXT,
              UNIQUE(customerId, billMonth)
            )
          ''');
        }

        if (oldVersion < 4) {
          try {
            await db.execute(
              'ALTER TABLE milk_records ADD COLUMN actualMilkQuantity REAL',
            );
          } catch (_) {
            // Column may already exist.
          }
        }

        if (oldVersion < 5) {
          try {
            await db.execute(
              'ALTER TABLE customers ADD COLUMN createdAt TEXT',
            );
          } catch (_) {
            // Column may already exist.
          }

          // Fill missing timestamps for older rows so sync can work.
          await db.execute('''
            UPDATE customers
            SET createdAt = COALESCE(createdAt, strftime('%Y-%m-%dT%H:%M:%f', 'now'))
          ''');
        }

        if (oldVersion < 6) {
          try {
            await db.execute(
              'ALTER TABLE bills ADD COLUMN collectedAmount REAL DEFAULT 0.0',
            );
          } catch (_) {
            // Column may already exist.
          }
        }

        if (oldVersion < 7) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS pdf_dispatch_logs(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              customerId INTEGER NOT NULL,
              billMonth TEXT NOT NULL,
              phoneNumber TEXT NOT NULL,
              status TEXT NOT NULL,
              filePath TEXT,
              dispatchedAt TEXT NOT NULL,
              errorMessage TEXT,
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

  /// Delete a customer and cascade delete their milk records and bills
  Future<int> deleteCustomer(int id) async {
    final db = await database;
    await db.delete('milk_records', where: 'customerId = ?', whereArgs: [id]);
    await db.delete('bills', where: 'customerId = ?', whereArgs: [id]);
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

  static String formatDate(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  /// Ensure today's normal milk is present
  Future<void> ensureTodayMilk(int customerId, double milkQuantity) async {
    final String today = formatDate(DateTime.now());
    final MilkRecord? todayRecord = await getRecordByDate(customerId, today);
    if (todayRecord == null) {
      final MilkRecord record = MilkRecord(
        customerId: customerId,
        date: today,
        milkQuantity: milkQuantity,
        actualMilkQuantity: milkQuantity,
        extraMilk: 0,
        status: 'taken',
      );
      await insertMilkRecord(record);
    }
  }

  /// Sync missing normal milk records for all customers up to today.
  /// If the app was closed for multiple days, this backfills the missing days.
  Future<void> syncMissingMilkRecords() async {
    final customers = await getCustomers();

    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);

    for (final customer in customers) {
      if (customer.id == null) continue;

      final records = await getRecords(customer.id!);
      final existingDates = records.map((r) => r.date).toSet();

      DateTime startDate;

      if (records.isNotEmpty) {
        final latest = DateTime.tryParse(records.last.date);
        if (latest != null) {
          startDate = DateTime(latest.year, latest.month, latest.day + 1);
        } else {
          startDate = todayDate;
        }
      } else {
        final created = DateTime.tryParse(customer.createdAt) ?? todayDate;
        startDate = DateTime(created.year, created.month, created.day);
      }

      for (DateTime day = startDate;
          !day.isAfter(todayDate);
          day = DateTime(day.year, day.month, day.day + 1)) {
        final key = formatDate(day);

        if (existingDates.contains(key)) continue;

        await insertMilkRecord(
          MilkRecord(
            customerId: customer.id!,
            date: key,
            milkQuantity: customer.milkQuantity,
            actualMilkQuantity: customer.milkQuantity,
            extraMilk: 0,
            status: 'taken',
          ),
        );
      }
    }
  }

  // --------------------------------------------------
  // BILL / PAYMENT TRACKING
  // --------------------------------------------------

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

  Future<int> upsertBill(BillRecord bill) async {
    final db = await database;
    final existing = await getBillByMonth(bill.customerId, bill.billMonth);

    if (existing == null) {
      final id = await db.insert('bills', bill.toMap());
      bill.id = id;
      return id;
    } else {
      bill.id = existing.id;
      await db.update(
        'bills',
        bill.toMap(),
        where: 'id = ?',
        whereArgs: [existing.id],
      );
      return existing.id!;
    }
  }


  Future<int> markBillPaid(int billId, {String? paymentDate}) async {
    final db = await database;
    final bill = await getBillById(billId);

    if (bill == null) return 0;

    return await db.update(
      'bills',
      {
        'collectedAmount': bill.totalAmount,
        'dueAmount': 0.0,
        'isPaid': 1,
        'paymentDate': paymentDate ?? DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [billId],
    );
  }

  Future<int> markBillUnpaid(int billId) async {
    final db = await database;
    final bill = await getBillById(billId);

    if (bill == null) return 0;

    return await db.update(
      'bills',
      {
        'collectedAmount': 0.0,
        'dueAmount': bill.totalAmount,
        'isPaid': 0,
        'paymentDate': null,
      },
      where: 'id = ?',
      whereArgs: [billId],
    );
  }

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

  Future<int> addBillPayment(int billId, double amount) async {
    final db = await database;
    final bill = await getBillById(billId);

    if (bill == null) return 0;

    double newCollected = bill.collectedAmount + amount;
    if (newCollected > bill.totalAmount) newCollected = bill.totalAmount;
    double newDue = (bill.totalAmount - newCollected).clamp(0.0, double.infinity);

    return await db.update(
      'bills',
      {
        'collectedAmount': newCollected,
        'dueAmount': newDue,
        'isPaid': newDue == 0 ? 1 : 0,
        'paymentDate': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [billId],
    );
  }

  /// Check if the monthly PDF has already been successfully sent to the customer
  Future<bool> isMonthlyPdfDispatched(int customerId, String billMonth) async {
    final db = await database;
    final res = await db.query(
      'pdf_dispatch_logs',
      where: 'customerId = ? AND billMonth = ? AND status = ?',
      whereArgs: [customerId, billMonth, 'sent'],
      limit: 1,
    );
    return res.isNotEmpty;
  }

  /// Record a PDF dispatch attempt (sent, failed, or skipped)
  Future<void> recordPdfDispatch({
    required int customerId,
    required String billMonth,
    required String phoneNumber,
    required String status,
    String? filePath,
    String? errorMessage,
  }) async {
    final db = await database;
    final data = {
      'customerId': customerId,
      'billMonth': billMonth,
      'phoneNumber': phoneNumber,
      'status': status,
      'filePath': filePath,
      'dispatchedAt': DateTime.now().toIso8601String(),
      'errorMessage': errorMessage,
    };

    await db.insert(
      'pdf_dispatch_logs',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retrieve all PDF dispatch logs for a given month
  Future<List<Map<String, dynamic>>> getPdfDispatchLogsForMonth(String billMonth) async {
    final db = await database;
    return await db.query(
      'pdf_dispatch_logs',
      where: 'billMonth = ?',
      whereArgs: [billMonth],
      orderBy: 'dispatchedAt DESC',
    );
  }

  /// Get list of customer IDs that have been successfully sent for a given month
  Future<List<int>> getDispatchedCustomerIdsForMonth(String billMonth) async {
    final db = await database;
    final res = await db.query(
      'pdf_dispatch_logs',
      columns: ['customerId'],
      where: 'billMonth = ? AND status = ?',
      whereArgs: [billMonth, 'sent'],
    );
    return res.map((r) => r['customerId'] as int).toList();
  }
}



