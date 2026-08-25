import 'package:flutter_test/flutter_test.dart';
import 'package:milkify/models/customer_model.dart';
import 'package:milkify/models/milk_record_model.dart';
import 'package:milkify/models/bill_model.dart';
import 'package:milkify/database/db_helper.dart';

void main() {
  group('Customer Model Tests', () {
    test('Customer model serialization and deserialization', () {
      final customer = Customer(
        id: 1,
        name: 'Ali Khan',
        phone: '03001234567',
        address: 'House 12, Street 4, Lahore',
        milkQuantity: 2.5,
        pricePerLiter: 220.0,
        time: 'Morning',
        createdAt: '2026-08-01T10:00:00.000',
      );

      final map = customer.toMap();
      expect(map['id'], 1);
      expect(map['name'], 'Ali Khan');
      expect(map['phone'], '03001234567');
      expect(map['milkQuantity'], 2.5);
      expect(map['pricePerLiter'], 220.0);

      final fromMap = Customer.fromMap(map);
      expect(fromMap.id, customer.id);
      expect(fromMap.name, customer.name);
      expect(fromMap.phone, customer.phone);
      expect(fromMap.address, customer.address);
      expect(fromMap.milkQuantity, customer.milkQuantity);
      expect(fromMap.pricePerLiter, customer.pricePerLiter);
      expect(fromMap.time, customer.time);
      expect(fromMap.createdAt, customer.createdAt);
    });

    test('Customer copyWith works correctly', () {
      final customer = Customer(
        id: 1,
        name: 'Ali Khan',
        phone: '03001234567',
        address: 'House 12',
        milkQuantity: 2.0,
        pricePerLiter: 200.0,
        time: 'Morning',
        createdAt: '2026-08-01T10:00:00.000',
      );

      final updated = customer.copyWith(milkQuantity: 3.5, time: 'Evening');
      expect(updated.id, 1);
      expect(updated.name, 'Ali Khan');
      expect(updated.milkQuantity, 3.5);
      expect(updated.time, 'Evening');
      expect(updated.pricePerLiter, 200.0);
    });

    test('Customer.fromMap handles missing/null values gracefully', () {
      final map = {
        'id': 2,
        'name': 'Sara',
        'phone': null,
        'address': null,
        'milkQuantity': 1,
        'pricePerLiter': 150,
        'time': null,
        'createdAt': null,
      };

      final customer = Customer.fromMap(map);
      expect(customer.name, 'Sara');
      expect(customer.phone, '');
      expect(customer.address, '');
      expect(customer.milkQuantity, 1.0);
      expect(customer.pricePerLiter, 150.0);
      expect(customer.time, 'Morning');
      expect(customer.createdAt, isNotEmpty);
    });
  });

  group('MilkRecord Model Tests', () {
    test('Effective milk quantity calculations', () {
      // Normal day
      final normal = MilkRecord(
        id: 1,
        customerId: 1,
        date: '2026-08-01',
        milkQuantity: 2.0,
        actualMilkQuantity: 2.0,
        extraMilk: 0.0,
        status: 'taken',
      );
      expect(normal.effectiveMilkQuantity, 2.0);

      // Less milk taken
      final less = MilkRecord(
        id: 2,
        customerId: 1,
        date: '2026-08-02',
        milkQuantity: 2.0,
        actualMilkQuantity: 1.0,
        extraMilk: 0.0,
        status: 'taken',
      );
      expect(less.effectiveMilkQuantity, 1.0);

      // Skipped day
      final skipped = MilkRecord(
        id: 3,
        customerId: 1,
        date: '2026-08-03',
        milkQuantity: 2.0,
        actualMilkQuantity: 0.0,
        extraMilk: 0.0,
        status: 'skipped',
      );
      expect(skipped.effectiveMilkQuantity, 0.0);

      // Null actualMilkQuantity fallback
      final fallback = MilkRecord(
        id: 4,
        customerId: 1,
        date: '2026-08-04',
        milkQuantity: 3.0,
        actualMilkQuantity: null,
        extraMilk: 1.5,
        status: 'taken',
      );
      expect(fallback.effectiveMilkQuantity, 3.0);
    });

    test('MilkRecord serialization and deserialization', () {
      final record = MilkRecord(
        id: 5,
        customerId: 10,
        date: '2026-08-15',
        milkQuantity: 2.5,
        actualMilkQuantity: 2.0,
        extraMilk: 1.0,
        status: 'taken',
      );

      final map = record.toMap();
      expect(map['id'], 5);
      expect(map['customerId'], 10);
      expect(map['date'], '2026-08-15');
      expect(map['milkQuantity'], 2.5);
      expect(map['actualMilkQuantity'], 2.0);
      expect(map['extraMilk'], 1.0);
      expect(map['status'], 'taken');

      final fromMap = MilkRecord.fromMap(map);
      expect(fromMap.id, record.id);
      expect(fromMap.customerId, record.customerId);
      expect(fromMap.date, record.date);
      expect(fromMap.milkQuantity, record.milkQuantity);
      expect(fromMap.actualMilkQuantity, record.actualMilkQuantity);
      expect(fromMap.extraMilk, record.extraMilk);
      expect(fromMap.status, record.status);
    });
  });

  group('BillRecord Model & Financial Calculation Tests', () {
    test('BillRecord serialization, deserialization and copyWith', () {
      final bill = BillRecord(
        id: 1,
        customerId: 2,
        billMonth: '2026-08',
        totalAmount: 12000.0,
        collectedAmount: 5000.0,
        dueAmount: 7000.0,
        isPaid: false,
        paymentDate: null,
        createdAt: '2026-08-01T00:00:00.000',
      );

      final map = bill.toMap();
      expect(map['id'], 1);
      expect(map['totalAmount'], 12000.0);
      expect(map['collectedAmount'], 5000.0);
      expect(map['dueAmount'], 7000.0);
      expect(map['isPaid'], 0);

      final fromMap = BillRecord.fromMap(map);
      expect(fromMap.id, 1);
      expect(fromMap.totalAmount, 12000.0);
      expect(fromMap.collectedAmount, 5000.0);
      expect(fromMap.dueAmount, 7000.0);
      expect(fromMap.isPaid, false);

      final updated = fromMap.copyWith(
        collectedAmount: 12000.0,
        dueAmount: 0.0,
        isPaid: true,
        paymentDate: '2026-08-20T12:00:00.000',
      );
      expect(updated.isPaid, true);
      expect(updated.dueAmount, 0.0);
      expect(updated.collectedAmount, 12000.0);
    });

    test('Monthly Bill calculation logic with mixed records', () {
      const pricePerLiter = 200.0;
      final records = [
        // Day 1: Normal 2L -> 2 * 200 = 400
        MilkRecord(customerId: 1, date: '2026-08-01', milkQuantity: 2.0, actualMilkQuantity: 2.0, extraMilk: 0, status: 'taken'),
        // Day 2: Less 1L -> 1 * 200 = 200
        MilkRecord(customerId: 1, date: '2026-08-02', milkQuantity: 2.0, actualMilkQuantity: 1.0, extraMilk: 0, status: 'taken'),
        // Day 3: Normal 2L + Extra 1.5L -> 3.5 * 200 = 700
        MilkRecord(customerId: 1, date: '2026-08-03', milkQuantity: 2.0, actualMilkQuantity: 2.0, extraMilk: 1.5, status: 'taken'),
        // Day 4: Skipped -> 0
        MilkRecord(customerId: 1, date: '2026-08-04', milkQuantity: 2.0, actualMilkQuantity: 0.0, extraMilk: 0, status: 'skipped'),
      ];

      final total = records.fold(0.0, (sum, r) {
        if (r.status != 'skipped') {
          return sum + (r.effectiveMilkQuantity + r.extraMilk) * pricePerLiter;
        }
        return sum;
      });

      expect(total, 1300.0);

      final skippedDays = records.where((r) => r.status == 'skipped').length;
      expect(skippedDays, 1);

      final deliveredDays = records.where((r) => r.status != 'skipped').length;
      expect(deliveredDays, 3);

      final totalExtraMilk = records.fold(0.0, (sum, r) => sum + r.extraMilk);
      expect(totalExtraMilk, 1.5);
    });

    test('Partial payments and due calculation logic', () {
      double totalBill = 5000.0;
      double collected = 0.0;

      // First partial payment: 2000
      double payment1 = 2000.0;
      collected += payment1;
      double due1 = (totalBill - collected).clamp(0.0, double.infinity);
      bool isPaid1 = (due1 <= 0);

      expect(collected, 2000.0);
      expect(due1, 3000.0);
      expect(isPaid1, false);

      // Second partial payment: 3000 (completes bill)
      double payment2 = 3000.0;
      collected += payment2;
      double due2 = (totalBill - collected).clamp(0.0, double.infinity);
      bool isPaid2 = (due2 <= 0);

      expect(collected, 5000.0);
      expect(due2, 0.0);
      expect(isPaid2, true);
    });

    test('Collection percentage calculation', () {
      double totalGenerated = 10000.0;
      double totalCollected = 7500.0;

      double percent = (totalCollected / totalGenerated) * 100;
      expect(percent, 75.0);

      // Edge case: 0 generated
      double zeroGenerated = 0.0;
      double zeroCollected = 0.0;
      double zeroPercent = zeroGenerated == 0 ? 0.0 : (zeroCollected / zeroGenerated) * 100;
      expect(zeroPercent, 0.0);
    });
  });

  group('Date Formatting Tests', () {
    test('formatDate produces standard YYYY-MM-DD', () {
      final dt = DateTime(2026, 8, 5);
      expect(DBHelper.formatDate(dt), '2026-08-05');

      final dtEnd = DateTime(2026, 12, 31);
      expect(DBHelper.formatDate(dtEnd), '2026-12-31');

      final dtStart = DateTime(2026, 1, 1);
      expect(DBHelper.formatDate(dtStart), '2026-01-01');
    });
  });
}



