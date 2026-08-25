import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/customer_model.dart';
import '../widgets/customer_tile.dart';
import 'add_customer_screen.dart';
import 'calendar_screen.dart';
import 'bill_screen.dart';
import 'income_dashboard_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Customer> customers = [];
  List<Customer> filteredCustomers = [];
  final searchController = TextEditingController();

  String selectedTimeFilter = "All";
  bool isLoading = true;

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
    setState(() {
      isLoading = true;
    });
    final fetched = await DBHelper().getCustomers();
    if (!mounted) return;
    setState(() {
      customers = fetched;
      isLoading = false;
    });
    _applyFilters();
  }



  double get totalDailyMilk =>
      customers.fold(0.0, (sum, c) => sum + c.milkQuantity);

  void _applyFilters() {
    final q = searchController.text.toLowerCase().trim();

    setState(() {
      filteredCustomers = customers.where((c) {
        final matchesSearch = q.isEmpty ||
            c.name.toLowerCase().contains(q) ||
            c.phone.toLowerCase().contains(q) ||
            c.address.toLowerCase().contains(q) ||
            c.time.toLowerCase().contains(q);

        final matchesTime = selectedTimeFilter == "All" ||
            c.time.toLowerCase() == selectedTimeFilter.toLowerCase();

        return matchesSearch && matchesTime;
      }).toList();
    });
  }

  void filterCustomers(String query) {
    _applyFilters();
  }

  void _setTimeFilter(String filter) {
    setState(() {
      selectedTimeFilter = filter;
    });
    _applyFilters();
  }

  void _deleteCustomer(Customer customer) async {
    if (customer.id == null) return;
    await DBHelper().deleteCustomer(customer.id!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("${customer.name} and related records deleted")),
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

  void _openBill(Customer customer) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MonthlyBillScreen(customer: customer),
      ),
    );
    loadCustomers();
  }

  void _openCalendar(Customer customer) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CalendarScreen(customer: customer),
      ),
    );
    loadCustomers();
  }

  void _confirmDelete(Customer customer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Customer"),
        content: Text(
          "Are you sure you want to delete ${customer.name}? All associated milk and bill records will be deleted.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _deleteCustomer(customer);
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }



  Widget _buildFilterChip(String label, IconData? icon) {
    final isSelected = selectedTimeFilter == label;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        avatar: icon != null
            ? Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : Colors.blue.shade800,
              )
            : null,
        label: Text(label),
        selected: isSelected,
        showCheckmark: false,
        onSelected: (_) => _setTimeFilter(label),
        selectedColor: Colors.blue.shade900,
        backgroundColor: Colors.white.withValues(alpha: 0.9),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.blue.shade900,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? Colors.transparent : Colors.white.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddCustomerScreen(),
            ),
          );
          loadCustomers();
        },
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.person_add_alt_1, size: 20),
        label: const Text(
          "Add Customer",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        title: const Text(
          "Milk Customers",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet),
            tooltip: "Income Dashboard",
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const IncomeDashboardScreen(),
                ),
              );
              loadCustomers();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Header Container
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade800, Colors.blue.shade600],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(26),
                  bottomRight: Radius.circular(26),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.shade900.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick Insights Badges
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.people, size: 15, color: Colors.white),
                            const SizedBox(width: 5),
                            Text(
                              "${customers.length} Customers",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.local_drink, size: 15, color: Colors.white),
                            const SizedBox(width: 5),
                            Text(
                              "${totalDailyMilk.toStringAsFixed(1)} L/day",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: searchController,
                      onChanged: filterCustomers,
                      decoration: InputDecoration(
                        hintText: "Search name, phone, address...",
                        hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                        prefixIcon: Icon(Icons.search, color: Colors.blue.shade700),
                        suffixIcon: searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                color: Colors.grey.shade600,
                                onPressed: () {
                                  searchController.clear();
                                  filterCustomers("");
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Delivery Timing Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip("All", null),
                        _buildFilterChip("Morning", Icons.wb_sunny_outlined),
                        _buildFilterChip("Evening", Icons.nights_stay_outlined),
                        _buildFilterChip("Both", Icons.schedule),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Customer List View
            Expanded(
              child: isLoading

                  ? const Center(child: CircularProgressIndicator())
                  : filteredCustomers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.people_outline,
                                  size: 48,
                                  color: Colors.blue.shade400,
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                "No Customers Found",
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                searchController.text.isNotEmpty
                                    ? "No match for '${searchController.text}'"
                                    : "Tap '+ Add Customer' to add your first customer",
                                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: filteredCustomers.length,
                          itemBuilder: (context, index) {
                            var c = filteredCustomers[index];
                            return CustomerTile(
                              customer: c,
                              onTap: () => _openCalendar(c),
                              onBillTap: () => _openBill(c),
                              onEdit: () => _editCustomer(c),
                              onDelete: () => _confirmDelete(c),
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

