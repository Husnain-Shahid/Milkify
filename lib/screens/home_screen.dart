import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/customer_model.dart';
import 'add_customer_screen.dart';
import 'calendar_screen.dart';
import 'bill_screen.dart';
import 'income_dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Customer> customers = [];
  List<Customer> filteredCustomers = [];
  final searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadCustomers();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void loadCustomers() async {
    customers = await DBHelper().getCustomers();
    filteredCustomers = List.from(customers);
    setState(() {});
  }

  void filterCustomers(String query) {
    final q = query.toLowerCase();
    setState(() {
      filteredCustomers = customers.where((c) {
        return c.name.toLowerCase().contains(q) ||
            c.phone.toLowerCase().contains(q);
      }).toList();
    });
  }

  void _deleteCustomer(int id) async {
    await DBHelper().deleteCustomer(id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Customer deleted")),
    );
    loadCustomers();
  }

  void _editCustomer(Customer customer) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddCustomerScreen(customer: customer),
      ),
    );
    loadCustomers();
  }

  void _openBill(Customer customer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MonthlyBillScreen(customer: customer),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddCustomerScreen(),
            ),
          );
          loadCustomers();
        },
        icon: Icon(Icons.add),
        label: Text("Add Customer"),
      ),
      appBar: AppBar(
        title: Text("Milk Customers"),
        actions: [
          IconButton(
            icon: Icon(Icons.account_balance_wallet_outlined),
            tooltip: "Income Dashboard",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => IncomeDashboardScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade700, Colors.blue.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Milk Customers",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "${customers.length} total customers",
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TextField(
                      controller: searchController,
                      onChanged: filterCustomers,
                      decoration: InputDecoration(
                        hintText: "Search customer...",
                        prefixIcon: Icon(Icons.search),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: filteredCustomers.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 80,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 12),
                    Text(
                      "No Customers Found",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Tap + to add your first customer",
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: filteredCustomers.length,
                itemBuilder: (context, index) {
                  var c = filteredCustomers[index];
                  return Card(
                    elevation: 4,
                    margin: EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.all(16),
                      leading: CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.blue.shade100,
                        child: Text(
                          c.name.isNotEmpty
                              ? c.name[0].toUpperCase()
                              : "?",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ),
                      title: Text(
                        c.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${c.milkQuantity} L | Rs ${c.pricePerLiter}",
                            ),
                            Text("Phone: ${c.phone}"),
                          ],
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.receipt),
                            tooltip: "Monthly Bill",
                            onPressed: () => _openBill(c),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == "edit") {
                                _editCustomer(c);
                              } else if (value == "delete") {
                                showDialog(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: Text("Delete Customer"),
                                    content: Text(
                                      "Are you sure you want to delete ${c.name}?",
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context),
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
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: "edit",
                                child: Text("Edit Customer"),
                              ),
                              PopupMenuItem(
                                value: "delete",
                                child: Text("Delete Customer"),
                              ),
                            ],
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                CalendarScreen(customer: c),
                          ),
                        );
                      },
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
}
