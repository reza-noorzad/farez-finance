import '../../shared/models/financial_transaction_model.dart';

class AccountBalanceCalculator {
  static double calculateBalance({
    required String accountId,
    required double openingBalance,
    required List<FinancialTransactionModel> transactions,
  }) {
    var balance = openingBalance;

    for (final transaction in transactions) {
      if (!transaction.affectsBalance) {
        continue;
      }

      if (transaction.toAccountId == accountId) {
        balance += transaction.amount;
      }

      if (transaction.fromAccountId == accountId) {
        balance -= transaction.amount;
      }
    }

    return balance;
  }

  static double calculateBalanceUntilDate({
    required String accountId,
    required double openingBalance,
    required List<FinancialTransactionModel> transactions,
    required DateTime endDate,
  }) {
    final relevantTransactions = transactions.where((transaction) {
      return !transaction.transactionDate.isAfter(endDate);
    }).toList();

    return calculateBalance(
      accountId: accountId,
      openingBalance: openingBalance,
      transactions: relevantTransactions,
    );
  }

  static double calculateTotalBalance({
    required List<String> accountIds,
    required Map<String, double> openingBalances,
    required List<FinancialTransactionModel> transactions,
  }) {
    var total = 0.0;

    for (final accountId in accountIds) {
      total += calculateBalance(
        accountId: accountId,
        openingBalance: openingBalances[accountId] ?? 0.0,
        transactions: transactions,
      );
    }

    return total;
  }

  static double calculateTotalBalanceUntilDate({
    required List<String> accountIds,
    required Map<String, double> openingBalances,
    required List<FinancialTransactionModel> transactions,
    required DateTime endDate,
  }) {
    var total = 0.0;

    for (final accountId in accountIds) {
      total += calculateBalanceUntilDate(
        accountId: accountId,
        openingBalance: openingBalances[accountId] ?? 0.0,
        transactions: transactions,
        endDate: endDate,
      );
    }

    return total;
  }
}
