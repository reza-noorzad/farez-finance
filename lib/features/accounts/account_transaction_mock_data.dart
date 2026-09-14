import '../../shared/models/account_transaction_model.dart';

class AccountTransactionMockData {
  static final List<AccountTransactionModel> transactions = [
    AccountTransactionModel(
      id: '1',
      accountId: '1',
      type: AccountTransactionType.income,
      amount: 2200,
      title: 'Salary Reza',
      transactionDate: DateTime(2026, 6, 1),
      createdAt: DateTime.now(),
    ),

    AccountTransactionModel(
      id: '2',
      accountId: '1',
      type: AccountTransactionType.transferOut,
      amount: 300,
      title: 'Transfer to Rome Trip',
      transactionDate: DateTime(2026, 6, 10),
      createdAt: DateTime.now(),
    ),

    AccountTransactionModel(
      id: '3',
      accountId: '1',
      type: AccountTransactionType.expense,
      amount: 100,
      title: 'Food',
      transactionDate: DateTime(2026, 6, 12),
      createdAt: DateTime.now(),
    ),
  ];
}