enum TravelPlanStatus {
  active,
  completed,
}

class TravelPlanModel {
  final String id;
  final String destination;
  final double targetBudget;
  final DateTime travelDate;
  final TravelPlanStatus status;
  final DateTime createdAt;
  final String? note;

  const TravelPlanModel({
    required this.id,
    required this.destination,
    required this.targetBudget,
    required this.travelDate,
    required this.status,
    required this.createdAt,
    this.note,
  });

  TravelPlanModel copyWith({
    String? id,
    String? destination,
    double? targetBudget,
    DateTime? travelDate,
    TravelPlanStatus? status,
    DateTime? createdAt,
    String? note,
  }) {
    return TravelPlanModel(
      id: id ?? this.id,
      destination: destination ?? this.destination,
      targetBudget: targetBudget ?? this.targetBudget,
      travelDate: travelDate ?? this.travelDate,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      note: note ?? this.note,
    );
  }

  factory TravelPlanModel.fromMap(Map<String, dynamic> map) {
    return TravelPlanModel(
      id: map['id'] as String,
      destination: map['destination'] as String,
      targetBudget: (map['target_budget'] as num).toDouble(),
      travelDate: DateTime.parse(map['travel_date'] as String),
      status: TravelPlanStatus.values.firstWhere(
        (status) => status.name == map['status'],
      ),
      createdAt: DateTime.parse(map['created_at'] as String),
      note: map['note'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'destination': destination,
      'target_budget': targetBudget,
      'travel_date': travelDate.toIso8601String(),
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'note': note,
    };
  }
}