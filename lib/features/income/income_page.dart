import 'package:flutter/material.dart';

import '../../shared/models/account_model.dart';
import '../../shared/models/category_model.dart';
import '../../shared/models/financial_transaction_model.dart';
import '../../shared/models/income_model.dart';
import '../../shared/widgets/help_text_card.dart';
import '../../shared/widgets/summary_card.dart';
import '../categories/category_mock_data.dart';
import '../savings/account_mock_data.dart';
import '../savings/financial_transaction_mock_data.dart';
import 'add_income_page.dart';
import 'edit_income_page.dart';
import 'income_mock_data.dart';
import 'income_repository.dart';

class IncomePage extends StatefulWidget {
  const IncomePage({super.key});

  @override
  State<IncomePage> createState() => _IncomePageState();
}

class _IncomePageState extends State<IncomePage> {
  final IncomeRepository _incomeRepository = IncomeRepository();

  List<IncomeModel> _incomes = [];
  List<FinancialTransactionModel> _transactions = [];
  final Map<String, FinancialTransactionModel> _transactionByIncomeId = {};

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadIncomes();
  }

  Future<void> _loadIncomes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final records = await _incomeRepository.fetchIncomesWithTransactions();

      final incomes = records.map((record) => record.income).toList();
      final incomeTransactions =
          records.map((record) => record.transaction).toList();

      IncomeMockData.incomes
        ..clear()
        ..addAll(incomes);

      FinancialTransactionMockData.transactions.removeWhere((transaction) {
        return transaction.type == FinancialTransactionType.income;
      });

      FinancialTransactionMockData.transactions.addAll(incomeTransactions);

      final transactionMap = <String, FinancialTransactionModel>{};
      for (final record in records) {
        transactionMap[record.income.id] = record.transaction;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _incomes = incomes;
        _transactions = FinancialTransactionMockData.transactions;
        _transactionByIncomeId
          ..clear()
          ..addAll(transactionMap);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Fehler beim Laden der Einnahmen: $e';
        _isLoading = false;
      });
    }
  }

  List<CategoryModel> get _incomeCategories {
    return CategoryMockData.getIncomeCategories();
  }

  List<AccountModel> get _accounts {
    return AccountMockData.accounts.where((account) {
      return account.isActive && account.kind == AccountKind.account;
    }).toList();
  }

  DateTime get _monthStart {
    return DateTime(_selectedMonth.year, _selectedMonth.month, 1);
  }

  DateTime get _monthEnd {
    return DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
      0,
      23,
      59,
      59,
    );
  }

  List<IncomeModel> get _monthlyIncomes {
    return _incomes.where((income) {
      return !income.transactionDate.isBefore(_monthStart) &&
          !income.transactionDate.isAfter(_monthEnd);
    }).toList();
  }

  double get _monthlyTotal {
    return _monthlyIncomes.fold(0.0, (sum, income) => sum + income.amount);
  }

  String _monthTitle() {
    final names = [
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

    return '${names[_selectedMonth.month - 1]} ${_selectedMonth.year}';
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day.$month.$year';
  }

  String _categoryName(String categoryId) {
    if (categoryId.isEmpty) {
      return 'Keine Kategorie';
    }

    final category = CategoryMockData.findById(categoryId);

    return category?.name ?? 'Keine Kategorie';
  }

  FinancialTransactionModel _transactionForIncome(IncomeModel income) {
    final existingTransaction = _transactionByIncomeId[income.id];

    if (existingTransaction != null && existingTransaction.id.isNotEmpty) {
      return existingTransaction;
    }

    final now = DateTime.now();

    return FinancialTransactionModel(
      id: '',
      type: FinancialTransactionType.income,
      amount: income.amount,
      transactionDate: income.transactionDate,
      createdAt: now,
      title: income.title,
      toAccountId: _accounts.isEmpty ? null : _accounts.first.id,
      categoryId: income.categoryId.isEmpty ? null : income.categoryId,
      note: income.note,
    );
  }

  Future<void> _openAddIncomePage() async {
    final result = await Navigator.push<AddIncomeResult>(
      context,
      MaterialPageRoute(
        builder: (context) => AddIncomePage(
          accounts: _accounts,
        ),
      ),
    );

    if (result == null) {
      return;
    }

    try {
      await _incomeRepository.createIncomeWithTransaction(
        income: result.income,
        transaction: result.transaction,
      );

      await _loadIncomes();
    } catch (e) {
      _showError('Einnahme konnte nicht gespeichert werden: $e');
    }
  }

  Future<void> _openEditIncomePage(IncomeModel income) async {
    final transaction = _transactionForIncome(income);

    if (transaction.id.isEmpty) {
      _showError('Keine passende Kontobewegung gefunden.');
      return;
    }

    final result = await Navigator.push<EditIncomeResult>(
      context,
      MaterialPageRoute(
        builder: (context) => EditIncomePage(
          income: income,
          transaction: transaction,
          categories: _incomeCategories,
          accounts: _accounts,
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

      await _loadIncomes();
    } catch (e) {
      _showError('Einnahme konnte nicht bearbeitet werden: $e');
    }
  }

  Future<void> _deleteIncome(IncomeModel income) async {
    final transaction = _transactionByIncomeId[income.id];

    if (transaction == null || transaction.id.isEmpty) {
      _showError('Keine passende Kontobewegung gefunden.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Einnahme löschen'),
          content: Text(
            'Möchtest du "${income.title}" wirklich löschen? '
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
      await _incomeRepository.deleteIncomeWithTransaction(
        incomeId: income.id,
        transactionId: transaction.id,
      );

      await _loadIncomes();
    } catch (e) {
      _showError('Einnahme konnte nicht gelöscht werden: $e');
    }
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    });
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
    await _loadIncomes();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        appBar: _IncomeAppBar(),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: const _IncomeAppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.red,
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Einnahmen'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Row(
                children: [
                  IconButton(
                    onPressed: _previousMonth,
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
                    onPressed: _nextMonth,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SummaryCard(
              title: 'Einnahmen',
              amount: '€${_monthlyTotal.toStringAsFixed(2)}',
              icon: Icons.trending_up_outlined,
            ),
            const SizedBox(height: 24),
            if (_monthlyIncomes.isEmpty)
              HelpTextCard(
                title: 'Noch keine Einnahmen',
                message:
                    'Hier kannst du Lohn, AMS, Rückzahlungen oder andere echte Einnahmen eintragen.',
                icon: Icons.info_outline,
                buttonText: 'Einnahme hinzufügen',
                onButtonPressed: _openAddIncomePage,
              )
            else
              for (final income in _monthlyIncomes.reversed)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.trending_up_outlined),
                    title: Text(income.title),
                    subtitle: Text(
                      '${_categoryName(income.categoryId)} · ${_formatDate(income.transactionDate)}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '€${income.amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              _openEditIncomePage(income);
                            }

                            if (value == 'delete') {
                              _deleteIncome(income);
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
                ),
            const SizedBox(height: 90),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddIncomePage,
        icon: const Icon(Icons.add),
        label: const Text('Einnahme'),
      ),
    );
  }
}

class _IncomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _IncomeAppBar();

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('Einnahmen'),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
