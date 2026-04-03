import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../database/db_helper.dart';
import '../models/bill_model.dart';
import '../models/customer_model.dart';
import '../models/milk_record_model.dart';

class MonthlyBillScreen extends StatefulWidget {
  final Customer customer;
  MonthlyBillScreen({required this.customer});

  @override
  _MonthlyBillScreenState createState() => _MonthlyBillScreenState();
}

class _MonthlyBillScreenState extends State<MonthlyBillScreen> {
  final DBHelper dbHelper = DBHelper();
  List<MilkRecord> records = [];
  late DateTime selectedMonth;
  BillRecord? billRecord;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    selectedMonth = DateTime(now.year, now.month - 1, 1);
    _loadMonthlyRecords();
  }

  String _recordLabel(MilkRecord r) {
    if (r.status == 'skipped') return 'Skipped';

    final actual = r.effectiveMilkQuantity;
    final normal = r.milkQuantity;

    if (actual < normal) {
      return 'Less: ${actual.toStringAsFixed(2)} L';
    }

    return 'Normal: ${actual.toStringAsFixed(2)} L';
  }

  Future<void> _loadMonthlyRecords() async {
    final allRecords = await dbHelper.getRecords(widget.customer.id!);

    final monthRecords = allRecords.where((r) {
      final d = DateTime.parse(r.date);
      return d.year == selectedMonth.year && d.month == selectedMonth.month;
    }).toList();

    monthRecords.sort((a, b) => a.date.compareTo(b.date));

    final computedTotal = monthRecords.fold(0.0, (sum, r) {
      if (r.status != 'skipped') {
        return sum +
            (r.effectiveMilkQuantity + r.extraMilk) * widget.customer.pricePerLiter;
      }
      return sum;
    });

    final billMonth = DateFormat('yyyy-MM').format(selectedMonth);
    final existingBill = await dbHelper.getBillByMonth(widget.customer.id!, billMonth);

    final newBill = BillRecord(
      id: existingBill?.id,
      customerId: widget.customer.id!,
      billMonth: billMonth,
      totalAmount: computedTotal,
      dueAmount: existingBill?.isPaid == true ? 0.0 : computedTotal,
      isPaid: existingBill?.isPaid ?? false,
      paymentDate: existingBill?.paymentDate,
      createdAt: existingBill?.createdAt ?? DateTime.now().toIso8601String(),
    );

    await dbHelper.upsertBill(newBill);

    if (!mounted) return;
    setState(() {
      records = monthRecords;
      billRecord = newBill;
    });
  }

  int get skippedDays => records.where((r) => r.status == 'skipped').length;
  double get extraMilk => records.fold(0.0, (sum, r) => sum + r.extraMilk);
  int get normalMilkDays => records.where((r) => r.status != 'skipped').length;

  double get totalCost => records.fold(0.0, (sum, r) {
    if (r.status != 'skipped') {
      return sum +
          (r.effectiveMilkQuantity + r.extraMilk) * widget.customer.pricePerLiter;
    }
    return sum;
  });

  Future<void> _markPaid() async {
    if (billRecord?.id == null) return;
    await dbHelper.markBillPaid(
      billRecord!.id!,
      paymentDate: DateTime.now().toIso8601String(),
    );
    _loadMonthlyRecords();
  }

  Future<void> _markUnpaid() async {
    if (billRecord?.id == null) return;
    await dbHelper.markBillUnpaid(billRecord!.id!);
    _loadMonthlyRecords();
  }

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('MMMM yyyy').format(selectedMonth);
    final isPaid = billRecord?.isPaid ?? false;
    final dueAmount = billRecord?.dueAmount ?? totalCost;

    return Scaffold(
      appBar: AppBar(title: Text("Monthly Bill - ${widget.customer.name}")),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              monthName,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Card(
              child: ListTile(
                title: Text("Normal Milk Days"),
                trailing: Text("$normalMilkDays days"),
              ),
            ),
            Card(
              child: ListTile(
                title: Text("Extra Milk"),
                trailing: Text("${extraMilk.toStringAsFixed(2)} L"),
              ),
            ),
            Card(
              child: ListTile(
                title: Text("Skipped Days"),
                trailing: Text("$skippedDays days"),
              ),
            ),
            Card(
              color: Colors.green[100],
              child: ListTile(
                title: Text(
                  "Total Cost",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: Text("Rs ${totalCost.toStringAsFixed(2)}"),
              ),
            ),
            Card(
              color: isPaid ? Colors.green[50] : Colors.orange[50],
              child: ListTile(
                title: Text(
                  "Payment Status",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  isPaid
                      ? "Paid on ${billRecord?.paymentDate != null
                      ? DateFormat('dd MMM yyyy').format(
                    DateTime.parse(billRecord!.paymentDate!),
                  )
                      : 'N/A'}"
                      : "Unpaid",
                ),
                trailing: Text(
                  "Due: Rs ${dueAmount.toStringAsFixed(2)}",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _sharePdfToWhatsApp,
                    child: Text("Share PDF"),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _pickMonth,
                    child: Text("Change Month"),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: isPaid ? null : _markPaid,
                    child: Text("Mark Paid"),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: isPaid ? _markUnpaid : null,
                    child: Text("Mark Unpaid"),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: records.length,
                itemBuilder: (context, index) {
                  final r = records[index];
                  final dateStr =
                  DateFormat('dd MMM yyyy').format(DateTime.parse(r.date));

                  return Card(
                    child: ListTile(
                      title: Text(dateStr),
                      subtitle: Text(
                        r.status == 'skipped'
                            ? 'Skipped'
                            : '${_recordLabel(r)}, Extra: ${r.extraMilk.toStringAsFixed(2)} L',
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedMonth,
      firstDate: DateTime(2023, 1),
      lastDate: DateTime(2030, 12),
      helpText: "Select Month",
      initialDatePickerMode: DatePickerMode.year,
    );

    if (picked != null) {
      setState(() {
        selectedMonth = DateTime(picked.year, picked.month, 1);
      });
      _loadMonthlyRecords();
    }
  }

  String _safeFileName(String input) {
    return input
        .replaceAll(RegExp(r'[^\w\s-]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
  }

  Future<File> _buildPdfFile() async {
    final pdf = pw.Document();
    final monthName = DateFormat('MMMM yyyy').format(selectedMonth);

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text(
            "Milk Monthly Bill",
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text("Customer: ${widget.customer.name}"),
          pw.Text("Phone: ${widget.customer.phone}"),
          pw.Text("Address: ${widget.customer.address}"),
          pw.Text("Month: $monthName"),
          pw.SizedBox(height: 10),
          pw.Text("Normal Milk Days: $normalMilkDays"),
          pw.Text("Extra Milk: ${extraMilk.toStringAsFixed(2)} L"),
          pw.Text("Skipped Days: $skippedDays"),
          pw.Text("Total Cost: Rs ${totalCost.toStringAsFixed(2)}"),
          pw.Text(
            "Payment Status: ${billRecord?.isPaid == true ? 'PAID' : 'UNPAID'}",
          ),
          pw.Text(
            "Due Amount: Rs ${(billRecord?.dueAmount ?? totalCost).toStringAsFixed(2)}",
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            "Daily Breakdown:",
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: ["Date", "Actual Milk (L)", "Extra Milk (L)", "Status"],
            data: records.map((r) {
              return [
                DateFormat('dd MMM yyyy').format(DateTime.parse(r.date)),
                r.effectiveMilkQuantity.toStringAsFixed(2),
                r.extraMilk.toStringAsFixed(2),
                r.status == 'skipped'
                    ? 'Skipped'
                    : (r.effectiveMilkQuantity < r.milkQuantity
                    ? 'Less'
                    : 'Normal'),
              ];
            }).toList(),
          ),
        ],
      ),
    );

    final bytes = await pdf.save();
    final dir = await getApplicationDocumentsDirectory();

    final safeCustomerName = _safeFileName(widget.customer.name);
    final safeMonth = monthName.replaceAll(' ', '_');
    final file = File('${dir.path}/Milk_Bill_${safeCustomerName}_$safeMonth.pdf');

    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> _sharePdfToWhatsApp() async {
    try {
      final file = await _buildPdfFile();

      await Share.shareXFiles(
        [XFile(file.path)],
        text:
        'Milk bill for ${widget.customer.name} - ${DateFormat('MMMM yyyy').format(selectedMonth)}',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to share PDF: $e")),
      );
    }
  }
}
