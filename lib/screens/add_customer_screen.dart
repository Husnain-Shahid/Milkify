import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/customer_model.dart';

class AddCustomerScreen extends StatefulWidget {
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Add Customer")),
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
              decoration: InputDecoration(labelText: "Milk Quantity (Liter)"),
            ),

            TextField(
              controller: priceController,
              decoration: InputDecoration(labelText: "Price per Liter"),
            ),

            SizedBox(height: 20),

            DropdownButton<String>(
              value: time,
              items: ["Morning", "Evening", "Both"]
                  .map((e) => DropdownMenuItem(
                child: Text(e),
                value: e,
              ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  time = value!;
                });
              },
            ),

            SizedBox(height: 20),

            ElevatedButton(
              child: Text("Save Customer"),
              onPressed: () async {
                if (nameController.text.isEmpty ||
                    milkController.text.isEmpty ||
                    priceController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Please fill all required fields")),
                  );
                  return;
                }

                Customer customer = Customer(
                  name: nameController.text,
                  phone: phoneController.text,
                  address: addressController.text,
                  milkQuantity: double.parse(milkController.text),
                  pricePerLiter: double.parse(priceController.text),
                  time: time,
                );

                await DBHelper().insertCustomer(customer);

                Navigator.pop(context);
              },
            )
          ],
        ),
      ),
    );
  }
}