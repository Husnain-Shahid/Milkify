class MilkRecord {
  int? id;
  int customerId;
  String date;
  double milkQuantity;
  double extraMilk;
  String status; // taken, skipped

  MilkRecord({
    this.id,
    required this.customerId,
    required this.date,
    required this.milkQuantity,
    required this.extraMilk,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerId': customerId,
      'date': date,
      'milkQuantity': milkQuantity,
      'extraMilk': extraMilk,
      'status': status,
    };
  }

  factory MilkRecord.fromMap(Map<String, dynamic> map) {
    return MilkRecord(
      id: map['id'],
      customerId: map['customerId'],
      date: map['date'],
      milkQuantity: map['milkQuantity'],
      extraMilk: map['extraMilk'],
      status: map['status'],
    );
  }
}