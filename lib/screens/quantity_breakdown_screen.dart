import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../database/db_helper.dart';
import '../models/bill_model.dart';
import '../models/customer_model.dart';
import '../models/milk_record_model.dart';

/// Represents a grouped tier of daily milk consumption.
/// E.g. Customer took 8.0 L per day on 7 days -> 56 L -> Rs 5,600
class QuantityGroup {
  final double dailyQuantity;
  final int daysCount;
  final double totalLiters;
  final double unitPrice;
  final double totalPrice;
  final List<DateTime> dates;

  QuantityGroup({
    required this.dailyQuantity,
    required this.daysCount,
    required this.totalLiters,
    required this.unitPrice,
    required this.totalPrice,
    required this.dates,
  });
}

/// Screen that displays customer monthly milk consumption grouped by daily quantity (Liters).
/// Replicates traditional milk dairy ledger breakdowns showing:
/// - Liters per day
/// - Days count
/// - Total Liters for that group
/// - Total Price for that group
/// - Grand Total at the bottom
/// Also supports tap-to-reveal dates, skipped days tracking, and WhatsApp sharing.
class QuantityBreakdownScreen extends StatefulWidget {
  final Customer customer;
  final DateTime selectedMonth;
  final String monthTag;
  final List<MilkRecord>? records;
  final BillRecord? billRecord;

  const QuantityBreakdownScreen({
    super.key,
    required this.customer,
    required this.selectedMonth,
    required this.monthTag,
    this.records,
    this.billRecord,
  });

  @override
  State<QuantityBreakdownScreen> createState() => _QuantityBreakdownScreenState();
}

class _QuantityBreakdownScreenState extends State<QuantityBreakdownScreen> {
  final DBHelper _dbHelper = DBHelper();

  late DateTime _selectedMonth;
  late String _monthTag;
  List<MilkRecord> _records = [];
  BillRecord? _billRecord;
  bool _isLoading = false;

  // Track expanded groups to show dates
  final Set<double> _expandedQuantities = {};
  bool _skippedExpanded = false;

  DateTime get _currentMonthDate {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  DateTime get _previousMonthDate {
    final now = DateTime.now();
    return DateTime(now.year, now.month - 1, 1);
  }

  bool get _isPreviousMonth =>
      _selectedMonth.year == _previousMonthDate.year &&
      _selectedMonth.month == _previousMonthDate.month;

  bool get _isPresentMonth =>
      _selectedMonth.year == _currentMonthDate.year &&
      _selectedMonth.month == _currentMonthDate.month;

  String _calculateMonthTag(DateTime month) {
    if (month.year == _previousMonthDate.year && month.month == _previousMonthDate.month) {
      return "Previous Month (Completed)";
    }
    if (month.year == _currentMonthDate.year && month.month == _currentMonthDate.month) {
      return "Present Month (Ongoing)";
    }
    return "Custom Month";
  }

  @override
  void initState() {
    super.initState();
    _selectedMonth = widget.selectedMonth;
    _monthTag = widget.monthTag;
    _billRecord = widget.billRecord;

    if (widget.records != null && widget.records!.isNotEmpty) {
      _records = List.from(widget.records!);
      _records.sort((a, b) => a.date.compareTo(b.date));
    } else {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    final allRecords = await _dbHelper.getRecords(widget.customer.id!);
    final monthRecords = allRecords.where((r) {
      final d = DateTime.tryParse(r.date);
      if (d == null) return false;
      return d.year == _selectedMonth.year && d.month == _selectedMonth.month;
    }).toList();

    monthRecords.sort((a, b) => a.date.compareTo(b.date));

    final billMonth = DateFormat('yyyy-MM').format(_selectedMonth);
    final bill = await _dbHelper.getBillByMonth(widget.customer.id!, billMonth);

    if (!mounted) return;
    setState(() {
      _records = monthRecords;
      _billRecord = bill;
      _monthTag = _calculateMonthTag(_selectedMonth);
      _isLoading = false;
    });
  }

  List<QuantityGroup> _buildGroups() {
    final Map<double, List<MilkRecord>> groupsMap = {};

    for (var r in _records) {
      if (r.status != 'skipped') {
        final double qty = r.effectiveMilkQuantity + r.extraMilk;
        final double roundedQty = double.parse(qty.toStringAsFixed(2));
        if (roundedQty > 0) {
          groupsMap.putIfAbsent(roundedQty, () => []).add(r);
        }
      }
    }

    final groups = groupsMap.entries.map((entry) {
      final double qty = entry.key;
      final List<MilkRecord> recs = entry.value;
      final int count = recs.length;
      final double totalLit = qty * count;
      final double price = totalLit * widget.customer.pricePerLiter;
      final List<DateTime> dates = recs
          .map((r) => DateTime.tryParse(r.date))
          .whereType<DateTime>()
          .toList()
        ..sort();

      return QuantityGroup(
        dailyQuantity: qty,
        daysCount: count,
        totalLiters: totalLit,
        unitPrice: widget.customer.pricePerLiter,
        totalPrice: price,
        dates: dates,
      );
    }).toList();

    // Sort descending by dailyQuantity (e.g. 8 L, then 6 L, 4 L, etc.)
    groups.sort((a, b) => b.dailyQuantity.compareTo(a.dailyQuantity));
    return groups;
  }

  List<MilkRecord> get _skippedRecords =>
      _records.where((r) => r.status == 'skipped').toList();

  double _calculateTotalCost(List<QuantityGroup> groups) {
    return groups.fold(0.0, (sum, g) => sum + g.totalPrice);
  }

  double _calculateTotalLiters(List<QuantityGroup> groups) {
    return groups.fold(0.0, (sum, g) => sum + g.totalLiters);
  }

  int _calculateTotalDays(List<QuantityGroup> groups) {
    return groups.fold(0, (sum, g) => sum + g.daysCount);
  }

  String _formatQuantity(double q) {
    if (q == q.roundToDouble()) {
      return q.toInt().toString();
    }
    return q.toStringAsFixed(1);
  }

  String _generateSummaryText(List<QuantityGroup> groups) {
    final monthName = DateFormat('MMMM yyyy').format(_selectedMonth);
    final totalDays = _calculateTotalDays(groups);
    final totalLiters = _calculateTotalLiters(groups);
    final totalCost = _calculateTotalCost(groups);
    final skippedCount = _skippedRecords.length;

    final isPaid = _billRecord?.isPaid ?? false;
    final collected = _billRecord?.collectedAmount ?? 0.0;
    final due = _billRecord?.dueAmount ?? (totalCost - collected).clamp(0.0, double.infinity);
    final statusStr = isPaid
        ? "✅ FULLY PAID"
        : (collected > 0 ? "⏱ PARTIALLY PAID (Due: Rs ${due.toStringAsFixed(2)})" : "⚠️ UNPAID (Due: Rs ${due.toStringAsFixed(2)})");

    final buffer = StringBuffer();
    buffer.writeln("🥛 *Milkify - Consumption Breakdown*");
    buffer.writeln("👤 Customer: *${widget.customer.name}*");
    buffer.writeln("📅 Month: *${monthName}* ($_monthTag)");
    buffer.writeln("🥛 Rate: *Rs ${widget.customer.pricePerLiter.toStringAsFixed(2)} / L*");
    buffer.writeln("━━━━━━━━━━━━━━━━━━━━");
    buffer.writeln("📋 *DAILY LITERS BREAKDOWN:*");

    if (groups.isEmpty) {
      buffer.writeln("• No milk consumption records found.");
    } else {
      for (var g in groups) {
        final qStr = _formatQuantity(g.dailyQuantity);
        final litStr = g.totalLiters.toStringAsFixed(1);
        final priceStr = g.totalPrice.toStringAsFixed(2);
        buffer.writeln("• ${qStr} L × ${g.daysCount} days = ${litStr} L  ➔  *Rs ${priceStr}*");
      }
    }

    if (skippedCount > 0) {
      buffer.writeln("• Skipped Days: ${skippedCount} days (0 L)  ➔  Rs 0.00");
    }

    buffer.writeln("━━━━━━━━━━━━━━━━━━━━");
    buffer.writeln("📊 *Total Active Days:* ${totalDays} days");
    buffer.writeln("🥛 *Total Milk Consumed:* ${totalLiters.toStringAsFixed(1)} L");
    buffer.writeln("💰 *Total Bill:* *Rs ${totalCost.toStringAsFixed(2)}*");
    buffer.writeln("💳 *Status:* ${statusStr}");
    buffer.writeln("━━━━━━━━━━━━━━━━━━━━");
    buffer.writeln("Shared via Milkify App");

    return buffer.toString();
  }

  Future<void> _shareOnWhatsApp(List<QuantityGroup> groups) async {
    final text = _generateSummaryText(groups);
    final monthName = DateFormat('MMMM yyyy').format(_selectedMonth);
    await Share.share(
      text,
      subject: "Milkify Breakdown - $monthName (${widget.customer.name})",
    );
  }

  void _copyToClipboard(List<QuantityGroup> groups) {
    final text = _generateSummaryText(groups);
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("✓ Summary breakdown copied to clipboard!"),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2023, 1),
      lastDate: DateTime(2030, 12),
      helpText: "Select Month",
      initialDatePickerMode: DatePickerMode.year,
    );

    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month, 1);
        _monthTag = _calculateMonthTag(_selectedMonth);
      });
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('MMMM yyyy').format(_selectedMonth);
    final prevMonthName = DateFormat('MMM yyyy').format(_previousMonthDate);
    final presMonthName = DateFormat('MMM yyyy').format(_currentMonthDate);

    final groups = _buildGroups();
    final skipped = _skippedRecords;
    final totalDays = _calculateTotalDays(groups);
    final totalLiters = _calculateTotalLiters(groups);
    final totalBill = _calculateTotalCost(groups);

    final isPaid = _billRecord?.isPaid ?? false;
    final collected = _billRecord?.collectedAmount ?? 0.0;
    final dueAmount = _billRecord?.dueAmount ?? (totalBill - collected).clamp(0.0, double.infinity);
    final isPartiallyPaid = collected > 0 && !isPaid;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Quantity Breakdown",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.customer.name,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: "Copy Summary",
            onPressed: () => _copyToClipboard(groups),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: "Share on WhatsApp",
            onPressed: () => _shareOnWhatsApp(groups),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Month Switcher Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            avatar: const Icon(Icons.history, size: 16),
                            label: Text("Previous ($prevMonthName)"),
                            selected: _isPreviousMonth,
                            selectedColor: Colors.blue.shade100,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedMonth = _previousMonthDate;
                                  _monthTag = _calculateMonthTag(_selectedMonth);
                                });
                                _loadData();
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            avatar: const Icon(Icons.today, size: 16),
                            label: Text("Present ($presMonthName)"),
                            selected: _isPresentMonth,
                            selectedColor: Colors.green.shade100,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedMonth = _currentMonthDate;
                                  _monthTag = _calculateMonthTag(_selectedMonth);
                                });
                                _loadData();
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          ActionChip(
                            avatar: const Icon(Icons.calendar_month, size: 16),
                            label: Text(!_isPreviousMonth && !_isPresentMonth ? monthName : "Pick Month"),
                            backgroundColor: (!_isPreviousMonth && !_isPresentMonth) ? Colors.purple.shade100 : null,
                            onPressed: _pickMonth,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Customer & Month Header Card
                    _buildCustomerHeaderCard(monthName, isPaid, isPartiallyPaid),
                    const SizedBox(height: 14),

                    // Quick Summary Stat Badges
                    Row(
                      children: [
                        Expanded(
                          child: _statPill(
                            label: "Total Liters",
                            value: "${totalLiters.toStringAsFixed(1)} L",
                            color: Colors.blue.shade50,
                            textColor: Colors.blue.shade900,
                            icon: Icons.water_drop,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _statPill(
                            label: "Active Days",
                            value: "$totalDays days",
                            color: Colors.indigo.shade50,
                            textColor: Colors.indigo.shade900,
                            icon: Icons.calendar_today,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _statPill(
                            label: "Rate / Liter",
                            value: "Rs ${widget.customer.pricePerLiter.toStringAsFixed(0)}",
                            color: Colors.teal.shade50,
                            textColor: Colors.teal.shade900,
                            icon: Icons.attach_money,
                          ),
                        ),
                        if (skipped.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: _statPill(
                              label: "Skipped",
                              value: "${skipped.length} days",
                              color: Colors.amber.shade50,
                              textColor: Colors.amber.shade900,
                              icon: Icons.event_busy,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Ledger / Breakdown Section Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.receipt_long, size: 18, color: Colors.blue.shade900),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              "Daily Liters Summary Table",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Text(
                          "Tap row for dates",
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // The Handwritten Ledger Styled Table Card (as in Image 2)
                    _buildLedgerTableCard(groups, skipped, totalDays, totalLiters, totalBill),
                    const SizedBox(height: 16),

                    // Payment & Financial Summary Card
                    _buildFinancialCard(totalBill, collected, dueAmount, isPaid, isPartiallyPaid),
                    const SizedBox(height: 16),

                    // Action Buttons (WhatsApp Share & Copy)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.share, size: 18),
                        label: const Text(
                          "Share Breakdown on WhatsApp",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366), // WhatsApp Green
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 2,
                        ),
                        onPressed: () => _shareOnWhatsApp(groups),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text(
                          "Copy Text Summary",
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.indigo.shade800,
                          side: BorderSide(color: Colors.indigo.shade200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => _copyToClipboard(groups),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCustomerHeaderCard(String monthName, bool isPaid, bool isPartiallyPaid) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.blue.shade100,
                child: Text(
                  widget.customer.name.isNotEmpty
                      ? widget.customer.name[0].toUpperCase()
                      : 'C',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.blue.shade900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.customer.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.customer.phone.isNotEmpty
                          ? widget.customer.phone
                          : "No phone number",
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isPaid
                      ? Colors.green.shade50
                      : (isPartiallyPaid ? Colors.blue.shade50 : Colors.orange.shade50),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isPaid
                        ? Colors.green.shade300
                        : (isPartiallyPaid ? Colors.blue.shade300 : Colors.orange.shade300),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPaid
                          ? Icons.check_circle
                          : (isPartiallyPaid ? Icons.timelapse : Icons.pending),
                      size: 13,
                      color: isPaid
                          ? Colors.green.shade800
                          : (isPartiallyPaid ? Colors.blue.shade800 : Colors.orange.shade800),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isPaid ? "PAID" : (isPartiallyPaid ? "PARTIAL" : "UNPAID"),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isPaid
                            ? Colors.green.shade900
                            : (isPartiallyPaid ? Colors.blue.shade900 : Colors.orange.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("BILL MONTH",
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.black54)),
                  Text(monthName,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _isPreviousMonth
                      ? Colors.blue.shade50
                      : (_isPresentMonth ? Colors.green.shade50 : Colors.purple.shade50),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _monthTag,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _isPreviousMonth
                        ? Colors.blue.shade900
                        : (_isPresentMonth ? Colors.green.shade900 : Colors.purple.shade900),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statPill({
    required String label,
    required String value,
    required Color color,
    required Color textColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Builds the table corresponding to the handwritten note in Image 2:
  /// Liters | Days | Total Liters | Price
  /// Followed by Total
  Widget _buildLedgerTableCard(
    List<QuantityGroup> groups,
    List<MilkRecord> skipped,
    int totalDays,
    double totalLiters,
    double totalBill,
  ) {
    if (groups.isEmpty && skipped.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(Icons.event_busy, size: 44, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            Text(
              "No milk records recorded for this month",
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(
              "Records added in calendar will automatically appear grouped here.",
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue.shade100, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade50.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: [
            // Table Header: Liters | Days | Total Liters | Price
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: Colors.blue.shade700,
              ),
              child: const Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      "Liters",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 13,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      "Days",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 13,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      "Total L",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 13,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      "Price",
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 13,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Rows for each daily quantity tier
            ...groups.asMap().entries.map((entry) {
              final index = entry.key;
              final group = entry.value;
              final isExpanded = _expandedQuantities.contains(group.dailyQuantity);
              final isEven = index % 2 == 0;

              return Column(
                children: [
                  InkWell(
                    onTap: () {
                      setState(() {
                        if (isExpanded) {
                          _expandedQuantities.remove(group.dailyQuantity);
                        } else {
                          _expandedQuantities.add(group.dailyQuantity);
                        }
                      });
                    },
                    child: Container(
                      color: isEven ? Colors.white : Colors.blue.shade50.withOpacity(0.35),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          // Liters (e.g. 8 L, 6 L, 4 L, 5.5 L)
                          Expanded(
                            flex: 3,
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    "${_formatQuantity(group.dailyQuantity)} L",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade900,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                  size: 16,
                                  color: Colors.grey.shade500,
                                ),
                              ],
                            ),
                          ),

                          // Days count (e.g. 7, 3, 2)
                          Expanded(
                            flex: 2,
                            child: Text(
                              "${group.daysCount}",
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                          ),

                          // Total Liters (e.g. 56.0 L)
                          Expanded(
                            flex: 3,
                            child: Text(
                              "${group.totalLiters.toStringAsFixed(1)} L",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ),

                          // Total Price for this group (e.g. Rs 5,600.00)
                          Expanded(
                            flex: 3,
                            child: Text(
                              "Rs ${group.totalPrice.toStringAsFixed(0)}",
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Expanded view showing specific dates for this tier
                  if (isExpanded)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      color: Colors.blue.shade50.withOpacity(0.6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.calendar_month, size: 13, color: Colors.blue.shade800),
                              const SizedBox(width: 4),
                              Text(
                                "Dates when ${_formatQuantity(group.dailyQuantity)} L was taken (${group.daysCount} days):",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: group.dates.map((dt) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.blue.shade200),
                                ),
                                child: Text(
                                  DateFormat('dd MMM (E)').format(dt),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.blue.shade900,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Formula: ${_formatQuantity(group.dailyQuantity)} L × ${group.daysCount} days = ${group.totalLiters.toStringAsFixed(1)} L × Rs ${group.unitPrice.toStringAsFixed(0)}/L = Rs ${group.totalPrice.toStringAsFixed(2)}",
                            style: TextStyle(
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                              color: Colors.blue.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
                ],
              );
            }),

            // Skipped Days Row (if any)
            if (skipped.isNotEmpty) ...[
              InkWell(
                onTap: () {
                  setState(() {
                    _skippedExpanded = !_skippedExpanded;
                  });
                },
                child: Container(
                  color: Colors.amber.shade50.withOpacity(0.4),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                "Skipped",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber.shade900,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _skippedExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                              size: 16,
                              color: Colors.amber.shade800,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          "${skipped.length}",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                      const Expanded(
                        flex: 3,
                        child: Text(
                          "0.0 L",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                      ),
                      const Expanded(
                        flex: 3,
                        child: Text(
                          "Rs 0.00",
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_skippedExpanded)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  color: Colors.amber.shade50,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Skipped Delivery Dates (${skipped.length} days):",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: skipped.map((r) {
                          final dt = DateTime.tryParse(r.date);
                          final label = dt != null ? DateFormat('dd MMM (E)').format(dt) : r.date;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.amber.shade300),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
            ],

            // Grand Total Row (Prominently styled matching "Total 2300" in handwritten note)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                border: Border(
                  top: BorderSide(color: Colors.indigo.shade200, width: 1.5),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      "TOTAL",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Colors.indigo.shade900,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      "$totalDays days",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo.shade900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      "${totalLiters.toStringAsFixed(1)} L",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo.shade900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      "Rs ${totalBill.toStringAsFixed(0)}",
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Colors.indigo.shade900,
                        fontSize: 16,
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

  Widget _buildFinancialCard(
    double totalBill,
    double collected,
    double dueAmount,
    bool isPaid,
    bool isPartiallyPaid,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: isPaid
          ? Colors.green.shade50
          : (isPartiallyPaid ? Colors.blue.shade50 : Colors.orange.shade50),
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
                    const Text("Total Bill", style: TextStyle(fontSize: 12, color: Colors.black54)),
                    Text(
                      "Rs ${totalBill.toStringAsFixed(2)}",
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Collected", style: TextStyle(fontSize: 12, color: Colors.black54)),
                    Text(
                      "Rs ${collected.toStringAsFixed(2)}",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Due Amount", style: TextStyle(fontSize: 12, color: Colors.black54)),
                    Text(
                      "Rs ${dueAmount.toStringAsFixed(2)}",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                        isPaid
                            ? Icons.check_circle
                            : (isPartiallyPaid ? Icons.timelapse : Icons.pending),
                        size: 13,
                        color: isPaid
                            ? Colors.green.shade900
                            : (isPartiallyPaid ? Colors.blue.shade900 : Colors.orange.shade900),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isPaid
                            ? "STATUS: FULLY PAID"
                            : (isPartiallyPaid ? "STATUS: PARTIALLY PAID" : "STATUS: UNPAID"),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: isPaid
                              ? Colors.green.shade900
                              : (isPartiallyPaid ? Colors.blue.shade900 : Colors.orange.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_billRecord?.paymentDate != null)
                  Text(
                    "Paid on: ${DateFormat('dd MMM yyyy').format(DateTime.parse(_billRecord!.paymentDate!))}",
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
