class Customer {
  int? id;
  String name;
  String phone;
  String address;
  double milkQuantity;
  double pricePerLiter;
  String time;

  Customer({
    this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.milkQuantity,
    required this.pricePerLiter,
    required this.time,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'milkQuantity': milkQuantity,
      'pricePerLiter': pricePerLiter,
      'time': time,
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'],
      name: map['name'],
      phone: map['phone'],
      address: map['address'],
      milkQuantity: map['milkQuantity'],
      pricePerLiter: map['pricePerLiter'],
      time: map['time'],
    );
  }
}