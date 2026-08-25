class MilkRecord {
  int? id;
  int customerId;
  String date;
  double milkQuantity; // default/planned milk quantity
  double? actualMilkQuantity; // actual milk taken that day
  double extraMilk;
  String status; // taken, skipped

  MilkRecord({
    this.id,
    required this.customerId,
    required this.date,
    required this.milkQuantity,
    this.actualMilkQuantity,
    required this.extraMilk,
    required this.status,
  });

  double get effectiveMilkQuantity {
    if (status == 'skipped') return 0.0;
    return actualMilkQuantity ?? milkQuantity;
  }

  MilkRecord copyWith({
    int? id,
    int? customerId,
    String? date,
    double? milkQuantity,
    double? actualMilkQuantity,
    double? extraMilk,
    String? status,
  }) {
    return MilkRecord(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      date: date ?? this.date,
      milkQuantity: milkQuantity ?? this.milkQuantity,
      actualMilkQuantity: actualMilkQuantity ?? this.actualMilkQuantity,
      extraMilk: extraMilk ?? this.extraMilk,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerId': customerId,
      'date': date,
      'milkQuantity': milkQuantity,
      'actualMilkQuantity': actualMilkQuantity,
      'extraMilk': extraMilk,
      'status': status,
    };
  }

  factory MilkRecord.fromMap(Map<String, dynamic> map) {
    return MilkRecord(
      id: map['id'],
      customerId: map['customerId'],
      date: map['date'],
      milkQuantity: ((map['milkQuantity'] ?? 0) as num).toDouble(),
      actualMilkQuantity: map['actualMilkQuantity'] == null
          ? null
          : (map['actualMilkQuantity'] as num).toDouble(),
      extraMilk: ((map['extraMilk'] ?? 0) as num).toDouble(),
      status: map['status'] ?? 'taken',
    );
  }
}