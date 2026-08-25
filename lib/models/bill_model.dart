class BillRecord {
  int? id;
  int customerId;
  String billMonth; // format: yyyy-MM
  double totalAmount;
  double collectedAmount; // Amount actually collected from customer
  double dueAmount;
  bool isPaid;
  String? paymentDate;
  String createdAt;

  BillRecord({
    this.id,
    required this.customerId,
    required this.billMonth,
    required this.totalAmount,
    this.collectedAmount = 0.0,
    required this.dueAmount,
    required this.isPaid,
    this.paymentDate,
    required this.createdAt,
  });

  BillRecord copyWith({
    int? id,
    int? customerId,
    String? billMonth,
    double? totalAmount,
    double? collectedAmount,
    double? dueAmount,
    bool? isPaid,
    String? paymentDate,
    String? createdAt,
  }) {
    return BillRecord(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      billMonth: billMonth ?? this.billMonth,
      totalAmount: totalAmount ?? this.totalAmount,
      collectedAmount: collectedAmount ?? this.collectedAmount,
      dueAmount: dueAmount ?? this.dueAmount,
      isPaid: isPaid ?? this.isPaid,
      paymentDate: paymentDate ?? this.paymentDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerId': customerId,
      'billMonth': billMonth,
      'totalAmount': totalAmount,
      'collectedAmount': collectedAmount,
      'dueAmount': dueAmount,
      'isPaid': isPaid ? 1 : 0,
      'paymentDate': paymentDate,
      'createdAt': createdAt,
    };
  }

  factory BillRecord.fromMap(Map<String, dynamic> map) {
    return BillRecord(
      id: map['id'],
      customerId: map['customerId'],
      billMonth: map['billMonth'],
      totalAmount: (map['totalAmount'] as num).toDouble(),
      collectedAmount: ((map['collectedAmount'] ?? 0) as num).toDouble(),
      dueAmount: (map['dueAmount'] as num).toDouble(),
      isPaid: map['isPaid'] == 1,
      paymentDate: map['paymentDate'],
      createdAt: map['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
    );
  }
}
