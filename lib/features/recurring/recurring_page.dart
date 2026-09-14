import 'package:flutter/material.dart';

import '../../core/supabase/app_data_loader_service.dart';
import '../../shared/models/account_model.dart';
import '../../shared/models/category_model.dart';
import '../../shared/models/expense_model.dart';
import '../../shared/models/financial_transaction_model.dart';
import '../../shared/models/income_model.dart';
import '../categories/category_mock_data.dart';
import '../expenses/edit_expense_page.dart';
import '../expenses/expense_repository.dart';
import '../income/edit_income_page.dart';
import '../income/income_repository.dart';
import '../savings/account_mock_data.dart';

class RecurringPage extends StatefulWidget {
  const RecurringPage({super.key});

  @override
  State<RecurringPage> createState() => _RecurringPageState();
}

class _RecurringPageState extends State<RecurringPage> {
  final IncomeRepository _incomeRepository = IncomeRepository();
  final ExpenseRepository _expenseRepository = ExpenseRepository();

  DateTime _selectedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  List<IncomeDbRecord> _incomeRecords = [];
  List<ExpenseDbRecord> _expenseRecords = [];

  bool _isLoading = true;
  bool _isApplying = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRecurringData();
  }

  Future<void> _loadRecurringData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await AppDataLoaderService.loadInitialFinanceData();

      final incomeRecords =
          await _incomeRepository.fetchIncomesWithTransactions();
      final expenseRecords =
          await _expenseRepository.fetchExpensesWithTransactions();

      if (!mounted) {
        return;
      }

      setState(() {
        _incomeRecords = incomeRecords;
        _expenseRecords = expenseRecords;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Fehler beim Laden der wiederkehrenden Buchungen: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    await _loadRecurringData();
  }

  List<IncomeDbRecord> get _recurringIncomeRecords {
    return _incomeRecords.where((record) {
      return record.income.isRecurring;
    }).toList();
  }

  List<ExpenseDbRecord> get _recurringExpenseRecords {
    return _expenseRecords.where((record) {
      return record.expense.isRecurring;
    }).toList();
  }

  List<AccountModel> get _normalAccounts {
    return AccountMockData.accounts.where((account) {
      return account.isActive && account.kind == AccountKind.account;
    }).toList();
  }

  List<CategoryModel> get _incomeCategories {
    return CategoryMockData.getIncomeCategories();
  }

  List<CategoryModel> get _expenseCategories {
    return CategoryMockData.getExpenseCategories();
  }

  String _monthTitle() {
    final monthNames = [
      'Januar',
      'Februar',
      'März',
      'April',
      'Mai',
      'Juni',
      'Juli',
      'August',
      'September',
      'Oktober',
      'November',
      'Dezember',
    ];

    return '${monthNames[_selectedMonth.month - 1]} ${_selectedMonth.year}';
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month - 1,
      );
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + 1,
      );
    });
  }

  DateTime _targetDateForMonth(DateTime sourceDate) {
    final lastDay = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
      0,
    ).day;

    final day = sourceDate.day > lastDay ? lastDay : sourceDate.day;

    return DateTime(
      _selectedMonth.year,
      _selectedMonth.month,
      day,
    );
  }

  bool _incomeAlreadyExistsInSelectedMonth(IncomeModel source) {
    return _incomeRecords.any((record) {
      final income = record.income;

      return !income.isRecurring &&
          income.title == source.title &&
          income.categoryId == source.categoryId &&
          income.amount == source.amount &&
          income.transactionDate.year == _selectedMonth.year &&
          income.transactionDate.month == _selectedMonth.month;
    });
  }

  bool _expenseAlreadyExistsInSelectedMonth(ExpenseModel source) {
    return _expenseRecords.any((record) {
      final expense = record.expense;

      return !expense.isRecurring &&
          expense.title == source.title &&
          expense.categoryId == source.categoryId &&
          expense.amount == source.amount &&
          expense.transactionDate.year == _selectedMonth.year &&
          expense.transactionDate.month == _selectedMonth.month;
    });
  }

  int get _openRecurringCount {
    final incomeCount = _recurringIncomeRecords.where((record) {
      return !_incomeAlreadyExistsInSelectedMonth(record.income);
    }).length;

    final expenseCount = _recurringExpenseRecords.where((record) {
      return !_expenseAlreadyExistsInSelectedMonth(record.expense);
    }).length;

    return incomeCount + expenseCount;
  }

  Future<void> _applyIncome(IncomeDbRecord record) async {
    final sourceIncome = record.income;
    final sourceTransaction = record.transaction;

    if (_incomeAlreadyExistsInSelectedMonth(sourceIncome)) {
      _showMessage('Diese Einnahme wurde für diesen Monat bereits übernommen.');
      return;
    }

    final now = DateTime.now();
    final targetDate = _targetDateForMonth(sourceIncome.transactionDate);

    final income = IncomeModel(
      id: now.microsecondsSinceEpoch.toString(),
      title: sourceIncome.title,
      categoryId: sourceIncome.categoryId,
      amount: sourceIncome.amount,
      transactionDate: targetDate,
      createdAt: now,
      note: sourceIncome.note,
      isRecurring: false,
    );

    final fallbackAccountId =
        _normalAccounts.isEmpty ? null : _normalAccounts.first.id;

    final transaction = FinancialTransactionModel(
      id: 'tx_${now.microsecondsSinceEpoch}',
      type: FinancialTransactionType.income,
      amount: sourceIncome.amount,
      transactionDate: targetDate,
      createdAt: now,
      title: sourceIncome.title,
      fromAccountId: null,
      toAccountId: sourceTransaction.toAccountId ?? fallbackAccountId,
      categoryId:
          sourceIncome.categoryId.isEmpty ? null : sourceIncome.categoryId,
      note: sourceIncome.note,
    );

    await _incomeRepository.createIncomeWithTransaction(
      income: income,
      transaction: transaction,
    );
  }

  Future<void> _applyExpense(ExpenseDbRecord record) async {
    final sourceExpense = record.expense;
    final sourceTransaction = record.transaction;

    if (_expenseAlreadyExistsInSelectedMonth(sourceExpense)) {
      _showMessage('Diese Ausgabe wurde für diesen Monat bereits übernommen.');
      return;
    }

    final now = DateTime.now();
    final targetDate = _targetDateForMonth(sourceExpense.transactionDate);

    final expense = ExpenseModel(
      id: now.microsecondsSinceEpoch.toString(),
      title: sourceExpense.title,
      categoryId: sourceExpense.categoryId,
      amount: sourceExpense.amount,
      transactionDate: targetDate,
      createdAt: now,
      storeName: sourceExpense.storeName,
      note: sourceExpense.note,
      isRecurring: false,
      items: const [],
    );

    final fallbackAccountId =
        _normalAccounts.isEmpty ? null : _normalAccounts.first.id;

    final transaction = FinancialTransactionModel(
      id: 'tx_${now.microsecondsSinceEpoch}',
      type: FinancialTransactionType.expense,
      amount: sourceExpense.amount,
      transactionDate: targetDate,
      createdAt: now,
      title: sourceExpense.title,
      fromAccountId: sourceTransaction.fromAccountId ?? fallbackAccountId,
      toAccountId: null,
      categoryId:
          sourceExpense.categoryId.isEmpty ? null : sourceExpense.categoryId,
      note: sourceExpense.note,
    );

    await _expenseRepository.createExpenseWithTransaction(
      expense: expense,
      transaction: transaction,
    );
  }

  Future<void> _applyAllForSelectedMonth() async {
    if (_openRecurringCount == 0) {
      _showMessage('Für diesen Monat ist nichts offen.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Wiederkehrende Buchungen übernehmen'),
          content: Text(
            'Möchtest du $_openRecurringCount offene wiederkehrende Buchungen für ${_monthTitle()} übernehmen?',
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
              child: const Text('Übernehmen'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isApplying = true;
    });

    try {
      for (final record in _recurringIncomeRecords) {
        if (!_incomeAlreadyExistsInSelectedMonth(record.income)) {
          await _applyIncome(record);
        }
      }

      for (final record in _recurringExpenseRecords) {
        if (!_expenseAlreadyExistsInSelectedMonth(record.expense)) {
          await _applyExpense(record);
        }
      }

      await _loadRecurringData();

      _showMessage('Wiederkehrende Buchungen wurden übernommen.');
    } catch (e) {
      _showError('Wiederkehrende Buchungen konnten nicht übernommen werden: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isApplying = false;
        });
      }
    }
  }

  Future<void> _applySingleIncome(IncomeDbRecord record) async {
    setState(() {
      _isApplying = true;
    });

    try {
      await _applyIncome(record);
      await _loadRecurringData();
      _showMessage('Einnahme wurde übernommen.');
    } catch (e) {
      _showError('Einnahme konnte nicht übernommen werden: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isApplying = false;
        });
      }
    }
  }

  Future<void> _applySingleExpense(ExpenseDbRecord record) async {
    setState(() {
      _isApplying = true;
    });

    try {
      await _applyExpense(record);
      await _loadRecurringData();
      _showMessage('Ausgabe wurde übernommen.');
    } catch (e) {
      _showError('Ausgabe konnte nicht übernommen werden: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isApplying = false;
        });
      }
    }
  }

  Future<void> _editIncome(IncomeDbRecord record) async {
    final result = await Navigator.push<EditIncomeResult>(
      context,
      MaterialPageRoute(
        builder: (context) => EditIncomePage(
          income: record.income,
          transaction: record.transaction,
          categories: _incomeCategories,
          accounts: _normalAccounts,
        ),
      ),
    );

    if (result == null) {
      return;
    }

    try {
      await _incomeRepository.updateIncomeWithTransaction(
        income: result.income,
        transaction: result.transaction,
      );

      await _loadRecurringData();
    } catch (e) {
      _showError('Wiederkehrende Einnahme konnte nicht bearbeitet werden: $e');
    }
  }

  Future<void> _editExpense(ExpenseDbRecord record) async {
    final result = await Navigator.push<EditExpenseResult>(
      context,
      MaterialPageRoute(
        builder: (context) => EditExpensePage(
          expense: record.expense,
          transaction: record.transaction,
          categories: _expenseCategories,
          accounts: _normalAccounts,
        ),
      ),
    );

    if (result == null) {
      return;
    }

    try {
      await _expenseRepository.updateExpenseWithTransaction(
        expense: result.expense,
        transaction: result.transaction,
      );

      await _loadRecurringData();
    } catch (e) {
      _showError('Wiederkehrende Ausgabe konnte nicht bearbeitet werden: $e');
    }
  }

  Future<void> _deleteIncome(IncomeDbRecord record) async {
    final confirmed = await _confirmDelete(record.income.title);

    if (confirmed != true) {
      return;
    }

    try {
      await _incomeRepository.deleteIncomeWithTransaction(
        incomeId: record.income.id,
        transactionId: record.transaction.id,
      );

      await _loadRecurringData();
    } catch (e) {
      _showError('Wiederkehrende Einnahme konnte nicht gelöscht werden: $e');
    }
  }

  Future<void> _deleteExpense(ExpenseDbRecord record) async {
    final confirmed = await _confirmDelete(record.expense.title);

    if (confirmed != true) {
      return;
    }

    try {
      await _expenseRepository.deleteExpenseWithTransaction(
        expenseId: record.expense.id,
        transactionId: record.transaction.id,
      );

      await _loadRecurringData();
    } catch (e) {
      _showError('Wiederkehrende Ausgabe konnte nicht gelöscht werden: $e');
    }
  }

  Future<bool?> _confirmDelete(String title) async {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Wiederkehrende Buchung löschen'),
          content: Text(
            'Möchtest du "$title" wirklich löschen?\n\n'
            'Bereits übernommene Buchungen in anderen Monaten bleiben erhalten.',
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

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wiederkehrend'),
      ),
      body: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorState() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wiederkehrend'),
      ),
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
                _errorMessage ?? 'Unbekannter Fehler',
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    final hasRecurring =
        _recurringIncomeRecords.isNotEmpty || _recurringExpenseRecords.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wiederkehrend'),
        actions: [
          IconButton(
            onPressed: _isApplying ? null : _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Aktualisieren',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _isApplying ? null : _previousMonth,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          _monthTitle(),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _isApplying ? null : _nextMonth,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.repeat_outlined),
                title: const Text('Offen für diesen Monat'),
                subtitle: const Text(
                  'Nur offene wiederkehrende Buchungen werden übernommen.',
                ),
                trailing: Text(
                  _openRecurringCount.toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isApplying || _openRecurringCount == 0
                    ? null
                    : _applyAllForSelectedMonth,
                icon: _isApplying
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.done_all),
                label: const Text('Alle offenen übernehmen'),
              ),
            ),
            const SizedBox(height: 24),
            if (!hasRecurring)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Noch keine wiederkehrenden Buchungen. Markiere eine Einnahme oder Ausgabe beim Erstellen/Bearbeiten als wiederkehrend.',
                  ),
                ),
              ),
            if (_recurringIncomeRecords.isNotEmpty) ...[
              Text(
                'Wiederkehrende Einnahmen',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              for (final record in _recurringIncomeRecords)
                _RecurringItemCard(
                  title: record.income.title,
                  amount: record.income.amount,
                  typeLabel: 'Einnahme',
                  isAlreadyApplied:
                      _incomeAlreadyExistsInSelectedMonth(record.income),
                  onApply:
                      _isApplying ? null : () => _applySingleIncome(record),
                  onEdit: () => _editIncome(record),
                  onDelete: () => _deleteIncome(record),
                ),
              const SizedBox(height: 24),
            ],
            if (_recurringExpenseRecords.isNotEmpty) ...[
              Text(
                'Wiederkehrende Ausgaben',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              for (final record in _recurringExpenseRecords)
                _RecurringItemCard(
                  title: record.expense.title,
                  amount: record.expense.amount,
                  typeLabel: 'Ausgabe',
                  isAlreadyApplied:
                      _expenseAlreadyExistsInSelectedMonth(record.expense),
                  onApply:
                      _isApplying ? null : () => _applySingleExpense(record),
                  onEdit: () => _editExpense(record),
                  onDelete: () => _deleteExpense(record),
                ),
            ],
            const SizedBox(height: 90),
          ],
        ),
      ),
    );
  }
}

class _RecurringItemCard extends StatelessWidget {
  final String title;
  final double amount;
  final String typeLabel;
  final bool isAlreadyApplied;
  final VoidCallback? onApply;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RecurringItemCard({
    required this.title,
    required this.amount,
    required this.typeLabel,
    required this.isAlreadyApplied,
    required this.onApply,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          children: [
            ListTile(
              leading: Icon(
                isAlreadyApplied ? Icons.check_circle_outline : Icons.repeat,
              ),
              title: Text(title),
              subtitle: Text(typeLabel),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isAlreadyApplied)
                    const Chip(
                      label: Text('Erledigt'),
                    )
                  else
                    FilledButton(
                      onPressed: onApply,
                      child: const Text('Übernehmen'),
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
            ),
            Padding(
              padding: const EdgeInsets.only(
                left: 72,
                right: 16,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '€${amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
