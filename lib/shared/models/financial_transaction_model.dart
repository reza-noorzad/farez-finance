enum FinancialTransactionType {
  // Echtes Einkommen.
  // Beispiel: Gehalt, Geschenk, Rückerstattung
  income,

  // Echte Ausgabe.
  // Beispiel: Essen, Miete, Hund, Auto
  expense,

  // Geldtransfer zwischen zwei Konten oder Fonds.
  // Beispiel: Bank Account -> Travel Fund
  transfer,

  // Geld, das ich jemandem gegeben habe.
  // Das ist keine normale Ausgabe, sondern eine Forderung.
  debtGiven,

  // Geld, das ich von jemandem zurückbekommen habe.
  // Das ist kein normales Einkommen, sondern Rückzahlung einer Forderung.
  debtReturned,

  // Geld, das ich von jemandem geliehen habe.
  // Das ist kein normales Einkommen, sondern eine Verbindlichkeit.
  debtBorrowed,

  // Geld, das ich zurückgezahlt habe.
  // Das ist keine normale Ausgabe, sondern Rückzahlung einer Verbindlichkeit.
  debtPaidBack,

  // Geld, das für einen Reisezweck gespart wird.
  // Beispiel: Bank Account -> Rome Trip
  travelSaving,

  // Geld, das aus einem Reiseplan wieder entnommen wird.
  // Beispiel: Rome Trip -> Bank Account
  travelWithdrawal,
}

class FinancialTransactionModel {
  final String id;
  final FinancialTransactionType type;

  final double amount;

  final DateTime transactionDate;
  final DateTime createdAt;

  final String title;

  // Konto oder Fonds, von dem Geld abgeht.
  // Beispiel: Bank Account bei einer Ausgabe oder einem Transfer.
  final String? fromAccountId;

  // Konto oder Fonds, auf das Geld eingeht.
  // Beispiel: Bank Account bei Einkommen oder Travel Fund bei Sparen.
  final String? toAccountId;

  // Optionale Verknüpfung zu einer Kategorie.
  // Beispiel: Food, Salary, Leo
  final String? categoryId;

  // Optionale Verknüpfung zu einer Reise.
  final String? travelPlanId;

  // Optionale Verknüpfung zu einer Schuld oder Forderung.
  final String? debtId;

  final String? note;

  // Wenn false, wird die Transaktion nur für Berichte gespeichert
  // und verändert den aktuellen Kontostand nicht.
  final bool affectsBalance;

  const FinancialTransactionModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.transactionDate,
    required this.createdAt,
    required this.title,
    this.fromAccountId,
    this.toAccountId,
    this.categoryId,
    this.travelPlanId,
    this.debtId,
    this.note,
    this.affectsBalance = true,
  });

  FinancialTransactionModel copyWith({
    String? id,
    FinancialTransactionType? type,
    double? amount,
    DateTime? transactionDate,
    DateTime? createdAt,
    String? title,
    String? fromAccountId,
    String? toAccountId,
    String? categoryId,
    String? travelPlanId,
    String? debtId,
    String? note,
    bool? affectsBalance,
  }) {
    return FinancialTransactionModel(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      transactionDate: transactionDate ?? this.transactionDate,
      createdAt: createdAt ?? this.createdAt,
      title: title ?? this.title,
      fromAccountId: fromAccountId ?? this.fromAccountId,
      toAccountId: toAccountId ?? this.toAccountId,
      categoryId: categoryId ?? this.categoryId,
      travelPlanId: travelPlanId ?? this.travelPlanId,
      debtId: debtId ?? this.debtId,
      note: note ?? this.note,
      affectsBalance: affectsBalance ?? this.affectsBalance,
    );
  }

  factory FinancialTransactionModel.fromMap(Map<String, dynamic> map) {
    // Diese Funktion erstellt ein Transaction-Objekt aus Datenbankdaten.
    return FinancialTransactionModel(
      id: map['id'] as String,
      type: FinancialTransactionType.values.firstWhere(
        (type) => type.name == map['type'],
      ),
      amount: (map['amount'] as num).toDouble(),
      transactionDate: DateTime.parse(map['transaction_date'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      title: map['title'] as String,
      fromAccountId: map['from_account_id'] as String?,
      toAccountId: map['to_account_id'] as String?,
      categoryId: map['category_id'] as String?,
      travelPlanId: map['travel_plan_id'] as String?,
      debtId: map['debt_id'] as String?,
      note: map['note'] as String?,
      affectsBalance: map['affects_balance'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    // Diese Funktion macht aus dem Objekt eine Map für die Datenbank.
    return {
      'id': id,
      'type': type.name,
      'amount': amount,
      'transaction_date': transactionDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'title': title,
      'from_account_id': fromAccountId,
      'to_account_id': toAccountId,
      'category_id': categoryId,
      'travel_plan_id': travelPlanId,
      'debt_id': debtId,
      'note': note,
      'affects_balance': affectsBalance,
    };
  }
}
