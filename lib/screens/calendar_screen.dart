import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../database/db_helper.dart';
import '../models/customer_model.dart';
import '../models/milk_record_model.dart';

class CalendarScreen extends StatefulWidget {
  final Customer customer;

  CalendarScreen({required this.customer});

  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime selectedDay = DateTime.now();
  final DBHelper dbHelper = DBHelper();
  Map<String, MilkRecord> milkMap = {}; // key = YYYY-MM-DD

  @override
  void initState() {
    super.initState();
    _loadMilkRecords();
  }

  String _dateKey(DateTime date) {
    return date.toIso8601String().split('T')[0];
  }

  Future<void> _loadMilkRecords() async {
    final records = await dbHelper.getRecords(widget.customer.id!);
    final today = DateTime.now().toIso8601String().split('T')[0];

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Milk Tracking - ${widget.customer.name}")),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2023, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: DateTime.now(),
            selectedDayPredicate: (day) => isSameDay(day, selectedDay),
            onDaySelected: (selected, focused) {
              setState(() {
                selectedDay = selected;
              });
              _showOptions(selectedDay);
            },
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, focusedDay) {
                final key = _dateKey(day);
                if (milkMap.containsKey(key)) {
                  final r = milkMap[key]!;
                  final actual = r.effectiveMilkQuantity;

                  Color color;
                  if (r.status == 'skipped') {
                    color = Colors.red;
                  } else if (actual < r.milkQuantity) {
                    color = Colors.orange;
                  } else if (r.extraMilk > 0) {
                    color = Colors.blue;
                  } else {
                    color = Colors.green;
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text('${day.day}'),
                  );
                }
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showOptions(DateTime date) {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text("No Milk"),
              onTap: () async {
                Navigator.pop(context);
                await _saveMilkRecord(
                  date: date,
                  actualMilkQuantity: 0,
                  extraMilk: 0,
                  status: 'skipped',
                );
              },
            ),
            ListTile(
              title: Text("Edit Milk"),
              onTap: () {
                Navigator.pop(context);
                _showEditMilkDialog(date);
              },
            ),
            ListTile(
              title: Text("Extra Milk"),
              onTap: () {
                Navigator.pop(context);
                _showExtraMilkDialog(date);
              },
            ),
          ],
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
      builder: (_) => AlertDialog(
        title: Text("Edit Normal Milk"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: "Enter actual milk taken",
          ),
        ),
        actions: [
          TextButton(
            child: Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: Text("Save"),
            onPressed: () async {
              final actual = double.tryParse(controller.text.trim());
              if (actual == null || actual < 0) return;

              if (actual > widget.customer.milkQuantity) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      "Use Extra Milk if quantity is more than normal.",
                    ),
                  ),
                );
                return;
              }

              Navigator.pop(context);
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
      builder: (_) => AlertDialog(
        title: Text("Enter Extra Milk Quantity"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(hintText: "Extra Milk in Liters"),
        ),
        actions: [
          TextButton(
            child: Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: Text("Save"),
            onPressed: () async {
              final extra = double.tryParse(controller.text.trim());
              if (extra == null || extra < 0) return;

              final actualMilk = existing?.actualMilkQuantity ??
                  existing?.milkQuantity ??
                  widget.customer.milkQuantity;

              Navigator.pop(context);
              await _saveMilkRecord(
                date: date,
                actualMilkQuantity: actualMilk,
                extraMilk: extra,
                status: actualMilk == 0 ? 'skipped' : 'taken',
              );
            },
          ),
        ],
      ),
    );
  }
}
