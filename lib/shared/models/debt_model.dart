import 'debt_payment_model.dart';

enum DebtKind {
  // Ich habe jemandem Geld gegeben.
  // Das ist eine Forderung: jemand schuldet mir Geld.
  moneyLent,

  // Ich habe Geld von jemandem bekommen.
  // Das ist eine Verbindlichkeit: ich schulde jemandem Geld.
  moneyBorrowed,
}

class DebtModel {
  final String id;
  final String personName;
  final DebtKind kind;
  final double originalAmount;
  final DateTime debtDate;
  final DateTime createdAt;
  final DateTime? dueDate;
  final String accountId;
  final String? note;
  final bool isActive;

  // True bedeutet: Diese Forderung/Verbindlichkeit war schon beim App-Start offen.
  // Sie verändert Bank/Cash beim Anlegen nicht. Spätere Rückzahlungen verändern Bank/Cash normal.
  final bool isOpeningBalance;

  const DebtModel({
    required this.id,
    required this.personName,
    required this.kind,
    required this.originalAmount,
    required this.debtDate,
    required this.createdAt,
    required this.accountId,
    required this.isActive,
    this.dueDate,
    this.note,
    this.isOpeningBalance = false,
  });

  double paidAmountFrom(List<DebtPaymentModel> payments) {
    return payments
        .where((payment) => payment.debtId == id)
        .fold(0.0, (sum, payment) => sum + payment.amount);
  }

  double remainingAmountFrom(List<DebtPaymentModel> payments) {
    final remaining = originalAmount - paidAmountFrom(payments);

    if (remaining < 0) {
      return 0;
    }

    return remaining;
  }

  bool isClosedBy(List<DebtPaymentModel> payments) {
    return remainingAmountFrom(payments) <= 0;
  }

  DebtModel copyWith({
    String? id,
    String? personName,
    DebtKind? kind,
    double? originalAmount,
    DateTime? debtDate,
    DateTime? createdAt,
    DateTime? dueDate,
    String? accountId,
    String? note,
    bool? isActive,
    bool? isOpeningBalance,
  }) {
    return DebtModel(
      id: id ?? this.id,
      personName: personName ?? this.personName,
      kind: kind ?? this.kind,
      originalAmount: originalAmount ?? this.originalAmount,
      debtDate: debtDate ?? this.debtDate,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate ?? this.dueDate,
      accountId: accountId ?? this.accountId,
      note: note ?? this.note,
      isActive: isActive ?? this.isActive,
      isOpeningBalance: isOpeningBalance ?? this.isOpeningBalance,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'personName': personName,
      'kind': kind.name,
      'originalAmount': originalAmount,
      'debtDate': debtDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'accountId': accountId,
      'note': note,
      'isActive': isActive,
      'isOpeningBalance': isOpeningBalance,
    };
  }

  factory DebtModel.fromMap(Map<String, dynamic> map) {
    return DebtModel(
      id: map['id'] as String,
      personName: map['personName'] as String,
      kind: DebtKind.values.firstWhere(
        (kind) => kind.name == map['kind'],
        orElse: () => DebtKind.moneyLent,
      ),
      originalAmount: (map['originalAmount'] as num).toDouble(),
      debtDate: DateTime.parse(map['debtDate'] as String),
      createdAt: DateTime.parse(map['createdAt'] as String),
      dueDate: map['dueDate'] == null
          ? null
          : DateTime.parse(map['dueDate'] as String),
      accountId: map['accountId'] as String? ?? '',
      note: map['note'] as String?,
      isActive: map['isActive'] as bool? ?? true,
      isOpeningBalance: map['isOpeningBalance'] as bool? ?? false,
    );
  }
}
