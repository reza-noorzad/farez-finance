enum AccountTransactionType {
  income,
  expense,
  transferIn,
  transferOut,
  debtGiven,
  debtReturned,
  debtBorrowed,
  debtPaidBack,
}

class AccountTransactionModel {
  final String id;

  final String accountId;

  final AccountTransactionType type;

  final double amount;

  final String title;

  final DateTime transactionDate;

  final DateTime createdAt;

  final String? note;

  const AccountTransactionModel({
    required this.id,
    required this.accountId,
    required this.type,
    required this.amount,
    required this.title,
    required this.transactionDate,
    required this.createdAt,
    this.note,
  });
}