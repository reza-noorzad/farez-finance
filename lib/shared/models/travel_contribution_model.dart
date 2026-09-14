class TravelContributionModel {
  final String id;
  final String travelPlanId;
  final String? sourceAccountId;
  final double amount;
  final DateTime date;
  final DateTime createdAt;
  final String? note;

  const TravelContributionModel({
    required this.id,
    required this.travelPlanId,
    required this.amount,
    required this.date,
    required this.createdAt,
    this.sourceAccountId,
    this.note,
  });

  TravelContributionModel copyWith({
    String? id,
    String? travelPlanId,
    String? sourceAccountId,
    double? amount,
    DateTime? date,
    DateTime? createdAt,
    String? note,
  }) {
    return TravelContributionModel(
      id: id ?? this.id,
      travelPlanId: travelPlanId ?? this.travelPlanId,
      sourceAccountId: sourceAccountId ?? this.sourceAccountId,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      note: note ?? this.note,
    );
  }
}
