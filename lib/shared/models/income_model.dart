class IncomeModel {
  final String id;
  final String title;
  final String categoryId;
  final double amount;
  final DateTime transactionDate;
  final DateTime createdAt;
  final String? note;
  final bool isRecurring;

  const IncomeModel({
    required this.id,
    required this.title,
    required this.categoryId,
    required this.amount,
    required this.transactionDate,
    required this.createdAt,
    required this.isRecurring,
    this.note,
  });

  IncomeModel copyWith({
    String? id,
    String? title,
    String? categoryId,
    double? amount,
    DateTime? transactionDate,
    DateTime? createdAt,
    String? note,
    bool? isRecurring,
  }) {
    // Diese Methode erstellt eine Kopie mit geänderten Werten.
    return IncomeModel(
      id: id ?? this.id,
      title: title ?? this.title,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      transactionDate: transactionDate ?? this.transactionDate,
      createdAt: createdAt ?? this.createdAt,
      note: note ?? this.note,
      isRecurring: isRecurring ?? this.isRecurring,
    );
  }

  factory IncomeModel.fromMap(Map<String, dynamic> map) {
    // Diese Methode erstellt ein IncomeModel aus einer Datenbank-Map.
    return IncomeModel(
      id: map['id'] as String,
      title: map['title'] as String,
      categoryId: map['categoryId'] as String,
      amount: (map['amount'] as num).toDouble(),
      transactionDate: DateTime.parse(map['transactionDate'] as String),
      createdAt: DateTime.parse(map['createdAt'] as String),
      note: map['note'] as String?,
      isRecurring: map['isRecurring'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    // Diese Methode wandelt das IncomeModel in eine Datenbank-Map um.
    return {
      'id': id,
      'title': title,
      'categoryId': categoryId,
      'amount': amount,
      'transactionDate': transactionDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'note': note,
      'isRecurring': isRecurring,
    };
  }
}
