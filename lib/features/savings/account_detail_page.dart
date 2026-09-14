import 'package:flutter/material.dart';

import 'account_balance_calculator.dart';
import '../../core/constants/category_colors.dart';
import '../../core/constants/category_icons.dart';
import '../../shared/models/account_model.dart';
import '../../shared/models/financial_transaction_model.dart';
import '../../shared/widgets/section_title.dart';
import '../../shared/widgets/summary_card.dart';

class AccountDetailPage extends StatelessWidget {
  final AccountModel account;
  final List<FinancialTransactionModel> transactions;

  const AccountDetailPage({
    super.key,
    required this.account,
    required this.transactions,
  });

  String _formatDate(DateTime date) {
    // Dieses Format zeigt das Datum benutzerfreundlich an.
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day.$month.$year';
  }

  List<FinancialTransactionModel> _accountTransactions() {
    // Diese Funktion findet alle Transaktionen für dieses Konto oder diesen Fonds.
    final accountTransactions = transactions.where((transaction) {
      return transaction.fromAccountId == account.id ||
          transaction.toAccountId == account.id;
    }).toList();

    accountTransactions.sort(
      (a, b) => b.transactionDate.compareTo(a.transactionDate),
    );

    return accountTransactions;
  }

  double _currentBalance() {
    // Der aktuelle Kontostand wird aus Opening Balance und Transaktionen berechnet.
    return AccountBalanceCalculator.calculateBalance(
      accountId: account.id,
      openingBalance: account.balance,
      transactions: transactions,
    );
  }

  bool _isMoneyIn(FinancialTransactionModel transaction) {
    // Geld kommt rein, wenn dieses Konto das Zielkonto ist.
    return transaction.toAccountId == account.id;
  }

  bool _isMoneyOut(FinancialTransactionModel transaction) {
    // Geld geht raus, wenn dieses Konto das Quellkonto ist.
    return transaction.fromAccountId == account.id;
  }

  String _transactionTypeLabel(FinancialTransactionType type) {
    // Diese Texte machen die technischen Transaction Types für den Benutzer lesbar.
    switch (type) {
      case FinancialTransactionType.income:
        return 'Income';
      case FinancialTransactionType.expense:
        return 'Expense';
      case FinancialTransactionType.transfer:
        return 'Transfer';
      case FinancialTransactionType.debtGiven:
        return 'Debt Given';
      case FinancialTransactionType.debtReturned:
        return 'Debt Returned';
      case FinancialTransactionType.debtBorrowed:
        return 'Debt Borrowed';
      case FinancialTransactionType.debtPaidBack:
        return 'Debt Paid Back';
      case FinancialTransactionType.travelSaving:
        return 'Travel Saving';
      case FinancialTransactionType.travelWithdrawal:
        return 'Travel Withdrawal';
    }
  }

  IconData _transactionIcon(FinancialTransactionModel transaction) {
    // Jede Transaction bekommt ein passendes Icon.
    switch (transaction.type) {
      case FinancialTransactionType.income:
        return Icons.arrow_downward;
      case FinancialTransactionType.expense:
        return Icons.arrow_upward;
      case FinancialTransactionType.transfer:
        return Icons.swap_horiz;
      case FinancialTransactionType.debtGiven:
        return Icons.call_made;
      case FinancialTransactionType.debtReturned:
        return Icons.call_received;
      case FinancialTransactionType.debtBorrowed:
        return Icons.account_balance_wallet_outlined;
      case FinancialTransactionType.debtPaidBack:
        return Icons.payments_outlined;
      case FinancialTransactionType.travelSaving:
        return Icons.flight_takeoff;
      case FinancialTransactionType.travelWithdrawal:
        return Icons.flight_land;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = CategoryColors.getColor(account.colorValue);
    final icon = CategoryIcons.getIcon(account.iconName);
    final accountTransactions = _accountTransactions();
    final currentBalance = _currentBalance();

    final kindLabel =
        account.kind == AccountKind.account ? 'Account' : 'Fund';

    return Scaffold(
      appBar: AppBar(
        title: Text(account.name),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SummaryCard(
            title: 'Current Balance',
            amount: '€${currentBalance.toStringAsFixed(2)}',
            icon: icon,
          ),

          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color,
                    radius: 26,
                    child: Icon(
                      icon,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(width: 16),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(kindLabel),
                        Text(
                          'Opening Balance: €${account.balance.toStringAsFixed(2)}',
                        ),
                        Text(
                          account.isActive
                              ? 'Status: Active'
                              : 'Status: Inactive',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          const SectionTitle(title: 'Transaction History'),
          const SizedBox(height: 12),

          if (accountTransactions.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No transactions yet.'),
              ),
            ),

          for (final transaction in accountTransactions)
            _FinancialTransactionTile(
              transaction: transaction,
              isMoneyIn: _isMoneyIn(transaction),
              isMoneyOut: _isMoneyOut(transaction),
              typeLabel: _transactionTypeLabel(transaction.type),
              icon: _transactionIcon(transaction),
              dateText: _formatDate(transaction.transactionDate),
            ),
        ],
      ),
    );
  }
}

class _FinancialTransactionTile extends StatelessWidget {
  final FinancialTransactionModel transaction;
  final bool isMoneyIn;
  final bool isMoneyOut;
  final String typeLabel;
  final IconData icon;
  final String dateText;

  const _FinancialTransactionTile({
    required this.transaction,
    required this.isMoneyIn,
    required this.isMoneyOut,
    required this.typeLabel,
    required this.icon,
    required this.dateText,
  });

  String get _amountText {
    // Das Vorzeichen zeigt, ob Geld rein oder raus gegangen ist.
    if (isMoneyIn) {
      return '+ €${transaction.amount.toStringAsFixed(2)}';
    }

    if (isMoneyOut) {
      return '- €${transaction.amount.toStringAsFixed(2)}';
    }

    return '€${transaction.amount.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final amountColor = isMoneyIn
        ? Colors.green
        : isMoneyOut
            ? Colors.red
            : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(icon),
        ),
        title: Text(transaction.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$typeLabel • $dateText'),
            if (transaction.note != null && transaction.note!.isNotEmpty)
              Text(transaction.note!),
          ],
        ),
        trailing: Text(
          _amountText,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: amountColor,
          ),
        ),
      ),
    );
  }
}