class SavingGoalReservationModel {
  final String id;
  final String fundId;
  final String? sourceAccountId;
  final double amount;
  final DateTime date;
  final DateTime createdAt;
  final String? note;

  const SavingGoalReservationModel({
    required this.id,
    required this.fundId,
    required this.amount,
    required this.date,
    required this.createdAt,
    this.sourceAccountId,
    this.note,
  });

  SavingGoalReservationModel copyWith({
    String? id,
    String? fundId,
    String? sourceAccountId,
    double? amount,
    DateTime? date,
    DateTime? createdAt,
    String? note,
  }) {
    return SavingGoalReservationModel(
      id: id ?? this.id,
      fundId: fundId ?? this.fundId,
      sourceAccountId: sourceAccountId ?? this.sourceAccountId,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      note: note ?? this.note,
    );
  }
}
