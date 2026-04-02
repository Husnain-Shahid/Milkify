import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/customer_model.dart';
import 'add_customer_screen.dart';

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
            title: Text(c.name),
            subtitle: Text("${c.milkQuantity} L | Rs ${c.pricePerLiter}"),
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