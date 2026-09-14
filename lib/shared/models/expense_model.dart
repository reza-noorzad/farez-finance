import 'expense_item_model.dart';

class ExpenseModel {
  final String id;
  final String title;
  final String categoryId;
  final double amount;
  final DateTime transactionDate;
  final DateTime createdAt;
  final String? storeName;
  final String? note;
  final bool isRecurring;
  final List<ExpenseItemModel> items;

  const ExpenseModel({
    required this.id,
    required this.title,
    required this.categoryId,
    required this.amount,
    required this.transactionDate,
    required this.createdAt,
    required this.isRecurring,
    required this.items,
    this.storeName,
    this.note,
  });

  ExpenseModel copyWith({
    String? id,
    String? title,
    String? categoryId,
    double? amount,
    DateTime? transactionDate,
    DateTime? createdAt,
    String? storeName,
    String? note,
    bool? isRecurring,
    List<ExpenseItemModel>? items,
  }) {
    // Diese Methode erstellt eine Kopie mit geänderten Werten.
    return ExpenseModel(
      id: id ?? this.id,
      title: title ?? this.title,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      transactionDate: transactionDate ?? this.transactionDate,
      createdAt: createdAt ?? this.createdAt,
      storeName: storeName ?? this.storeName,
      note: note ?? this.note,
      isRecurring: isRecurring ?? this.isRecurring,
      items: items ?? this.items,
    );
  }

  factory ExpenseModel.fromMap(Map<String, dynamic> map) {
    // Diese Methode erstellt ein ExpenseModel aus einer Datenbank-Map.
    return ExpenseModel(
      id: map['id'] as String,
      title: map['title'] as String,
      categoryId: map['categoryId'] as String,
      amount: (map['amount'] as num).toDouble(),
      transactionDate: DateTime.parse(map['transactionDate'] as String),
      createdAt: DateTime.parse(map['createdAt'] as String),
      storeName: map['storeName'] as String?,
      note: map['note'] as String?,
      isRecurring: map['isRecurring'] as bool? ?? false,
      items: const [],
    );
  }

  Map<String, dynamic> toMap() {
    // Diese Methode wandelt das ExpenseModel in eine Datenbank-Map um.
    return {
      'id': id,
      'title': title,
      'categoryId': categoryId,
      'amount': amount,
      'transactionDate': transactionDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'storeName': storeName,
      'note': note,
      'isRecurring': isRecurring,
    };
  }
}
