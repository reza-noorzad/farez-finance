class ExpenseItemModel {
  final String id;
  final String expenseId;
  final String name;
  final String? originalName;
  final String? monthlyName;
  final String category;
  final double quantity;
  final String unit;
  final double totalPrice;
  final DateTime date;
  final String? storeName;

  // Neue Messfelder für Produktanalyse und PDF-Berichte.
  // Wenn z.B. Hackfleisch nur als "1 Packung" erkannt wird, bleibt weightGrams null.
  final double? weightGrams;
  final double? volumeMl;
  final double? countUnits;
  final bool isMeasurementImportant;
  final bool needsReview;
  final String? reviewReason;
  final String measurementStatus; // exact, estimated, unknown, reviewed, notImportant

  const ExpenseItemModel({
    required this.id,
    required this.expenseId,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.totalPrice,
    required this.date,
    this.originalName,
    this.monthlyName,
    this.storeName,
    this.weightGrams,
    this.volumeMl,
    this.countUnits,
    this.isMeasurementImportant = false,
    this.needsReview = false,
    this.reviewReason,
    this.measurementStatus = 'unknown',
  });

  ExpenseItemModel copyWith({
    String? id,
    String? expenseId,
    String? name,
    String? originalName,
    String? monthlyName,
    String? category,
    double? quantity,
    String? unit,
    double? totalPrice,
    DateTime? date,
    String? storeName,
    double? weightGrams,
    double? volumeMl,
    double? countUnits,
    bool? isMeasurementImportant,
    bool? needsReview,
    String? reviewReason,
    String? measurementStatus,
  }) {
    return ExpenseItemModel(
      id: id ?? this.id,
      expenseId: expenseId ?? this.expenseId,
      name: name ?? this.name,
      originalName: originalName ?? this.originalName,
      monthlyName: monthlyName ?? this.monthlyName,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      totalPrice: totalPrice ?? this.totalPrice,
      date: date ?? this.date,
      storeName: storeName ?? this.storeName,
      weightGrams: weightGrams ?? this.weightGrams,
      volumeMl: volumeMl ?? this.volumeMl,
      countUnits: countUnits ?? this.countUnits,
      isMeasurementImportant:
          isMeasurementImportant ?? this.isMeasurementImportant,
      needsReview: needsReview ?? this.needsReview,
      reviewReason: reviewReason ?? this.reviewReason,
      measurementStatus: measurementStatus ?? this.measurementStatus,
    );
  }

  String get reportName {
    final value = monthlyName?.trim();

    if (value != null && value.isNotEmpty) {
      return value;
    }

    return name;
  }

  bool get hasPreciseMeasurement {
    return weightGrams != null || volumeMl != null || countUnits != null;
  }

  String get measurementLabel {
    if (weightGrams != null) {
      if (weightGrams! >= 1000) {
        return '${(weightGrams! / 1000).toStringAsFixed(2)} kg';
      }

      return '${weightGrams!.toStringAsFixed(0)} g';
    }

    if (volumeMl != null) {
      if (volumeMl! >= 1000) {
        return '${(volumeMl! / 1000).toStringAsFixed(2)} L';
      }

      return '${volumeMl!.toStringAsFixed(0)} ml';
    }

    if (countUnits != null) {
      return '${countUnits!.toStringAsFixed(0)} Stück';
    }

    if (isMeasurementImportant) {
      return '${quantity.toStringAsFixed(0)} $unit · Menge unbekannt';
    }

    return '${quantity.toStringAsFixed(0)} $unit';
  }

  factory ExpenseItemModel.fromMap(Map<String, dynamic> map) {
    return ExpenseItemModel(
      id: map['id'] as String,
      expenseId: map['expenseId'] as String,
      name: map['name'] as String,
      originalName: map['originalName'] as String?,
      monthlyName: map['monthlyName'] as String?,
      category: map['category'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      unit: map['unit'] as String,
      totalPrice: (map['totalPrice'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      storeName: map['storeName'] as String?,
      weightGrams: _toDouble(map['weightGrams']),
      volumeMl: _toDouble(map['volumeMl']),
      countUnits: _toDouble(map['countUnits']),
      isMeasurementImportant: map['isMeasurementImportant'] as bool? ?? false,
      needsReview: map['needsReview'] as bool? ?? false,
      reviewReason: map['reviewReason'] as String?,
      measurementStatus: map['measurementStatus'] as String? ?? 'unknown',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'expenseId': expenseId,
      'name': name,
      'originalName': originalName,
      'monthlyName': monthlyName,
      'category': category,
      'quantity': quantity,
      'unit': unit,
      'totalPrice': totalPrice,
      'date': date.toIso8601String(),
      'storeName': storeName,
      'weightGrams': weightGrams,
      'volumeMl': volumeMl,
      'countUnits': countUnits,
      'isMeasurementImportant': isMeasurementImportant,
      'needsReview': needsReview,
      'reviewReason': reviewReason,
      'measurementStatus': measurementStatus,
    };
  }

  static double? _toDouble(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString().replaceAll(',', '.'));
  }
}
