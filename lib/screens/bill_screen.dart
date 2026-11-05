import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../database/db_helper.dart';
import '../models/bill_model.dart';
import '../models/customer_model.dart';
import '../models/milk_record_model.dart';
import '../services/pdf_invoice_service.dart';
import 'quantity_breakdown_screen.dart';



class MonthlyBillScreen extends StatefulWidget {
  final Customer customer;
  const MonthlyBillScreen({super.key, required this.customer});

  @override
  State<MonthlyBillScreen> createState() => _MonthlyBillScreenState();
}

class _MonthlyBillScreenState extends State<MonthlyBillScreen> {
  final DBHelper dbHelper = DBHelper();
  List<MilkRecord> records = [];
  late DateTime selectedMonth;
  BillRecord? billRecord;
  bool isLoading = true;

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
    // Default to Previous Month (e.g. if today is August, show complete bill of July)
    selectedMonth = previousMonthDate;
    _loadMonthlyRecords(showLoading: true);
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

  Future<void> _loadMonthlyRecords({bool showLoading = false}) async {
    if (showLoading) {
      setState(() {
        isLoading = true;
      });
    }

    final allRecords = await dbHelper.getRecords(widget.customer.id!);

    final monthRecords = allRecords.where((r) {
      final d = DateTime.tryParse(r.date);
      if (d == null) return false;
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

    double collectedAmount = existingBill?.collectedAmount ?? 0.0;
    if (existingBill != null && existingBill.isPaid && collectedAmount == 0.0 && computedTotal > 0) {
      collectedAmount = computedTotal;
    }

    double dueAmount = (computedTotal - collectedAmount).clamp(0.0, double.infinity);
    bool isPaid = computedTotal > 0 ? (dueAmount <= 0) : (existingBill?.isPaid ?? false);

    final newBill = BillRecord(
      id: existingBill?.id,
      customerId: widget.customer.id!,
      billMonth: billMonth,
      totalAmount: computedTotal,
      collectedAmount: collectedAmount,
      dueAmount: dueAmount,
      isPaid: isPaid,
      paymentDate: existingBill?.paymentDate,
      createdAt: existingBill?.createdAt ?? DateTime.now().toIso8601String(),
    );

    final billId = await dbHelper.upsertBill(newBill);
    newBill.id = billId;

    if (!mounted) return;
    setState(() {
      records = monthRecords;
      billRecord = newBill;
      isLoading = false;
    });
  }

  int get skippedDays => records.where((r) => r.status == 'skipped').length;
  double get extraMilk => records.fold(0.0, (sum, r) => sum + r.extraMilk);
  int get normalMilkDays => records.where((r) => r.status != 'skipped').length;
  double get totalMilkLiters => records.fold(
      0.0,
      (sum, r) =>
          sum +
          (r.status == 'skipped'
              ? 0.0
              : r.effectiveMilkQuantity + r.extraMilk));

  double get totalCost => billRecord?.totalAmount ?? 0.0;

  Future<void> _markPaid() async {
    if (billRecord?.id == null) return;
    final nowStr = DateTime.now().toIso8601String();
    await dbHelper.markBillPaid(
      billRecord!.id!,
      paymentDate: nowStr,
    );
    if (!mounted) return;
    setState(() {
      billRecord = billRecord!.copyWith(
        collectedAmount: billRecord!.totalAmount,
        dueAmount: 0.0,
        isPaid: true,
        paymentDate: nowStr,
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("✓ Marked as Fully Paid!"),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
    _loadMonthlyRecords(showLoading: false);
  }

  Future<void> _markUnpaid() async {
    if (billRecord?.id == null) return;
    await dbHelper.markBillUnpaid(billRecord!.id!);
    if (!mounted) return;
    setState(() {
      billRecord = billRecord!.copyWith(
        collectedAmount: 0.0,
        dueAmount: billRecord!.totalAmount,
        isPaid: false,
        paymentDate: null,
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Marked as Unpaid"),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
    _loadMonthlyRecords(showLoading: false);
  }

  Future<void> _addPayment() async {
    if (billRecord == null || billRecord!.id == null) return;
    final controller = TextEditingController();

    final amountText = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add Payment"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Customer: ${widget.customer.name}",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Text(
                "Bill Month: ${DateFormat('MMMM yyyy').format(selectedMonth)} ($monthTag)",
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Total Bill:"),
                        Text("Rs ${billRecord!.totalAmount.toStringAsFixed(2)}",
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Already Collected:"),
                        Text("Rs ${billRecord!.collectedAmount.toStringAsFixed(2)}",
                            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Pending:"),
                        Text("Rs ${billRecord!.dueAmount.toStringAsFixed(2)}",
                            style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid amount"), backgroundColor: Colors.red),
      );
      return;
    }

    if (amount > billRecord!.dueAmount) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Amount exceeds pending amount (Rs ${billRecord!.dueAmount.toStringAsFixed(2)})"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await dbHelper.addBillPayment(billRecord!.id!, amount);
    if (!mounted) return;
    final newCollected = billRecord!.collectedAmount + amount;
    final newDue = (billRecord!.totalAmount - newCollected).clamp(0.0, double.infinity);
    setState(() {
      billRecord = billRecord!.copyWith(
        collectedAmount: newCollected,
        dueAmount: newDue,
        isPaid: newDue <= 0,
        paymentDate: DateTime.now().toIso8601String(),
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("✓ Payment of Rs ${amount.toStringAsFixed(2)} collected from ${widget.customer.name}"),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
    _loadMonthlyRecords(showLoading: false);
  }



  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('MMMM yyyy').format(selectedMonth);
    final prevMonthName = DateFormat('MMM yyyy').format(previousMonthDate);
    final presMonthName = DateFormat('MMM yyyy').format(currentMonthDate);

    final isPaid = billRecord?.isPaid ?? false;
    final collected = billRecord?.collectedAmount ?? 0.0;
    final dueAmount = billRecord?.dueAmount ?? totalCost;
    final isPartiallyPaid = collected > 0 && !isPaid;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text("Bill: ${widget.customer.name}"),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: "Share Bill PDF",
            onPressed: _sharePdfToWhatsApp,
          ),
        ],
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Quick Month Switcher Bar
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
                              _loadMonthlyRecords();
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
                              _loadMonthlyRecords();
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          avatar: const Icon(Icons.calendar_month, size: 16),
                          label: Text(!isPreviousMonth && !isPresentMonth ? monthName : "Pick Month"),
                          backgroundColor: (!isPreviousMonth && !isPresentMonth) ? Colors.purple.shade100 : null,
                          onPressed: _pickMonth,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Bill Month Header Card
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
                              "BILL MONTH",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                                color: Colors.black54,
                              ),
                            ),
                            Text(
                              monthName,
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

                  // Summary Info Cards
                  Row(
                    children: [
                      Expanded(
                        child: _infoCard("Milk Days", "$normalMilkDays days", Colors.blue.shade50),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _infoCard("Total Milk", "${totalMilkLiters.toStringAsFixed(1)} L", Colors.indigo.shade50),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _infoCard("Extra Milk", "${extraMilk.toStringAsFixed(1)} L", Colors.cyan.shade50),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _infoCard("Skipped", "$skippedDays days", Colors.amber.shade50),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Financial Card
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    color: isPaid ? Colors.green.shade50 : (isPartiallyPaid ? Colors.blue.shade50 : Colors.orange.shade50),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Total Bill", style: TextStyle(fontSize: 13, color: Colors.black54)),
                                  Text("Rs ${totalCost.toStringAsFixed(2)}",
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Collected", style: TextStyle(fontSize: 13, color: Colors.black54)),
                                  Text("Rs ${collected.toStringAsFixed(2)}",
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Due Amount", style: TextStyle(fontSize: 13, color: Colors.black54)),
                                  Text("Rs ${dueAmount.toStringAsFixed(2)}",
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange.shade900)),
                                ],
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isPaid
                                          ? Colors.green.shade100
                                          : (isPartiallyPaid ? Colors.blue.shade100 : Colors.orange.shade100),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isPaid ? Icons.check_circle : (isPartiallyPaid ? Icons.timelapse : Icons.pending),
                                          size: 14,
                                          color: isPaid
                                              ? Colors.green.shade900
                                              : (isPartiallyPaid ? Colors.blue.shade900 : Colors.orange.shade900),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isPaid ? "STATUS: PAID" : (isPartiallyPaid ? "STATUS: PARTIAL" : "STATUS: UNPAID"),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: isPaid
                                                ? Colors.green.shade900
                                                : (isPartiallyPaid ? Colors.blue.shade900 : Colors.orange.shade900),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (billRecord?.paymentDate != null) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      "(${DateFormat('dd MMM').format(DateTime.parse(billRecord!.paymentDate!))})",
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                    ),
                                  ],
                                ],
                              ),
                              // Navigate to the Quantity Breakdown Screen (shows consumption grouped by daily Liters, Days count, and Price)
                              ElevatedButton.icon(
                                icon: const Icon(Icons.table_chart_outlined, size: 14),
                                label: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      "Qty Breakdown",
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                    SizedBox(width: 3),
                                    Icon(Icons.arrow_forward_ios, size: 10),
                                  ],
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.indigo.shade800,
                                  elevation: 1,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(color: Colors.indigo.shade200, width: 1.2),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => QuantityBreakdownScreen(
                                        customer: widget.customer,
                                        selectedMonth: selectedMonth,
                                        monthTag: monthTag,
                                        records: records,
                                        billRecord: billRecord,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Actions: Add Payment, Mark Full Paid / Mark Unpaid
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text("Add Payment"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: isPaid ? null : _addPayment,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: isPaid
                            ? OutlinedButton.icon(
                                icon: const Icon(Icons.undo, size: 18),
                                label: const Text("Mark Unpaid"),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.orange.shade800,
                                ),
                                onPressed: _markUnpaid,
                              )
                            : ElevatedButton.icon(
                                icon: const Icon(Icons.check_circle_outline, size: 18),
                                label: const Text("Mark Full Paid"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade700,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: totalCost > 0 ? _markPaid : null,
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Share Bill on WhatsApp / PDF Button
                  // SizedBox(
                  //   width: double.infinity,
                  //   child: ElevatedButton.icon(
                  //     icon: const Icon(Icons.share, size: 18),
                  //     label: const Text(
                  //       "Share Bill on WhatsApp / PDF",
                  //       style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  //     ),
                  //     style: ElevatedButton.styleFrom(
                  //       backgroundColor: const Color(0xFF25D366), // WhatsApp Green
                  //       foregroundColor: Colors.white,
                  //       padding: const EdgeInsets.symmetric(vertical: 12),
                  //       shape: RoundedRectangleBorder(
                  //         borderRadius: BorderRadius.circular(10),
                  //       ),
                  //       elevation: 1,
                  //     ),
                  //     onPressed: _sharePdfToWhatsApp,
                  //   ),
                  // ),
                  const SizedBox(height: 10),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(

                      "Daily Consumption Breakdown",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: records.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.event_busy, size: 40, color: Colors.grey[400]),
                                const SizedBox(height: 8),
                                Text(
                                  "No records found for $monthName ($monthTag)",
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: records.length,
                            itemBuilder: (context, index) {
                              final r = records[index];
                              final dateStr = DateFormat('dd MMM yyyy').format(DateTime.parse(r.date));
                              final isSkipped = r.status == 'skipped';

                              return Card(
                                margin: const EdgeInsets.only(bottom: 6),
                                child: ListTile(
                                  dense: true,
                                  leading: Icon(
                                    isSkipped
                                        ? Icons.cancel
                                        : (r.extraMilk > 0 ? Icons.add_circle : Icons.check_circle),
                                    color: isSkipped
                                        ? Colors.red
                                        : (r.extraMilk > 0 ? Colors.blue : Colors.green),
                                  ),
                                  title: Text(dateStr, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  subtitle: Text(
                                    isSkipped
                                        ? 'No milk taken (Skipped)'
                                        : '${_recordLabel(r)}${r.extraMilk > 0 ? ', Extra: ${r.extraMilk.toStringAsFixed(2)} L' : ''}',
                                  ),
                                  trailing: Text(
                                    isSkipped
                                        ? 'Rs 0.00'
                                        : 'Rs ${((r.effectiveMilkQuantity + r.extraMilk) * widget.customer.pricePerLiter).toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
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

  Widget _infoCard(String title, String value, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontSize: 11, color: Colors.black54), textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        ],
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
    return await PdfInvoiceService.generateMonthlyPdf(
      customer: widget.customer,
      month: selectedMonth,
      records: records,
      billRecord: billRecord,
    );
  }



  Future<void> _sharePdfToWhatsApp() async {
    try {
      final file = await _buildPdfFile();
      final monthName = DateFormat('MMMM yyyy').format(selectedMonth);

      final isPaid = billRecord?.isPaid ?? false;
      final collected = billRecord?.collectedAmount ?? 0.0;
      final due = billRecord?.dueAmount ?? (totalCost - collected).clamp(0.0, double.infinity);

      final statusStr = isPaid
          ? "✅ FULLY PAID"
          : (collected > 0 ? "⏱ PARTIALLY PAID (Due: Rs ${due.toStringAsFixed(2)})" : "⚠️ UNPAID (Due: Rs ${due.toStringAsFixed(2)})");

      final messageText =
          "🥛 *Milkify Monthly Bill - $monthName*\n"
          "👤 Customer: *${widget.customer.name}*\n"
          "📅 Cycle: $monthTag\n"
          "🥛 Total Milk: *${totalMilkLiters.toStringAsFixed(1)} L*\n"
          "💰 Total Bill: *Rs ${totalCost.toStringAsFixed(2)}*\n"
          "💳 Status: *$statusStr*\n\n"
          "Please find your complete monthly delivery invoice attached as a PDF.";

      await Share.shareXFiles(
        [XFile(file.path)],
        text: messageText,
        subject: "Milkify Invoice - $monthName for ${widget.customer.name}",
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to share PDF: $e")),
      );
    }
  }
}


