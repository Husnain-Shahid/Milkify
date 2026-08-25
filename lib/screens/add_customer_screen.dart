import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/customer_model.dart';

class AddCustomerScreen extends StatefulWidget {
  final Customer? customer;

  const AddCustomerScreen({super.key, this.customer});

  @override
  State<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();
  final milkController = TextEditingController();
  final priceController = TextEditingController();

  final List<String> availableTimes = const ["Morning", "Evening", "Both"];
  String time = "Morning";

  @override
  void initState() {
    super.initState();

    if (widget.customer != null) {
      nameController.text = widget.customer!.name;
      phoneController.text = widget.customer!.phone;
      addressController.text = widget.customer!.address;
      milkController.text = widget.customer!.milkQuantity.toString();
      priceController.text = widget.customer!.pricePerLiter.toString();

      final customerTime = widget.customer!.time;
      if (availableTimes.contains(customerTime)) {
        time = customerTime;
      } else {
        time = "Morning";
      }
    }

    // Add listeners to update live calculation
    milkController.addListener(_onFieldChanged);
    priceController.addListener(_onFieldChanged);
    nameController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    nameController.removeListener(_onFieldChanged);
    priceController.removeListener(_onFieldChanged);
    milkController.removeListener(_onFieldChanged);
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    milkController.dispose();
    priceController.dispose();
    super.dispose();
  }

  double get _estimatedDailyCost {
    final qty = double.tryParse(milkController.text.trim()) ?? 0.0;
    final price = double.tryParse(priceController.text.trim()) ?? 0.0;
    return qty * price;
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditMode = widget.customer != null;
    final name = nameController.text.trim();

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode ? "Edit Customer" : "Add New Customer"),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero Preview Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade700, Colors.indigo.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.shade200.withValues(alpha: 0.5),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : (isEditMode ? "E" : "+"),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isNotEmpty ? name : (isEditMode ? "Customer Details" : "New Customer"),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                "Time: $time",
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (_estimatedDailyCost > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade400,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  "Rs ${_estimatedDailyCost.toStringAsFixed(0)}/day",
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Section 1: Personal & Contact Information Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person_pin, size: 20, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          "Contact Information",
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: "Customer Name *",
                        hintText: "Enter full name",
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: "Phone Number",
                        hintText: "e.g. 03001234567",
                        prefixIcon: const Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: addressController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: "Delivery Address",
                        hintText: "Street, house number, area...",
                        prefixIcon: const Icon(Icons.location_on_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Section 2: Milk Quantity & Rate Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.local_drink_outlined, size: 20, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          "Milk Quantity & Pricing",
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: milkController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: "Daily Quantity *",
                              hintText: "e.g. 2.0",
                              suffixText: "L/day",
                              prefixIcon: const Icon(Icons.water_drop_outlined),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: priceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: "Price / Liter *",
                              hintText: "e.g. 200",
                              suffixText: "Rs/L",
                              prefixIcon: const Icon(Icons.currency_rupee),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Section 3: Delivery Timing Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 20, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          "Preferred Delivery Timing",
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      children: availableTimes.map((t) {
                        final isSelected = time == t;
                        IconData timingIcon;
                        if (t == "Morning") {
                          timingIcon = Icons.wb_sunny_outlined;
                        } else if (t == "Evening") {
                          timingIcon = Icons.nights_stay_outlined;
                        } else {
                          timingIcon = Icons.schedule;
                        }

                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ChoiceChip(
                              avatar: Icon(
                                timingIcon,
                                size: 16,
                                color: isSelected ? Colors.blue.shade900 : Colors.grey.shade700,
                              ),
                              label: Text(t),
                              selected: isSelected,
                              selectedColor: Colors.blue.shade100,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    time = t;
                                  });
                                }
                              },
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Save / Update Action Button
            ElevatedButton.icon(
              icon: Icon(isEditMode ? Icons.check_circle : Icons.save, size: 20),
              label: Text(
                isEditMode ? "Update Customer" : "Save Customer",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 3,
              ),
              onPressed: _saveCustomer,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _saveCustomer() async {
    String name = nameController.text.trim();
    String milkText = milkController.text.trim();
    String priceText = priceController.text.trim();

    if (name.isEmpty || milkText.isEmpty || priceText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all required fields (*)")),
      );
      return;
    }

    double? milk = double.tryParse(milkText);
    double? price = double.tryParse(priceText);

    if (milk == null || price == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter valid numbers (e.g. 1.5)")),
      );
      return;
    }

    if (milk <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Milk quantity must be greater than 0")),
      );
      return;
    }

    if (price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Price cannot be negative")),
      );
      return;
    }

    try {
      final dbHelper = DBHelper();
      Customer customer = Customer(
        id: widget.customer?.id,
        name: name,
        phone: phoneController.text.trim(),
        address: addressController.text.trim(),
        milkQuantity: milk,
        pricePerLiter: price,
        time: time,
        createdAt: widget.customer?.createdAt ?? DateTime.now().toIso8601String(),
      );

      if (widget.customer != null) {
        await dbHelper.updateCustomer(customer);
      } else {
        int newId = await dbHelper.insertCustomer(customer);
        customer.id = newId;
        await dbHelper.ensureTodayMilk(newId, milk);
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving customer: $e")),
      );
    }
  }
}




