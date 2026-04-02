import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/customer_model.dart';
import 'add_customer_screen.dart';
import 'calendar_screen.dart';
import 'bill_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Customer> customers = [];

  @override
  void initState() {
    super.initState();
    loadCustomers();
  }

  void loadCustomers() async {
    customers = await DBHelper().getCustomers();
    setState(() {});
  }

  void _deleteCustomer(int id) async {
    await DBHelper().deleteCustomer(id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Customer deleted")),
    );
    loadCustomers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Milk Customers")),
      body: customers.isEmpty
          ? Center(child: Text("No Customers Found"))
          : ListView.builder(
        itemCount: customers.length,
        itemBuilder: (context, index) {
          var c = customers[index];
          return ListTile(
            leading: Icon(Icons.person,size: 50),
            title: Text(c.name,style: TextStyle(fontWeight: FontWeight.bold),),
            subtitle: Text("${c.milkQuantity} L | Rs ${c.pricePerLiter}"),
            onTap: () {
              // Open CalendarScreen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CalendarScreen(customer: c),
                ),
              );
            },
            trailing: IconButton(
              icon: Icon(Icons.receipt),
              tooltip: "Monthly Bill",
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MonthlyBillScreen(customer: c),
                  ),
                );
              },
            ),
            onLongPress: () {
              // Confirm deletion
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text("Delete Customer"),
                  content: Text("Are you sure you want to delete ${c.name}?"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text("Cancel"),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _deleteCustomer(c.id!);
                      },
                      child: Text("Delete"),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddCustomerScreen(),
            ),
          );
          loadCustomers(); // refresh after adding
        },
      ),
    );
  }
}