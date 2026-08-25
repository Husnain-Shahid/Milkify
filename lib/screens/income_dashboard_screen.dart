import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/db_helper.dart';
import '../models/bill_model.dart';
import '../models/customer_model.dart';
import 'bill_screen.dart';



class IncomeDashboardScreen extends StatefulWidget {
  const IncomeDashboardScreen({super.key});

  @override
  State<IncomeDashboardScreen> createState() => _IncomeDashboardScreenState();
}


class _IncomeDashboardScreenState extends State<IncomeDashboardScreen> {
  final DBHelper dbHelper = DBHelper();

  late DateTime selectedMonth;
  bool isLoading = true;

  List<BillRecord> bills = [];
  Map<int, Customer> customerMap = {};

  DateTime get currentMonthDate {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  DateTime get previousMonthDate {
    final now = DateTime.now();
    return DateTime(now.year, now.month - 1, 1);
  }

  bool get isPreviousMonth =>
      selectedMonth.year == previousMonthDate.year &&
      selectedMonth.month == previousMonthDate.month;

  bool get isPresentMonth =>
      selectedMonth.year == currentMonthDate.year &&
      selectedMonth.month == currentMonthDate.month;

  String get monthTag {
    if (isPreviousMonth) return "Previous Month (Completed)";
    if (isPresentMonth) return "Present Month (Ongoing)";
    return "Custom Month";
  }

  @override
  void initState() {
    super.initState();
    // Default to Previous Month automatically
    selectedMonth = previousMonthDate;
    _loadDashboard(showLoading: true);
  }

  String get monthKey => DateFormat('yyyy-MM').format(selectedMonth);
  String get monthLabel => DateFormat('MMMM yyyy').format(selectedMonth);

  Future<void> _loadDashboard({bool showLoading = false}) async {
    if (showLoading) {
      setState(() {
        isLoading = true;
      });
    }

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
          final d = DateTime.tryParse(r.date);
          if (d == null) return false;
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

        double collectedAmount = existingBill?.collectedAmount ?? 0.0;
        if (existingBill != null && existingBill.isPaid && collectedAmount == 0.0 && totalAmount > 0) {
          collectedAmount = totalAmount;
        }

        double dueAmount = (totalAmount - collectedAmount).clamp(0.0, double.infinity);
        bool isPaid = totalAmount > 0 ? (dueAmount <= 0) : (existingBill?.isPaid ?? false);

        final bill = BillRecord(
          id: existingBill?.id,
          customerId: customer.id!,
          billMonth: monthKey,
          totalAmount: totalAmount,
          collectedAmount: collectedAmount,
          dueAmount: dueAmount,
          isPaid: isPaid,
          paymentDate: existingBill?.paymentDate,
          createdAt: existingBill?.createdAt ?? DateTime.now().toIso8601String(),
        );

        final id = await dbHelper.upsertBill(bill);
        bill.id = id;
      }

      final rawBills = await dbHelper.getBillsByMonth(monthKey);
      // Filter out bills belonging to deleted customers
      bills = rawBills.where((b) => customerMap.containsKey(b.customerId)).toList();

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
      _loadDashboard(showLoading: true);
    }
  }

  Future<void> _addPayment(BillRecord bill) async {
    final controller = TextEditingController();

    final amountText = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add Payment"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Customer: ${_customerName(bill.customerId)}",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            Text(
              "Month: $monthLabel ($monthTag)",
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
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
                      Text("Rs ${bill.totalAmount.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Already Collected:", style: TextStyle(color: Colors.grey[700])),
                      Text("Rs ${bill.collectedAmount.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Pending:", style: TextStyle(color: Colors.grey[700])),
                      Text("Rs ${bill.dueAmount.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
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
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text("Save Payment"),
          ),
        ],
      ),
    );

    if (amountText == null || amountText.isEmpty) return;

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
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
      final index = bills.indexWhere((b) => b.id == bill.id);
      if (index != -1) {
        final newCollected = bills[index].collectedAmount + amount;
        final newDue = (bills[index].totalAmount - newCollected).clamp(0.0, double.infinity);
        setState(() {
          bills[index] = bills[index].copyWith(
            collectedAmount: newCollected,
            dueAmount: newDue,
            isPaid: newDue <= 0,
            paymentDate: DateTime.now().toIso8601String(),
          );
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("✓ Payment of Rs ${amount.toStringAsFixed(2)} collected from ${_customerName(bill.customerId)}"),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    _loadDashboard(showLoading: false);
  }

  Future<void> _markPaid(BillRecord bill) async {
    final nowStr = DateTime.now().toIso8601String();
    await dbHelper.markBillPaid(
      bill.id!,
      paymentDate: nowStr,
    );
    if (mounted) {
      final index = bills.indexWhere((b) => b.id == bill.id);
      if (index != -1) {
        setState(() {
          bills[index] = bills[index].copyWith(
            collectedAmount: bills[index].totalAmount,
            dueAmount: 0.0,
            isPaid: true,
            paymentDate: nowStr,
          );
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✓ Marked as Fully Paid!"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
    _loadDashboard(showLoading: false);
  }

  Future<void> _markUnpaid(BillRecord bill) async {
    await dbHelper.markBillUnpaid(bill.id!);
    if (mounted) {
      final index = bills.indexWhere((b) => b.id == bill.id);
      if (index != -1) {
        setState(() {
          bills[index] = bills[index].copyWith(
            collectedAmount: 0.0,
            dueAmount: bills[index].totalAmount,
            isPaid: false,
            paymentDate: null,
          );
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Marked as Unpaid"),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    }
    _loadDashboard(showLoading: false);
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
            const SizedBox(width: 10),
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
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: const TextStyle(
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
    final customer = customerMap[bill.customerId];
    final customerName = customer?.name ?? _customerName(bill.customerId);
    final collected = bill.collectedAmount;
    final isFullyPaid = bill.dueAmount <= 0;
    final isPartiallyPaid = collected > 0 && !isFullyPaid;

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isFullyPaid ? Colors.green[50] : (isPartiallyPaid ? Colors.blue[50] : Colors.white),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: customer != null
            ? () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MonthlyBillScreen(customer: customer),
                  ),
                );
                _loadDashboard();
              }
            : null,
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
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isFullyPaid
                          ? Colors.green[100]
                          : (isPartiallyPaid ? Colors.blue[100] : Colors.orange[100]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isFullyPaid ? Icons.check_circle : (isPartiallyPaid ? Icons.timelapse : Icons.pending),
                          size: 13,
                          color: isFullyPaid
                              ? Colors.green[800]
                              : (isPartiallyPaid ? Colors.blue[800] : Colors.orange[800]),
                        ),
                        const SizedBox(width: 4),
                        Text(
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
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 12),
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
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isFullyPaid ? null : () => _addPayment(bill),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text("Add Payment"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!isFullyPaid)
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.check_circle_outline, size: 16),
                        onPressed: bill.totalAmount > 0 ? () => _markPaid(bill) : null,
                        label: const Text("Mark Paid"),
                      ),
                    )
                  else
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.undo, size: 16),
                        onPressed: () => _markUnpaid(bill),
                        label: const Text("Mark Unpaid"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange.shade800,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final prevMonthName = DateFormat('MMM yyyy').format(previousMonthDate);
    final presMonthName = DateFormat('MMM yyyy').format(currentMonthDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Income Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: "Select Month",
            onPressed: _pickMonth,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh",
            onPressed: _loadDashboard,
          ),
        ],
      ),


      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadDashboard,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quick Month Selector Bar
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      avatar: const Icon(Icons.history, size: 16),
                      label: Text("Previous ($prevMonthName)"),
                      selected: isPreviousMonth,
                      selectedColor: Colors.blue.shade100,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            selectedMonth = previousMonthDate;
                          });
                          _loadDashboard();
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      avatar: const Icon(Icons.today, size: 16),
                      label: Text("Present ($presMonthName)"),
                      selected: isPresentMonth,
                      selectedColor: Colors.green.shade100,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            selectedMonth = currentMonthDate;
                          });
                          _loadDashboard();
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    ActionChip(
                      avatar: const Icon(Icons.calendar_month, size: 16),
                      label: Text(!isPreviousMonth && !isPresentMonth ? monthLabel : "Pick Month"),
                      backgroundColor: (!isPreviousMonth && !isPresentMonth) ? Colors.purple.shade100 : null,
                      onPressed: _pickMonth,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Billing Month Header Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isPreviousMonth
                      ? Colors.blue.shade50
                      : (isPresentMonth ? Colors.green.shade50 : Colors.purple.shade50),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isPreviousMonth
                        ? Colors.blue.shade200
                        : (isPresentMonth ? Colors.green.shade200 : Colors.purple.shade200),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "BILLING CYCLE",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            color: Colors.black54,
                          ),
                        ),
                        Text(
                          monthLabel,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPreviousMonth
                            ? Colors.blue.shade100
                            : (isPresentMonth ? Colors.green.shade100 : Colors.purple.shade100),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        monthTag,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isPreviousMonth
                              ? Colors.blue.shade900
                              : (isPresentMonth ? Colors.green.shade900 : Colors.purple.shade900),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Overview Grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.05,
                children: [
                  _summaryCard(
                    "Total Generated",
                    "Rs ${totalGenerated.toStringAsFixed(2)}",
                    Colors.blue.shade700,
                    Icons.receipt_long,
                  ),
                  _summaryCard(
                    "Total Collected",
                    "Rs ${totalCollected.toStringAsFixed(2)}",
                    Colors.green.shade700,
                    Icons.account_balance_wallet,
                  ),
                  _summaryCard(
                    "Total Due",
                    "Rs ${totalDue.toStringAsFixed(2)}",
                    Colors.orange.shade800,
                    Icons.pending_actions,
                  ),
                  _summaryCard(
                    "Paid Bills",
                    paidBillsCount.toString(),
                    Colors.teal.shade700,
                    Icons.check_circle,
                  ),
                  _summaryCard(
                    "Unpaid Bills",
                    unpaidBillsCount.toString(),
                    Colors.redAccent.shade700,
                    Icons.cancel,
                  ),
                  _summaryCard(
                    "Collection %",
                    "${collectionPercent.toStringAsFixed(1)}%",
                    Colors.purple.shade700,
                    Icons.pie_chart,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                "Customer Bills",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if (bills.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long, size: 40, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        Text(
                          "No bills found for $monthLabel ($monthTag).",
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
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

