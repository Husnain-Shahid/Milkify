import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/db_helper.dart';
import '../models/bill_model.dart';
import '../models/customer_model.dart';

class IncomeDashboardScreen extends StatefulWidget {
  IncomeDashboardScreen({Key? key}) : super(key: key);

  @override
  _IncomeDashboardScreenState createState() => _IncomeDashboardScreenState();
}

class _IncomeDashboardScreenState extends State<IncomeDashboardScreen> {
  final DBHelper dbHelper = DBHelper();

  DateTime selectedMonth =
  DateTime(DateTime.now().year, DateTime.now().month, -1);
  bool isLoading = true;

  List<BillRecord> bills = [];
  Map<int, Customer> customerMap = {};

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  String get monthKey => DateFormat('yyyy-MM').format(selectedMonth);
  String get monthLabel => DateFormat('MMMM yyyy').format(selectedMonth);

  Future<void> _loadDashboard() async {
    setState(() {
      isLoading = true;
    });

    try {
      final customers = await dbHelper.getCustomers();
      customerMap = {
        for (final c in customers)
          if (c.id != null) c.id!: c,
      };

      for (final customer in customers) {
        if (customer.id == null) continue;

        final allRecords = await dbHelper.getRecords(customer.id!);
        final monthRecords = allRecords.where((r) {
          final d = DateTime.parse(r.date);
          return d.year == selectedMonth.year && d.month == selectedMonth.month;
        }).toList();

        final totalAmount = monthRecords.fold(0.0, (sum, r) {
          if (r.status != 'skipped') {
            return sum +
                (r.effectiveMilkQuantity + r.extraMilk) * customer.pricePerLiter;
          }
          return sum;
        });

        final existingBill = await dbHelper.getBillByMonth(customer.id!, monthKey);

        double dueAmount = existingBill?.dueAmount ?? totalAmount;
        if (dueAmount > totalAmount) {
          dueAmount = totalAmount;
        }

        final isPaid = totalAmount == 0 ? true : (existingBill?.isPaid ?? false);

        if (isPaid) {
          dueAmount = 0.0;
        }

        final bill = BillRecord(
          id: existingBill?.id,
          customerId: customer.id!,
          billMonth: monthKey,
          totalAmount: totalAmount,
          collectedAmount: existingBill?.collectedAmount ?? 0.0,
          dueAmount: dueAmount,
          isPaid: isPaid,
          paymentDate: existingBill?.paymentDate,
          createdAt: existingBill?.createdAt ?? DateTime.now().toIso8601String(),
        );

        await dbHelper.upsertBill(bill);
      }

      bills = await dbHelper.getBillsByMonth(monthKey);

      bills.sort((a, b) {
        final aPaid = a.isPaid ? 1 : 0;
        final bPaid = b.isPaid ? 1 : 0;
        if (aPaid != bPaid) return aPaid.compareTo(bPaid);

        final aName = customerMap[a.customerId]?.name ?? '';
        final bName = customerMap[b.customerId]?.name ?? '';
        return aName.compareTo(bName);
      });

      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load dashboard: $e")),
      );
    }
  }

  double get totalGenerated => bills.fold(0.0, (sum, b) => sum + b.totalAmount);

  double get totalCollected =>
      bills.fold(0.0, (sum, b) => sum + b.collectedAmount);

  double get totalDue => bills.fold(0.0, (sum, b) => sum + b.dueAmount);

  int get paidBillsCount => bills.where((b) => b.isPaid).length;
  int get unpaidBillsCount => bills.where((b) => !b.isPaid).length;

  double get collectionPercent {
    if (totalGenerated == 0) return 0;
    return (totalCollected / totalGenerated) * 100;
  }

  String _customerName(int customerId) {
    return customerMap[customerId]?.name ?? 'Customer #$customerId';
  }

  Future<void> _pickMonth() async {
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
      _loadDashboard();
    }
  }

  Future<void> _addPayment(BillRecord bill) async {
    final controller = TextEditingController();

    final amountText = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Add Payment"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Customer: ${_customerName(bill.customerId)}",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Total Bill:", style: TextStyle(color: Colors.grey[700])),
                      Text("Rs ${bill.totalAmount.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Already Collected:", style: TextStyle(color: Colors.grey[700])),
                      Text("Rs ${bill.collectedAmount.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Pending:", style: TextStyle(color: Colors.grey[700])),
                      Text("Rs ${bill.dueAmount.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: "Enter amount received",
                labelText: "Amount to Collect",
                border: OutlineInputBorder(),
                prefixText: "Rs ",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text("Save Payment"),
          ),
        ],
      ),
    );

    final amount = double.tryParse(amountText ?? '');
    if (amount == null || amount <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Invalid amount"),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (amount > bill.dueAmount) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Amount exceeds pending amount (Rs ${bill.dueAmount.toStringAsFixed(2)})"),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    await dbHelper.addBillPayment(bill.id!, amount);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("✓ Payment of Rs ${amount.toStringAsFixed(2)} collected from ${_customerName(bill.customerId)}"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }

    _loadDashboard();
  }

  Future<void> _markPaid(BillRecord bill) async {
    await dbHelper.markBillPaid(
      bill.id!,
      paymentDate: DateTime.now().toIso8601String(),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("✓ Marked as Fully Paid!"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
    _loadDashboard();
  }

  Future<void> _markUnpaid(BillRecord bill) async {
    await dbHelper.markBillUnpaid(bill.id!);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Marked as Unpaid"),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    }
    _loadDashboard();
  }

  Widget _summaryCard(
      String title,
      String value,
      Color color,
      IconData icon,
      ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 26),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _billCard(BillRecord bill) {
    final customerName = _customerName(bill.customerId);
    final collected = bill.collectedAmount;
    final isFullyPaid = bill.dueAmount <= 0;
    final isPartiallyPaid = collected > 0 && !isFullyPaid;

    return Card(
      elevation: 3,
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isFullyPaid ? Colors.green[50] : (isPartiallyPaid ? Colors.blue[50] : Colors.white),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    customerName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isFullyPaid
                        ? Colors.green[100]
                        : (isPartiallyPaid ? Colors.blue[100] : Colors.orange[100]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isFullyPaid
                        ? "PAID"
                        : (isPartiallyPaid ? "PARTIAL" : "UNPAID"),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isFullyPaid
                          ? Colors.green[800]
                          : (isPartiallyPaid ? Colors.blue[800] : Colors.orange[800]),
                    ),
                  ),
                ),
              ],
            ),
            Divider(height: 12),
            Wrap(
              spacing: 20,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Total Bill",
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    Text(
                      "Rs ${bill.totalAmount.toStringAsFixed(2)}",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Collected",
                      style: TextStyle(fontSize: 12, color: Colors.green[600]),
                    ),
                    Text(
                      "Rs ${collected.toStringAsFixed(2)}",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Pending",
                      style: TextStyle(fontSize: 12, color: Colors.orange[600]),
                    ),
                    Text(
                      "Rs ${bill.dueAmount.toStringAsFixed(2)}",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[700],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (bill.paymentDate != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  "Last Payment: ${DateFormat('dd MMM yyyy').format(DateTime.parse(bill.paymentDate!))}",
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _addPayment(bill),
                    icon: Icon(Icons.add),
                    label: Text("Add Payment"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                if (!isFullyPaid)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _markPaid(bill),
                      child: Text("Mark Paid"),
                    ),
                  )
                else
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _markUnpaid(bill),
                      child: Text("Mark Unpaid"),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Income Dashboard"),
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_month),
            tooltip: "Select Month",
            onPressed: _pickMonth,
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: "Refresh",
            onPressed: _loadDashboard,
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadDashboard,
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                monthLabel,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 12),
              GridView.count(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.05,
                children: [
                  _summaryCard(
                    "Total Generated",
                    "Rs ${totalGenerated.toStringAsFixed(2)}",
                    Colors.blue,
                    Icons.receipt_long,
                  ),
                  _summaryCard(
                    "Total Collected",
                    "Rs ${totalCollected.toStringAsFixed(2)}",
                    Colors.green,
                    Icons.account_balance_wallet,
                  ),
                  _summaryCard(
                    "Total Due",
                    "Rs ${totalDue.toStringAsFixed(2)}",
                    Colors.orange,
                    Icons.pending_actions,
                  ),
                  _summaryCard(
                    "Paid Bills",
                    paidBillsCount.toString(),
                    Colors.teal,
                    Icons.check_circle,
                  ),
                  _summaryCard(
                    "Unpaid Bills",
                    unpaidBillsCount.toString(),
                    Colors.redAccent,
                    Icons.cancel,
                  ),
                  _summaryCard(
                    "Collection %",
                    "${collectionPercent.toStringAsFixed(1)}%",
                    Colors.purple,
                    Icons.pie_chart,
                  ),
                ],
              ),
              SizedBox(height: 16),
              Text(
                "Customer Bills",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 12),
              if (bills.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Center(
                    child: Text(
                      "No bills found for this month.",
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: bills.length,
                  itemBuilder: (context, index) {
                    return _billCard(bills[index]);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
