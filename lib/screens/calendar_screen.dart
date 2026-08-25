import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../database/db_helper.dart';
import '../models/customer_model.dart';
import '../models/milk_record_model.dart';

class CalendarScreen extends StatefulWidget {
  final Customer customer;

  const CalendarScreen({super.key, required this.customer});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime selectedDay = DateTime.now();
  DateTime focusedDay = DateTime.now();
  final DBHelper dbHelper = DBHelper();
  Map<String, MilkRecord> milkMap = {}; // key = YYYY-MM-DD
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    selectedDay = DateTime(focusedDay.year, focusedDay.month, focusedDay.day);
    _loadMilkRecords();
  }

  String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadMilkRecords() async {
    setState(() {
      isLoading = true;
    });

    final records = await dbHelper.getRecords(widget.customer.id!);
    final today = _dateKey(DateTime.now());

    final hasToday = records.any((r) => r.date == today);
    if (!hasToday) {
      final todayRecord = MilkRecord(
        customerId: widget.customer.id!,
        date: today,
        milkQuantity: widget.customer.milkQuantity,
        actualMilkQuantity: widget.customer.milkQuantity,
        extraMilk: 0,
        status: 'taken',
      );
      await dbHelper.insertMilkRecord(todayRecord);
      records.add(todayRecord);
    }

    if (!mounted) return;
    setState(() {
      milkMap = {for (var r in records) r.date: r};
      isLoading = false;
    });
  }

  Future<void> _saveMilkRecord({
    required DateTime date,
    required double actualMilkQuantity,
    required double extraMilk,
    required String status,
  }) async {
    final key = _dateKey(date);
    final existing = milkMap[key];

    final record = MilkRecord(
      id: existing?.id,
      customerId: widget.customer.id!,
      date: key,
      milkQuantity: widget.customer.milkQuantity,
      actualMilkQuantity: actualMilkQuantity,
      extraMilk: extraMilk,
      status: status,
    );

    if (existing == null) {
      await dbHelper.insertMilkRecord(record);
    } else {
      await dbHelper.updateMilkRecord(record);
    }

    if (!mounted) return;
    _loadMilkRecords();
  }

  Color _getStatusColor(MilkRecord? r) {
    if (r == null) return Colors.transparent;
    if (r.status == 'skipped') return Colors.red.shade400;
    final actual = r.effectiveMilkQuantity;
    if (actual < r.milkQuantity) return Colors.orange.shade400;
    if (r.extraMilk > 0) return Colors.blue.shade500;
    return Colors.green.shade500;
  }

  Widget _buildDayCell(DateTime day, {bool isSelected = false, bool isToday = false}) {
    final key = _dateKey(day);
    final r = milkMap[key];
    final color = _getStatusColor(r);
    final hasRecord = r != null;

    return Center(
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: hasRecord ? color : (isSelected ? Colors.blue.shade100 : Colors.transparent),
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(color: Colors.black87, width: 2.5)
              : (isToday ? Border.all(color: Colors.blue.shade900, width: 1.5) : null),
        ),
        alignment: Alignment.center,
        child: Text(
          '${day.day}',
          style: TextStyle(
            color: hasRecord
                ? Colors.white
                : (isToday ? Colors.blue.shade900 : Colors.black87),
            fontWeight: (isSelected || isToday) ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedKey = _dateKey(selectedDay);
    final currentRecord = milkMap[selectedKey];
    final dateDisplay = DateFormat('EEEE, dd MMMM yyyy').format(selectedDay);

    return Scaffold(
      appBar: AppBar(
        title: Text("Milk Tracking - ${widget.customer.name}"),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  TableCalendar(
                    firstDay: DateTime.utc(2023, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: focusedDay,
                    selectedDayPredicate: (day) => isSameDay(day, selectedDay),
                    onDaySelected: (selected, focused) {
                      setState(() {
                        selectedDay = selected;
                        focusedDay = focused;
                      });
                      _showOptions(selectedDay);
                    },
                    onPageChanged: (focused) {
                      setState(() {
                        focusedDay = focused;
                      });
                    },
                    calendarBuilders: CalendarBuilders(
                      defaultBuilder: (context, day, focusedDay) =>
                          _buildDayCell(day),
                      todayBuilder: (context, day, focusedDay) =>
                          _buildDayCell(day, isToday: true, isSelected: isSameDay(day, selectedDay)),
                      selectedBuilder: (context, day, focusedDay) =>
                          _buildDayCell(day, isSelected: true, isToday: isSameDay(day, DateTime.now())),
                      outsideBuilder: (context, day, focusedDay) => Center(
                        child: Text(
                          '${day.day}',
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 20),
                  // Color Legend
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [
                        _legendItem(Colors.green.shade500, "Normal Milk"),
                        _legendItem(Colors.orange.shade400, "Less Milk"),
                        _legendItem(Colors.blue.shade500, "Extra Milk"),
                        _legendItem(Colors.red.shade400, "Skipped"),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Selected Day Detail Card
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  dateDisplay,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 20),
                                  tooltip: "Change Status",
                                  onPressed: () => _showOptions(selectedDay),
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _detailStat(
                                  "Status",
                                  currentRecord?.status == 'skipped'
                                      ? "Skipped"
                                      : "Delivered",
                                  currentRecord?.status == 'skipped'
                                      ? Colors.red
                                      : Colors.green,
                                ),
                                _detailStat(
                                  "Milk Taken",
                                  "${(currentRecord?.effectiveMilkQuantity ?? widget.customer.milkQuantity).toStringAsFixed(2)} L",
                                  Colors.blue.shade800,
                                ),
                                _detailStat(
                                  "Extra Milk",
                                  "${(currentRecord?.extraMilk ?? 0).toStringAsFixed(2)} L",
                                  Colors.purple.shade700,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.cancel_outlined, size: 16),
                                    label: const Text("No Milk"),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                    ),
                                    onPressed: () async {
                                      await _saveMilkRecord(
                                        date: selectedDay,
                                        actualMilkQuantity: 0,
                                        extraMilk: 0,
                                        status: 'skipped',
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.edit_note, size: 16),
                                    label: const Text("Edit Milk"),
                                    onPressed: () => _showEditMilkDialog(selectedDay),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.add, size: 16),
                                    label: const Text("Extra"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue.shade700,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () => _showExtraMilkDialog(selectedDay),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _detailStat(String title, String value, Color color) {
    return Column(
      children: [
        Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  void _showOptions(DateTime date) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.cancel, color: Colors.red),
                title: const Text("No Milk (Skipped)"),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _saveMilkRecord(
                    date: date,
                    actualMilkQuantity: 0,
                    extraMilk: 0,
                    status: 'skipped',
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.orange),
                title: const Text("Edit Normal Milk (Take Less / Normal)"),
                onTap: () {
                  Navigator.pop(ctx);
                  _showEditMilkDialog(date);
                },
              ),
              ListTile(
                leading: const Icon(Icons.add_circle, color: Colors.blue),
                title: const Text("Extra Milk"),
                onTap: () {
                  Navigator.pop(ctx);
                  _showExtraMilkDialog(date);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditMilkDialog(DateTime date) {
    final controller = TextEditingController();
    final key = _dateKey(date);
    final existing = milkMap[key];
    final currentActual = existing?.actualMilkQuantity ??
        existing?.milkQuantity ??
        widget.customer.milkQuantity;

    controller.text = currentActual.toString();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Normal Milk"),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: "Enter actual milk taken",
            labelText: "Milk Quantity (Liters)",
            helperText: "Normal daily quantity: ${widget.customer.milkQuantity} L",
          ),
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            child: const Text("Save"),
            onPressed: () async {
              final actual = double.tryParse(controller.text.trim());
              if (actual == null || actual < 0) return;

              if (actual > widget.customer.milkQuantity) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Use Extra Milk option if quantity exceeds normal daily limit.",
                      ),
                    ),
                  );
                }
                return;
              }

              Navigator.pop(ctx);
              await _saveMilkRecord(
                date: date,
                actualMilkQuantity: actual,
                extraMilk: existing?.extraMilk ?? 0,
                status: actual == 0 ? 'skipped' : 'taken',
              );
            },
          ),
        ],
      ),
    );
  }

  void _showExtraMilkDialog(DateTime date) {
    final controller = TextEditingController();
    final key = _dateKey(date);
    final existing = milkMap[key];

    controller.text = (existing?.extraMilk ?? 0).toString();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Enter Extra Milk Quantity"),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            hintText: "Extra Milk in Liters",
            labelText: "Extra Milk (Liters)",
          ),
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            child: const Text("Save"),
            onPressed: () async {
              final extra = double.tryParse(controller.text.trim());
              if (extra == null || extra < 0) return;

              final actualMilk = existing?.actualMilkQuantity ??
                  existing?.milkQuantity ??
                  widget.customer.milkQuantity;

              Navigator.pop(ctx);
              await _saveMilkRecord(
                date: date,
                actualMilkQuantity: actualMilk,
                extraMilk: extra,
                status: actualMilk == 0 && extra == 0 ? 'skipped' : 'taken',
              );
            },
          ),
        ],
      ),
    );
  }
}
