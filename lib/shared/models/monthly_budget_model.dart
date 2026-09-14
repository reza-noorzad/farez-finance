class MonthlyBudgetModel {
  final String id;
  final String categoryId;
  final DateTime monthDate;
  final double amount;
  final DateTime createdAt;

  const MonthlyBudgetModel({
    required this.id,
    required this.categoryId,
    required this.monthDate,
    required this.amount,
    required this.createdAt,
  });

  MonthlyBudgetModel copyWith({
    String? id,
    String? categoryId,
    DateTime? monthDate,
    double? amount,
    DateTime? createdAt,
  }) {
    return MonthlyBudgetModel(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      monthDate: monthDate ?? this.monthDate,
      amount: amount ?? this.amount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
