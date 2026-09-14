import 'package:flutter/material.dart';

import '../../shared/models/account_model.dart';
import '../../shared/models/category_model.dart';
import '../../shared/models/expense_model.dart';
import '../../shared/models/financial_transaction_model.dart';
import '../../shared/widgets/help_text_card.dart';
import '../../shared/widgets/summary_card.dart';
import '../categories/category_mock_data.dart';
import '../reports/product_mock_data.dart';
import '../savings/account_mock_data.dart';
import '../savings/financial_transaction_mock_data.dart';
import 'add_expense_page.dart';
import 'edit_expense_page.dart';
import 'expense_detail_page.dart';
import 'expense_mock_data.dart';
import 'expense_repository.dart';

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  final ExpenseRepository _expenseRepository = ExpenseRepository();

  List<ExpenseModel> _expenses = [];
  List<FinancialTransactionModel> _transactions = [];
  final Map<String, FinancialTransactionModel> _transactionByExpenseId = {};

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  String? _selectedCategoryId;
  bool _showAllExpenses = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadExpenses() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final records = await _expenseRepository.fetchExpensesWithTransactions();

      final expenses = records.map((record) => record.expense).toList();
      final expenseTransactions =
          records.map((record) => record.transaction).toList();

      ExpenseMockData.expenses
        ..clear()
        ..addAll(expenses);

      ProductMockData.items.clear();
      for (final expense in expenses) {
        ProductMockData.items.addAll(expense.items);
      }

      FinancialTransactionMockData.transactions.removeWhere((transaction) {
        return transaction.type == FinancialTransactionType.expense;
      });

      FinancialTransactionMockData.transactions.addAll(expenseTransactions);

      final transactionMap = <String, FinancialTransactionModel>{};
      for (final record in records) {
        transactionMap[record.expense.id] = record.transaction;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _expenses = expenses;
        _transactions = FinancialTransactionMockData.transactions;
        _transactionByExpenseId
          ..clear()
          ..addAll(transactionMap);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Fehler beim Laden der Ausgaben: $e';
        _isLoading = false;
      });
    }
  }

  List<CategoryModel> get _expenseCategories {
    return CategoryMockData.getExpenseCategories();
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

  List<ExpenseModel> get _monthlyExpenses {
    return _expenses.where((expense) {
      return !expense.transactionDate.isBefore(_monthStart) &&
          !expense.transactionDate.isAfter(_monthEnd);
    }).toList();
  }

  List<ExpenseModel> get _filteredMonthlyExpenses {
    final query = _searchQuery.trim().toLowerCase();

    return _monthlyExpenses.where((expense) {
      if (_selectedCategoryId != null && expense.categoryId != _selectedCategoryId) {
        return false;
      }
      if (query.isEmpty) return true;

      final searchable = <String>[
        expense.title,
        expense.storeName ?? '',
        expense.note ?? '',
        ...expense.items.expand((item) => [
          item.name,
          item.originalName ?? '',
          item.monthlyName ?? '',
          item.storeName ?? '',
        ]),
      ].join(' ').toLowerCase();

      return searchable.contains(query);
    }).toList();
  }

  double get _monthlyTotal {
    return _filteredMonthlyExpenses.fold(0.0, (sum, expense) => sum + expense.amount);
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

  String _accountName(String? accountId) {
    if (accountId == null || accountId.isEmpty) return 'Unbekannt';
    try {
      return _accounts.firstWhere((account) => account.id == accountId).name;
    } catch (_) {
      return 'Unbekannt';
    }
  }

  String _categoryName(String categoryId) {
    if (categoryId.isEmpty) {
      return 'Keine Kategorie';
    }

    final category = CategoryMockData.findById(categoryId);

    return category?.name ?? 'Keine Kategorie';
  }

  FinancialTransactionModel _transactionForExpense(ExpenseModel expense) {
    final existingTransaction = _transactionByExpenseId[expense.id];

    if (existingTransaction != null && existingTransaction.id.isNotEmpty) {
      return existingTransaction;
    }

    final now = DateTime.now();

    return FinancialTransactionModel(
      id: '',
      type: FinancialTransactionType.expense,
      amount: expense.amount,
      transactionDate: expense.transactionDate,
      createdAt: now,
      title: expense.title,
      fromAccountId: _accounts.isEmpty ? null : _accounts.first.id,
      categoryId: expense.categoryId.isEmpty ? null : expense.categoryId,
      note: expense.note,
    );
  }

  Future<void> _openAddExpensePage() async {
    final result = await Navigator.push<AddExpenseResult>(
      context,
      MaterialPageRoute(
        builder: (context) => AddExpensePage(
          accounts: _accounts,
        ),
      ),
    );

    if (result == null) {
      return;
    }

    try {
      await _expenseRepository.createExpenseWithTransaction(
        expense: result.expense,
        transaction: result.transaction,
      );

      await _loadExpenses();
    } catch (e) {
      _showError('Ausgabe konnte nicht gespeichert werden: $e');
    }
  }

  Future<void> _openEditExpensePage(ExpenseModel expense) async {
    final transaction = _transactionForExpense(expense);

    if (transaction.id.isEmpty) {
      _showError('Keine passende Kontobewegung gefunden.');
      return;
    }

    final result = await Navigator.push<EditExpenseResult>(
      context,
      MaterialPageRoute(
        builder: (context) => EditExpensePage(
          expense: expense,
          transaction: transaction,
          categories: _expenseCategories,
          accounts: _accounts,
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

      await _loadExpenses();
    } catch (e) {
      _showError('Ausgabe konnte nicht bearbeitet werden: $e');
    }
  }

  Future<void> _deleteExpense(ExpenseModel expense) async {
    final transaction = _transactionByExpenseId[expense.id];

    if (transaction == null || transaction.id.isEmpty) {
      _showError('Keine passende Kontobewegung gefunden.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Ausgabe löschen'),
          content: Text(
            'Möchtest du "${expense.title}" wirklich löschen? '
            'Die dazugehörige Kontobewegung und Produktdetails werden auch entfernt.',
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
      await _expenseRepository.deleteExpenseWithTransaction(
        expenseId: expense.id,
        transactionId: transaction.id,
      );

      await _loadExpenses();
    } catch (e) {
      _showError('Ausgabe konnte nicht gelöscht werden: $e');
    }
  }

  Future<void> _openExpenseDetail(ExpenseModel expense) async {
    final action = await Navigator.push<ExpenseDetailAction>(
      context,
      MaterialPageRoute(
        builder: (context) => ExpenseDetailPage(
          expense: expense,
          categoryName: _categoryName(expense.categoryId),
          dateText: _formatDate(expense.transactionDate),
          paymentSourceName: _accountName(_transactionForExpense(expense).fromAccountId),
        ),
      ),
    );

    if (action == ExpenseDetailAction.edit) {
      _openEditExpensePage(expense);
    }

    if (action == ExpenseDetailAction.delete) {
      _deleteExpense(expense);
    }
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
      _showAllExpenses = false;
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
      _showAllExpenses = false;
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
    await _loadExpenses();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        appBar: _ExpensesAppBar(),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: const _ExpensesAppBar(),
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
        title: const Text('Ausgaben'),
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
              title: _selectedCategoryId == null
                  ? 'Ausgaben'
                  : _categoryName(_selectedCategoryId!),
              amount: '€${_monthlyTotal.toStringAsFixed(2)}',
              icon: Icons.trending_down_outlined,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    DropdownButtonFormField<String?>(
                      value: _selectedCategoryId,
                      decoration: const InputDecoration(
                        labelText: 'Kategorie',
                        prefixIcon: Icon(Icons.category_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('Alle Kategorien')),
                        ..._expenseCategories.map((category) => DropdownMenuItem<String?>(
                          value: category.id,
                          child: Text(category.name),
                        )),
                      ],
                      onChanged: (value) => setState(() {
                        _selectedCategoryId = value;
                        _showAllExpenses = false;
                      }),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: 'Suchen',
                        hintText: 'z. B. SPAR, Kaffee Reza, Kebab …',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isEmpty ? null : IconButton(
                          tooltip: 'Suche löschen',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          icon: const Icon(Icons.close),
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (value) => setState(() {
                        _searchQuery = value;
                        _showAllExpenses = false;
                      }),
                    ),
                    if (_selectedCategoryId != null || _searchQuery.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${_filteredMonthlyExpenses.length} Buchungen · €${_monthlyTotal.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (_filteredMonthlyExpenses.isEmpty)
              HelpTextCard(
                title: 'Noch keine Ausgaben',
                message:
                    'Hier kannst du Einkäufe, Miete, Internet, Freizeit und andere Ausgaben eintragen.',
                icon: Icons.info_outline,
                buttonText: 'Ausgabe hinzufügen',
                onButtonPressed: _openAddExpensePage,
              )
            else
              for (final expense in (_showAllExpenses
                      ? _filteredMonthlyExpenses.reversed
                      : _filteredMonthlyExpenses.reversed.take(5)))
                Card(
                  child: ListTile(
                    onTap: () => _openExpenseDetail(expense),
                    leading: const Icon(Icons.trending_down_outlined),
                    title: Text(expense.title),
                    subtitle: Text(
                      '${_categoryName(expense.categoryId)} · ${_formatDate(expense.transactionDate)}'
                      '${expense.items.isEmpty ? '' : ' · ${expense.items.length} Produkte'}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '€${expense.amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              _openEditExpensePage(expense);
                            }

                            if (value == 'delete') {
                              _deleteExpense(expense);
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
            if (_filteredMonthlyExpenses.length > 5)
              TextButton.icon(
                onPressed: () => setState(() => _showAllExpenses = !_showAllExpenses),
                icon: Icon(_showAllExpenses ? Icons.expand_less : Icons.expand_more),
                label: Text(_showAllExpenses ? 'Weniger anzeigen' : 'Mehr anzeigen'),
              ),
            const SizedBox(height: 90),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddExpensePage,
        icon: const Icon(Icons.add),
        label: const Text('Ausgabe'),
      ),
    );
  }
}

class _ExpensesAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ExpensesAppBar();

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('Ausgaben'),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
