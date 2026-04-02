import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../database/db_helper.dart';
import '../models/customer_model.dart';
import '../models/milk_record_model.dart';

class MonthlyBillScreen extends StatefulWidget {
  final Customer customer;
  MonthlyBillScreen({required this.customer});

  @override
  _MonthlyBillScreenState createState() => _MonthlyBillScreenState();
}

class _MonthlyBillScreenState extends State<MonthlyBillScreen> {
  DBHelper dbHelper = DBHelper();
  List<MilkRecord> records = [];
  late DateTime selectedMonth;

  @override
  void initState() {
    super.initState();
    DateTime now = DateTime.now();
    selectedMonth = DateTime(now.year, now.month - 1, 1);
    _loadMonthlyRecords();
  }

  void _loadMonthlyRecords() async {
    List<MilkRecord> allRecords = await dbHelper.getRecords(widget.customer.id!);

    List<MilkRecord> monthRecords = allRecords.where((r) {
      DateTime d = DateTime.parse(r.date);
      return d.year == selectedMonth.year && d.month == selectedMonth.month;
    }).toList();

    for (var r in monthRecords) {
      if (r.status != 'skipped') {
        r.milkQuantity = widget.customer.milkQuantity;
      } else {
        r.milkQuantity = 0;
      }
    }

    monthRecords.sort((a, b) => a.date.compareTo(b.date));

    setState(() {
      records = monthRecords;
    });
  }

  int get skippedDays => records.where((r) => r.status == 'skipped').length;
  double get extraMilk => records.fold(0.0, (sum, r) => sum + r.extraMilk);
  int get normalMilkDays => records.where((r) => r.status != 'skipped').length;
  double get totalCost => records.fold(0.0, (sum, r) {
    if (r.status != 'skipped') {
      return sum + (r.milkQuantity + r.extraMilk) * widget.customer.pricePerLiter;
    } else {
      return sum;
    }
  });

  @override
  Widget build(BuildContext context) {
    String monthName = DateFormat('MMMM yyyy').format(selectedMonth);

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
            Expanded(
              child: ListView.builder(
                itemCount: records.length,
                itemBuilder: (context, index) {
                  MilkRecord r = records[index];
                  String dateStr = DateFormat('dd MMM yyyy').format(DateTime.parse(r.date));
                  return Card(
                    child: ListTile(
                      title: Text(dateStr),
                      subtitle: Text(
                        r.status == 'skipped'
                            ? 'Skipped'
                            : 'Normal: ${r.milkQuantity.toStringAsFixed(2)} L, Extra: ${r.extraMilk.toStringAsFixed(2)} L',
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

  Future<File> _buildPdfFile() async {
    final pdf = pw.Document();
    final monthName = DateFormat('MMMM yyyy').format(selectedMonth);

    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
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
              pw.SizedBox(height: 20),
              pw.Text(
                "Daily Breakdown:",
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headers: ["Date", "Normal Milk (L)", "Extra Milk (L)", "Status"],
                data: records.map((r) {
                  return [
                    DateFormat('dd MMM yyyy').format(DateTime.parse(r.date)),
                    r.milkQuantity.toStringAsFixed(2),
                    r.extraMilk.toStringAsFixed(2),
                    r.status,
                  ];
                }).toList(),
              ),
            ],
          );
        },
      ),
    );

    final bytes = await pdf.save();
    final dir = await getTemporaryDirectory();

    final safeMonth = monthName.replaceAll(' ', '_');
    final file = File('${dir.path}/Milk_Bill_${widget.customer.name}_$safeMonth.pdf');

    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> _sharePdfToWhatsApp() async {
    try {
      final file = await _buildPdfFile();

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Milk bill for ${widget.customer.name} - ${DateFormat('MMMM yyyy').format(selectedMonth)}',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to share PDF: $e")),
      );
    }
  }
}