class DebtPaymentModel {
  final String id;
  final String debtId;
  final double amount;
  final DateTime paymentDate;
  final DateTime createdAt;
  final String accountId;
  final String? note;
  final bool affectsBalance;

  const DebtPaymentModel({
    required this.id,
    required this.debtId,
    required this.amount,
    required this.paymentDate,
    required this.createdAt,
    required this.accountId,
    this.note,
    this.affectsBalance = true,
  });

  DebtPaymentModel copyWith({
    String? id,
    String? debtId,
    double? amount,
    DateTime? paymentDate,
    DateTime? createdAt,
    String? accountId,
    String? note,
    bool? affectsBalance,
  }) {
    return DebtPaymentModel(
      id: id ?? this.id,
      debtId: debtId ?? this.debtId,
      amount: amount ?? this.amount,
      paymentDate: paymentDate ?? this.paymentDate,
      createdAt: createdAt ?? this.createdAt,
      accountId: accountId ?? this.accountId,
      note: note ?? this.note,
      affectsBalance: affectsBalance ?? this.affectsBalance,
    );
  }
}
