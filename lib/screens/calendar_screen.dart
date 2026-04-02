import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../database/db_helper.dart';
import '../models/customer_model.dart';
import '../models/milk_record_model.dart';
import 'bill_screen.dart';

class CalendarScreen extends StatefulWidget {
  final Customer customer;

  CalendarScreen({required this.customer});

  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime selectedDay = DateTime.now();
  DBHelper dbHelper = DBHelper();
  Map<DateTime, MilkRecord> milkMap = {};

  @override
  void initState() {
    super.initState();
    _loadMilkRecords();
  }

  DateTime _normalizeDate(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  void _loadMilkRecords() async {
    List<MilkRecord> records = await dbHelper.getRecords(widget.customer.id!);
    setState(() {
      milkMap = {for (var r in records) _normalizeDate(DateTime.parse(r.date)): r};
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.customer.name} - Milk Tracker"),
        actions: [
          IconButton(
            icon: Icon(Icons.receipt),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MonthlyBillScreen(customer: widget.customer),
                ),
              );
            },
          )
        ],
      ),
      body: TableCalendar(
        firstDay: DateTime.utc(2023, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: DateTime.now(),
        selectedDayPredicate: (day) => isSameDay(day, selectedDay),
        onDaySelected: (selected, focused) {
          setState(() => selectedDay = selected);
          _showOptions(selectedDay);
        },
        calendarBuilders: CalendarBuilders(
          defaultBuilder: (context, day, focusedDay) {
            final nDay = _normalizeDate(day);
            if (milkMap.containsKey(nDay)) {
              MilkRecord r = milkMap[nDay]!;
              Color color = r.status == 'skipped'
                  ? Colors.red
                  : (r.extraMilk > 0 ? Colors.blue : Colors.green);
              return Container(
                decoration: BoxDecoration(
                  color: color.withOpacity(0.6),
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
    );
  }

  void _showOptions(DateTime date) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text("Normal Milk"),
            onTap: () => _saveRecord(date, status: "taken", extraMilk: 0),
          ),
          ListTile(
            title: Text("No Milk"),
            onTap: () => _saveRecord(date, status: "skipped", extraMilk: 0),
          ),
          ListTile(
            title: Text("Extra Milk"),
            onTap: () {
              Navigator.pop(context);
              _showExtraMilkDialog(date);
            },
          ),
        ],
      ),
    );
  }

  void _showExtraMilkDialog(DateTime date) {
    final extraController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Enter Extra Milk Quantity"),
        content: TextField(
          controller: extraController,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(hintText: "Liters"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel")),
          ElevatedButton(
            child: Text("Save"),
            onPressed: () {
              double? extra = double.tryParse(extraController.text);
              if (extra != null) {
                _saveRecord(date, status: "taken", extraMilk: extra);
                Navigator.pop(context);
              }
            },
          )
        ],
      ),
    );
  }

  void _saveRecord(DateTime date, {required String status, required double extraMilk}) async {
    MilkRecord record = MilkRecord(
      customerId: widget.customer.id!,
      date: _normalizeDate(date).toIso8601String().split('T')[0],
      milkQuantity: widget.customer.milkQuantity,
      extraMilk: extraMilk,
      status: status,
    );

    await dbHelper.insertMilkRecord(record);
    _loadMilkRecords();
    Navigator.pop(context); // close bottom sheet
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Record saved")));
  }
}