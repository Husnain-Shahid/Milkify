import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarScreen extends StatefulWidget {
  final int customerId;

  CalendarScreen({required this.customerId});

  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime selectedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Milk Tracking")),
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

              showOptions(selected);
            },
          ),

        ],
      ),
    );
  }

  void showOptions(DateTime date) {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            ListTile(
              title: Text("Normal Milk"),
              onTap: () {
                saveRecord(date, "taken", 0);
              },
            ),

            ListTile(
              title: Text("No Milk"),
              onTap: () {
                saveRecord(date, "skipped", 0);
              },
            ),

            ListTile(
              title: Text("Extra Milk"),
              onTap: () {
                saveExtraMilk(date);
              },
            ),

          ],
        );
      },
    );
  }

  void saveRecord(DateTime date, String status, double extra) {
    print("Saved: $status");
    Navigator.pop(context);
  }

  void saveExtraMilk(DateTime date) {
    print("Extra milk clicked");
  }
}