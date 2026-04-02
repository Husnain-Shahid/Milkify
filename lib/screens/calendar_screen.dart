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
  DBHelper dbHelper = DBHelper();
  Map<String, MilkRecord> milkMap = {}; // key = 'YYYY-MM-DD'

  @override
  void initState() {
    super.initState();
    _loadMilkRecords();
  }

  /// Load all records and auto-insert today's normal milk if missing
  void _loadMilkRecords() async {
    List<MilkRecord> records = await dbHelper.getRecords(widget.customer.id!);

    String today = DateTime.now().toIso8601String().split('T')[0];

    // Auto-create today's normal milk if missing
    bool hasToday = records.any((r) => r.date == today);
    if (!hasToday) {
      MilkRecord todayRecord = MilkRecord(
        customerId: widget.customer.id!,
        date: today,
        milkQuantity: widget.customer.milkQuantity,
        extraMilk: 0,
        status: 'taken', // default green
      );
      await dbHelper.insertMilkRecord(todayRecord);
      records.add(todayRecord);
    }

    setState(() {
      milkMap = {for (var r in records) r.date: r};
    });
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
                String key = day.toIso8601String().split('T')[0];
                if (milkMap.containsKey(key)) {
                  MilkRecord r = milkMap[key]!;

                  Color color;
                  if (r.status == 'skipped')
                    color = Colors.red;
                  else if (r.extraMilk > 0)
                    color = Colors.blue;
                  else
                    color = Colors.green;

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

  /// Show bottom sheet to update past or today's milk
  void _showOptions(DateTime date) {
    String key = date.toIso8601String().split('T')[0];

    showModalBottomSheet(
      context: context,
      builder: (_) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text("No Milk"),
              onTap: () async {
                MilkRecord? existing = milkMap[key];
                if (existing != null) {
                  existing.status = 'skipped';
                  existing.extraMilk = 0;
                  await dbHelper.updateMilkRecord(existing);
                } else {
                  await dbHelper.insertMilkRecord(MilkRecord(
                    customerId: widget.customer.id!,
                    date: key,
                    milkQuantity: 0,
                    extraMilk: 0,
                    status: 'skipped',
                  ));
                }
                Navigator.pop(context);
                _loadMilkRecords();
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

  /// Dialog to add extra milk
  void _showExtraMilkDialog(DateTime date) {
    final TextEditingController extraController = TextEditingController();
    String key = date.toIso8601String().split('T')[0];

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Enter Extra Milk Quantity"),
        content: TextField(
          controller: extraController,
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
              double? extra = double.tryParse(extraController.text);
              if (extra != null && extra > 0) {
                MilkRecord? existing = milkMap[key];
                if (existing != null) {
                  existing.extraMilk = extra;
                  existing.status = 'taken';
                  await dbHelper.updateMilkRecord(existing);
                } else {
                  await dbHelper.insertMilkRecord(MilkRecord(
                    customerId: widget.customer.id!,
                    date: key,
                    milkQuantity: widget.customer.milkQuantity,
                    extraMilk: extra,
                    status: 'taken',
                  ));
                }
                Navigator.pop(context);
                _loadMilkRecords();
              }
            },
          )
        ],
      ),
    );
  }
}