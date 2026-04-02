import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/customer_model.dart';
import '../models/milk_record_model.dart';
import 'package:intl/intl.dart';

class MonthlyBillScreen extends StatefulWidget {
  final Customer customer;

  MonthlyBillScreen({required this.customer});

  @override
  _MonthlyBillScreenState createState() => _MonthlyBillScreenState();
}

class _MonthlyBillScreenState extends State<MonthlyBillScreen> {
  DBHelper dbHelper = DBHelper();
  List<MilkRecord> records = [];
  DateTime selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadMonthlyRecords();
  }

  void _loadMonthlyRecords() async {
    List<MilkRecord> allRecords = await dbHelper.getRecords(widget.customer.id!);

    setState(() {
      records = allRecords.where((r) {
        DateTime d = DateTime.parse(r.date);
        return d.year == selectedMonth.year && d.month == selectedMonth.month;
      }).toList();
    });
  }

  int get skippedDays =>
      records.where((r) => r.status == 'skipped').length;

  double get extraMilk =>
      records.fold(0.0, (sum, r) => sum + r.extraMilk);

  int get normalMilkDays =>
      records.where((r) => r.status != 'skipped').length;

  double get totalCost =>
      (normalMilkDays * widget.customer.milkQuantity * widget.customer.pricePerLiter) +
          (extraMilk * widget.customer.pricePerLiter);

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
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _pickMonth,
              child: Text("Change Month"),
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
      fieldHintText: "Month/Year",
      selectableDayPredicate: (day) => true,
    );

    if (picked != null) {
      setState(() {
        selectedMonth = DateTime(picked.year, picked.month);
        _loadMonthlyRecords();
      });
    }
  }
}