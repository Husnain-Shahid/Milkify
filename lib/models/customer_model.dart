class Customer {
  int? id;
  String name;
  String phone;
  String address;
  double milkQuantity;
  double pricePerLiter;
  String time;
  String createdAt;

  Customer({
    this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.milkQuantity,
    required this.pricePerLiter,
    required this.time,
    required this.createdAt,
  });

  Customer copyWith({
    int? id,
    String? name,
    String? phone,
    String? address,
    double? milkQuantity,
    double? pricePerLiter,
    String? time,
    String? createdAt,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      milkQuantity: milkQuantity ?? this.milkQuantity,
      pricePerLiter: pricePerLiter ?? this.pricePerLiter,
      time: time ?? this.time,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'milkQuantity': milkQuantity,
      'pricePerLiter': pricePerLiter,
      'time': time,
      'createdAt': createdAt,
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'],
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      milkQuantity: ((map['milkQuantity'] ?? 0) as num).toDouble(),
      pricePerLiter: ((map['pricePerLiter'] ?? 0) as num).toDouble(),
      time: map['time'] ?? 'Morning',
      createdAt: map['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
    );
  }
}
