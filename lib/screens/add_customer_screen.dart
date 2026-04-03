import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/customer_model.dart';

class AddCustomerScreen extends StatefulWidget {
  final Customer? customer;

  AddCustomerScreen({this.customer});

  @override
  _AddCustomerScreenState createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();
  final milkController = TextEditingController();
  final priceController = TextEditingController();

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
      time = widget.customer!.time;
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    milkController.dispose();
    priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditMode = widget.customer != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEditMode ? "Edit Customer" : "Add Customer")),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: "Customer Name"),
            ),
            TextField(
              controller: phoneController,
              decoration: InputDecoration(labelText: "Phone"),
            ),
            TextField(
              controller: addressController,
              decoration: InputDecoration(labelText: "Address"),
            ),
            TextField(
              controller: milkController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: "Milk Quantity"),
            ),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: "Price per Liter"),
            ),
            SizedBox(height: 20),
            DropdownButton<String>(
              value: time,
              items: ["Morning", "Evening", "Both"]
                  .map(
                    (e) => DropdownMenuItem(
                  child: Text(e),
                  value: e,
                ),
              )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  time = value!;
                });
              },
            ),
            SizedBox(height: 20),
            ElevatedButton(
              child: Text(isEditMode ? "Update Customer" : "Save Customer"),
              onPressed: () async {
                String name = nameController.text.trim();
                String milkText = milkController.text.trim();
                String priceText = priceController.text.trim();

                if (name.isEmpty || milkText.isEmpty || priceText.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Please fill all fields")),
                  );
                  return;
                }

                double? milk = double.tryParse(milkText);
                double? price = double.tryParse(priceText);

                if (milk == null || price == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Enter valid numbers (e.g. 1.5)")),
                  );
                  return;
                }

                try {
                  Customer customer = Customer(
                    id: widget.customer?.id,
                    name: name,
                    phone: phoneController.text,
                    address: addressController.text,
                    milkQuantity: milk,
                    pricePerLiter: price,
                    time: time,
                    createdAt: widget.customer?.createdAt ?? DateTime.now().toIso8601String(),
                  );

                  if (isEditMode) {
                    await DBHelper().updateCustomer(customer);
                  } else {
                    await DBHelper().insertCustomer(customer);
                  }

                  Navigator.pop(context);
                } catch (e) {
                  print("ERROR: $e");
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error saving customer")),
                  );
                }
              },
            )
          ],
        ),
      ),
    );
  }
}
