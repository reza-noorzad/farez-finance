import 'package:flutter/material.dart';

import '../../shared/models/account_model.dart';
import '../../shared/models/debt_model.dart';
import '../../shared/models/debt_payment_model.dart';
import '../../shared/models/financial_transaction_model.dart';
import '../../shared/widgets/summary_card.dart';
import '../savings/account_mock_data.dart';
import '../savings/financial_transaction_mock_data.dart';
import 'add_debt_page.dart';
import 'add_debt_payment_page.dart';
import 'debt_detail_page.dart';
import 'debt_mock_data.dart';
import 'debt_repository.dart';
import 'edit_debt_page.dart';
import 'edit_debt_payment_page.dart';

class DebtsPage extends StatefulWidget {
  const DebtsPage({super.key});

  @override
  State<DebtsPage> createState() => _DebtsPageState();
}

class _DebtsPageState extends State<DebtsPage> {
  final DebtRepository _debtRepository = DebtRepository();

  List<DebtModel> _debts = [];
  List<DebtPaymentModel> _payments = [];
  List<FinancialTransactionModel> _transactions = [];
  List<AccountModel> _accounts = [];

  final Map<String, FinancialTransactionModel> _mainTransactionByDebtId = {};
  final Map<String, FinancialTransactionModel> _paymentTransactionByPaymentId =
      {};

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDebts();
  }

  Future<void> _loadDebts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final debtData = await _debtRepository.fetchDebtData();

      DebtMockData.debts
        ..clear()
        ..addAll(debtData.debts);

      DebtMockData.payments
        ..clear()
        ..addAll(debtData.payments);

      FinancialTransactionMockData.transactions.removeWhere((transaction) {
        return transaction.type == FinancialTransactionType.debtGiven ||
            transaction.type == FinancialTransactionType.debtReturned ||
            transaction.type == FinancialTransactionType.debtBorrowed ||
            transaction.type == FinancialTransactionType.debtPaidBack;
      });

      FinancialTransactionMockData.transactions.addAll(
        debtData.mainTransactionByDebtId.values,
      );

      FinancialTransactionMockData.transactions.addAll(
        debtData.paymentTransactionByPaymentId.values,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _debts = debtData.debts;
        _payments = debtData.payments;
        _transactions = FinancialTransactionMockData.transactions;
        _accounts = AccountMockData.accounts;

        _mainTransactionByDebtId
          ..clear()
          ..addAll(debtData.mainTransactionByDebtId);

        _paymentTransactionByPaymentId
          ..clear()
          ..addAll(debtData.paymentTransactionByPaymentId);

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Fehler beim Laden der Schulden: $e';
        _isLoading = false;
      });
    }
  }

  List<AccountModel> get _normalActiveAccounts {
    return _accounts.where((account) {
      return account.isActive && account.kind == AccountKind.account;
    }).toList();
  }

  List<DebtModel> get _activeDebts {
    return _debts.where((debt) {
      return debt.isActive && !debt.isClosedBy(_payments);
    }).toList();
  }

  List<DebtModel> get _closedDebts {
    return _debts.where((debt) {
      return debt.isActive && debt.isClosedBy(_payments);
    }).toList();
  }

  double get _totalReceivables {
    return _activeDebts
        .where((debt) => debt.kind == DebtKind.moneyLent)
        .fold(0.0, (sum, debt) => sum + debt.remainingAmountFrom(_payments));
  }

  double get _totalLiabilities {
    return _activeDebts
        .where((debt) => debt.kind == DebtKind.moneyBorrowed)
        .fold(0.0, (sum, debt) => sum + debt.remainingAmountFrom(_payments));
  }

  Future<void> _openAddDebtPage() async {
    final result = await Navigator.push<AddDebtResult>(
      context,
      MaterialPageRoute(
        builder: (context) => AddDebtPage(
          accounts: _normalActiveAccounts,
        ),
      ),
    );

    if (result == null) {
      return;
    }

    try {
      await _debtRepository.createDebtWithTransaction(
        debt: result.debt,
        transaction: result.transaction,
      );

      await _loadDebts();
    } catch (e) {
      _showError('Schuld konnte nicht gespeichert werden: $e');
    }
  }

  Future<void> _openEditDebtPage(DebtModel debt) async {
    final paidAmount = debt.paidAmountFrom(_payments);

    final existingTransaction = _mainTransactionByDebtId[debt.id];

    if (existingTransaction == null) {
      _showError('Keine passende Kontobewegung gefunden.');
      return;
    }

    final result = await Navigator.push<EditDebtResult>(
      context,
      MaterialPageRoute(
        builder: (context) => EditDebtPage(
          debt: debt,
          alreadyPaidAmount: paidAmount,
          accounts: _normalActiveAccounts,
        ),
      ),
    );

    if (result == null) {
      return;
    }

    final transactionForDb = result.transaction.copyWith(
      id: existingTransaction.id,
      debtId: result.debt.id,
    );

    try {
      await _debtRepository.updateDebtWithTransaction(
        debt: result.debt,
        transaction: transactionForDb,
      );

      await _loadDebts();
    } catch (e) {
      _showError('Schuld konnte nicht bearbeitet werden: $e');
    }
  }

  Future<void> _deleteDebt(DebtModel debt) async {
    final debtPayments = _payments.where((payment) {
      return payment.debtId == debt.id;
    }).toList();

    final hasPayments = debtPayments.isNotEmpty;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Schuld löschen'),
          content: Text(
            hasPayments
                ? 'Diese Schuld hat bereits Zahlungen. Wenn du sie löschst, werden auch alle Zahlungen und Kontobewegungen dazu entfernt. Möchtest du fortfahren?'
                : 'Möchtest du diese Schuld wirklich löschen? Die dazugehörige Kontobewegung wird entfernt.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Löschen'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _debtRepository.deleteDebtWithTransactions(debt.id);
      await _loadDebts();
    } catch (e) {
      _showError('Schuld konnte nicht gelöscht werden: $e');
    }
  }

  Future<void> _openAddPaymentPage(DebtModel debt) async {
    final remainingAmount = debt.remainingAmountFrom(_payments);

    if (remainingAmount <= 0) {
      return;
    }

    final result = await Navigator.push<AddDebtPaymentResult>(
      context,
      MaterialPageRoute(
        builder: (context) => AddDebtPaymentPage(
          debt: debt,
          remainingAmount: remainingAmount,
          accounts: _normalActiveAccounts,
        ),
      ),
    );

    if (result == null) {
      return;
    }

    try {
      await _debtRepository.createPaymentWithTransaction(
        debt: debt,
        payment: result.payment,
        transaction: result.transaction,
      );

      await _loadDebts();
    } catch (e) {
      _showError('Zahlung konnte nicht gespeichert werden: $e');
    }
  }

  Future<void> _openEditPaymentPage({
    required DebtModel debt,
    required DebtPaymentModel payment,
  }) async {
    final totalPaidWithoutThisPayment = _payments
        .where((item) => item.debtId == debt.id && item.id != payment.id)
        .fold(0.0, (sum, item) => sum + item.amount);

    final maxAmount = debt.originalAmount - totalPaidWithoutThisPayment;

    final existingTransaction = _paymentTransactionByPaymentId[payment.id];

    if (existingTransaction == null) {
      _showError('Keine passende Kontobewegung gefunden.');
      return;
    }

    final result = await Navigator.push<EditDebtPaymentResult>(
      context,
      MaterialPageRoute(
        builder: (context) => EditDebtPaymentPage(
          debt: debt,
          payment: payment,
          maxAmount: maxAmount,
          accounts: _normalActiveAccounts,
        ),
      ),
    );

    if (result == null) {
      return;
    }

    final transactionForDb = result.transaction.copyWith(
      id: existingTransaction.id,
      debtId: debt.id,
    );

    try {
      await _debtRepository.updatePaymentWithTransaction(
        debt: debt,
        payment: result.payment,
        transaction: transactionForDb,
      );

      await _loadDebts();
    } catch (e) {
      _showError('Zahlung konnte nicht bearbeitet werden: $e');
    }
  }

  Future<void> _deletePayment({
    required DebtModel debt,
    required DebtPaymentModel payment,
  }) async {
    final transaction = _paymentTransactionByPaymentId[payment.id];

    if (transaction == null) {
      _showError('Keine passende Kontobewegung gefunden.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Zahlung löschen'),
          content: Text(
            'Möchtest du diese Zahlung über €${payment.amount.toStringAsFixed(2)} wirklich löschen? '
            'Die dazugehörige Kontobewegung wird auch entfernt.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Löschen'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _debtRepository.deletePaymentWithTransaction(
        paymentId: payment.id,
        transactionId: transaction.id,
      );

      await _loadDebts();
    } catch (e) {
      _showError('Zahlung konnte nicht gelöscht werden: $e');
    }
  }

  Future<void> _openDebtDetail(DebtModel debt) async {
    final result = await Navigator.push<DebtDetailResult>(
      context,
      MaterialPageRoute(
        builder: (context) => DebtDetailPage(
          debt: debt,
          payments: _payments,
          accounts: _accounts,
        ),
      ),
    );

    if (result == null) {
      return;
    }

    switch (result.action) {
      case DebtDetailAction.editDebt:
        await _openEditDebtPage(debt);
        break;
      case DebtDetailAction.deleteDebt:
        await _deleteDebt(debt);
        break;
      case DebtDetailAction.addPayment:
        await _openAddPaymentPage(debt);
        break;
      case DebtDetailAction.editPayment:
        if (result.payment != null) {
          await _openEditPaymentPage(
            debt: debt,
            payment: result.payment!,
          );
        }
        break;
      case DebtDetailAction.deletePayment:
        if (result.payment != null) {
          await _deletePayment(
            debt: debt,
            payment: result.payment!,
          );
        }
        break;
    }
  }

  String _kindText(DebtModel debt) {
    if (debt.kind == DebtKind.moneyLent) {
      return 'Ich bekomme Geld';
    }

    return 'Ich schulde Geld';
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _refresh() async {
    await _loadDebts();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        appBar: _DebtsAppBar(),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: const _DebtsAppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Erneut versuchen'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final netDebtPosition = _totalReceivables - _totalLiabilities;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Schulden'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SummaryCard(
              title: 'Forderungen',
              amount: '€${_totalReceivables.toStringAsFixed(2)}',
              icon: Icons.trending_up_outlined,
            ),
            const SizedBox(height: 12),
            SummaryCard(
              title: 'Verbindlichkeiten',
              amount: '€${_totalLiabilities.toStringAsFixed(2)}',
              icon: Icons.trending_down_outlined,
            ),
            const SizedBox(height: 12),
            SummaryCard(
              title: 'Netto',
              amount: '€${netDebtPosition.toStringAsFixed(2)}',
              icon: Icons.compare_arrows_outlined,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Text(
                  'Offene Schulden',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _openAddDebtPage,
                  icon: const Icon(Icons.add),
                  label: const Text('Neu'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_activeDebts.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Noch keine offenen Schulden.',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Hier kannst du festhalten, wenn du jemandem Geld gegeben hast oder selbst Geld geliehen hast.',
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: _openAddDebtPage,
                        icon: const Icon(Icons.add),
                        label: const Text('Schuld hinzufügen'),
                      ),
                    ],
                  ),
                ),
              )
            else
              for (final debt in _activeDebts)
                _DebtCard(
                  debt: debt,
                  payments: _payments,
                  kindText: _kindText(debt),
                  onTap: () => _openDebtDetail(debt),
                  onPayment: () => _openAddPaymentPage(debt),
                  onEdit: () => _openEditDebtPage(debt),
                  onDelete: () => _deleteDebt(debt),
                ),
            if (_closedDebts.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Geschlossen',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              for (final debt in _closedDebts)
                _DebtCard(
                  debt: debt,
                  payments: _payments,
                  kindText: _kindText(debt),
                  onTap: () => _openDebtDetail(debt),
                  onPayment: null,
                  onEdit: () => _openEditDebtPage(debt),
                  onDelete: () => _deleteDebt(debt),
                ),
            ],
            const SizedBox(height: 90),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddDebtPage,
        icon: const Icon(Icons.add),
        label: const Text('Schuld'),
      ),
    );
  }
}

class _DebtsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _DebtsAppBar();

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('Schulden'),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _DebtCard extends StatelessWidget {
  final DebtModel debt;
  final List<DebtPaymentModel> payments;
  final String kindText;
  final VoidCallback onTap;
  final VoidCallback? onPayment;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DebtCard({
    required this.debt,
    required this.payments,
    required this.kindText,
    required this.onTap,
    required this.onPayment,
    required this.onEdit,
    required this.onDelete,
  });

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day.$month.$year';
  }

  @override
  Widget build(BuildContext context) {
    final paidAmount = debt.paidAmountFrom(payments);
    final remainingAmount = debt.remainingAmountFrom(payments);
    final isClosed = debt.isClosedBy(payments);

    final progress = debt.originalAmount <= 0
        ? 0.0
        : (paidAmount / debt.originalAmount).clamp(0.0, 1.0);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    child: Icon(
                      debt.kind == DebtKind.moneyLent
                          ? Icons.call_made_outlined
                          : Icons.call_received_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          debt.personName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(kindText),
                      ],
                    ),
                  ),
                  Text(
                    '€${remainingAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        onEdit();
                      }

                      if (value == 'delete') {
                        onDelete();
                      }
                    },
                    itemBuilder: (context) {
                      return const [
                        PopupMenuItem(
                          value: 'edit',
                          child: Text('Bearbeiten'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Löschen'),
                        ),
                      ];
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: progress,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Bezahlt: €${paidAmount.toStringAsFixed(2)} / €${debt.originalAmount.toStringAsFixed(2)}',
                    ),
                  ),
                  if (isClosed)
                    const Chip(
                      label: Text('Erledigt'),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text('Datum: ${_formatDate(debt.debtDate)}'),
                  const Spacer(),
                  if (onPayment != null)
                    IconButton(
                      tooltip: 'Zahlung',
                      onPressed: onPayment,
                      icon: const Icon(Icons.payments_outlined),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
