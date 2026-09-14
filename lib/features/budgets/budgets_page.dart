import 'package:flutter/material.dart';

import '../../core/localization/app_strings.dart';
import '../../core/supabase/app_data_loader_service.dart';
import '../../shared/models/category_model.dart';
import '../../shared/models/monthly_budget_model.dart';
import '../../shared/widgets/summary_card.dart';
import '../../shared/widgets/simple_finance_charts.dart';
import '../categories/category_mock_data.dart';
import '../expenses/expense_repository.dart';
import 'budget_repository.dart';

class BudgetsPage extends StatefulWidget {
  const BudgetsPage({super.key});

  @override
  State<BudgetsPage> createState() => _BudgetsPageState();
}

class _BudgetsPageState extends State<BudgetsPage> {
  final BudgetRepository _budgetRepository = BudgetRepository();
  final ExpenseRepository _expenseRepository = ExpenseRepository();

  DateTime _selectedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  List<MonthlyBudgetModel> _budgets = [];
  Map<String, double> _spentByCategoryId = {};

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadBudgets();
  }

  Future<void> _loadBudgets() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await AppDataLoaderService.loadInitialFinanceData();

      final budgets =
          await _budgetRepository.fetchBudgetsForMonth(_selectedMonth);

      final expenseRecords =
          await _expenseRepository.fetchExpensesWithTransactions();

      final spentByCategoryId = <String, double>{};

      for (final record in expenseRecords) {
        final expense = record.expense;
        final categoryId = expense.categoryId;

        if (categoryId.isEmpty) {
          continue;
        }

        if (!_isInSelectedMonth(expense.transactionDate)) {
          continue;
        }

        spentByCategoryId[categoryId] =
            (spentByCategoryId[categoryId] ?? 0) + expense.amount;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _budgets = budgets;
        _spentByCategoryId = spentByCategoryId;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Fehler beim Laden der Budgets: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    await _loadBudgets();
  }

  bool _isInSelectedMonth(DateTime date) {
    return date.year == _selectedMonth.year &&
        date.month == _selectedMonth.month;
  }

  List<CategoryModel> get _expenseCategories {
    return CategoryMockData.getExpenseCategories().where((category) {
      return category.isActive;
    }).toList();
  }

  CategoryModel? _categoryById(String categoryId) {
    try {
      return _expenseCategories.firstWhere((category) => category.id == categoryId);
    } catch (_) {
      return null;
    }
  }

  String _monthTitle() {
    return '${AppStrings.monthName(_selectedMonth.month)} ${_selectedMonth.year}';
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month - 1,
      );
    });

    _loadBudgets();
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + 1,
      );
    });

    _loadBudgets();
  }

  double get _totalBudget {
    return _budgets.fold(
      0.0,
      (sum, budget) => sum + budget.amount,
    );
  }

  double get _totalSpent {
    return _budgets.fold(
      0.0,
      (sum, budget) => sum + (_spentByCategoryId[budget.categoryId] ?? 0),
    );
  }

  double get _totalRemaining {
    return _totalBudget - _totalSpent;
  }

  Future<void> _openAddBudgetDialog() async {
    final existingCategoryIds = _budgets.map((budget) => budget.categoryId).toSet();

    final availableCategories = _expenseCategories.where((category) {
      return !existingCategoryIds.contains(category.id);
    }).toList();

    if (availableCategories.isEmpty) {
      _showMessage(
        'Für diesen Monat haben alle Ausgabenkategorien bereits ein Budget.',
      );
      return;
    }

    final result = await showDialog<_BudgetDialogResult>(
      context: context,
      builder: (context) {
        return _BudgetDialog(
          title: 'Budget hinzufügen',
          categories: availableCategories,
        );
      },
    );

    if (result == null) {
      return;
    }

    try {
      await _budgetRepository.createBudget(
        categoryId: result.categoryId,
        monthDate: _selectedMonth,
        amount: result.amount,
      );

      await _loadBudgets();
    } catch (e) {
      _showError('Budget konnte nicht gespeichert werden: $e');
    }
  }

  Future<void> _openEditBudgetDialog(MonthlyBudgetModel budget) async {
    final category = _categoryById(budget.categoryId);

    final result = await showDialog<_BudgetDialogResult>(
      context: context,
      builder: (context) {
        return _BudgetDialog(
          title: 'Budget bearbeiten',
          categories: category == null ? _expenseCategories : [category],
          initialCategoryId: budget.categoryId,
          initialAmount: budget.amount,
          lockCategory: true,
        );
      },
    );

    if (result == null) {
      return;
    }

    try {
      await _budgetRepository.updateBudget(
        budgetId: budget.id,
        amount: result.amount,
      );

      await _loadBudgets();
    } catch (e) {
      _showError('Budget konnte nicht bearbeitet werden: $e');
    }
  }

  Future<void> _deleteBudget(MonthlyBudgetModel budget) async {
    final category = _categoryById(budget.categoryId);
    final categoryName = category?.name ?? 'diese Kategorie';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Budget löschen'),
          content: Text(
            'Möchtest du das Budget für "$categoryName" wirklich löschen?',
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
      await _budgetRepository.deleteBudget(budget.id);
      await _loadBudgets();
    } catch (e) {
      _showError('Budget konnte nicht gelöscht werden: $e');
    }
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
        title: const Text('Budgets'),
      ),
      body: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorState() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets'),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets'),
        actions: [
          IconButton(
            onPressed: _refresh,
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
            ),
            const SizedBox(height: 16),
            SummaryCard(
              title: 'Budget gesamt',
              amount: '€${_totalBudget.toStringAsFixed(2)}',
              icon: Icons.account_balance_wallet_outlined,
            ),
            const SizedBox(height: 12),
            SummaryCard(
              title: 'Ausgegeben',
              amount: '€${_totalSpent.toStringAsFixed(2)}',
              icon: Icons.shopping_cart_outlined,
            ),
            const SizedBox(height: 12),
            SummaryCard(
              title: 'Übrig',
              amount: '€${_totalRemaining.toStringAsFixed(2)}',
              icon: Icons.savings_outlined,
            ),
            const SizedBox(height: 12),
            FinanceBarChartCard(
              title: 'Budget vs Ausgegeben',
              valuePrefix: '€',
              data: [
                FinanceBarDatum(label: 'Budget', value: _totalBudget),
                FinanceBarDatum(label: 'Ausgegeben', value: _totalSpent),
                FinanceBarDatum(label: 'Übrig', value: _totalRemaining),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Text(
                  'Budgets pro Kategorie',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _openAddBudgetDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Neu'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_budgets.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Noch keine Budgets für diesen Monat. Erstelle z.B. ein Budget für Lebensmittel, Freizeit oder Haushalt.',
                  ),
                ),
              )
            else
              for (final budget in _budgets)
                _BudgetCard(
                  budget: budget,
                  categoryName:
                      _categoryById(budget.categoryId)?.name ?? 'Unbekannt',
                  spent: _spentByCategoryId[budget.categoryId] ?? 0,
                  onEdit: () => _openEditBudgetDialog(budget),
                  onDelete: () => _deleteBudget(budget),
                ),
            const SizedBox(height: 90),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddBudgetDialog,
        icon: const Icon(Icons.add),
        label: const Text('Budget'),
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  final MonthlyBudgetModel budget;
  final String categoryName;
  final double spent;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BudgetCard({
    required this.budget,
    required this.categoryName,
    required this.spent,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = budget.amount - spent;
    final progress = budget.amount <= 0 ? 0.0 : (spent / budget.amount).clamp(0.0, 1.0);
    final isOverBudget = spent > budget.amount;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Icon(
                    isOverBudget
                        ? Icons.warning_amber_outlined
                        : Icons.pie_chart_outline,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    categoryName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
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
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Budget: €${budget.amount.toStringAsFixed(2)}',
                  ),
                ),
                Text(
                  'Ausgegeben: €${spent.toStringAsFixed(2)}',
                ),
              ],
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                isOverBudget
                    ? 'Über Budget: €${(spent - budget.amount).toStringAsFixed(2)}'
                    : 'Übrig: €${remaining.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isOverBudget
                      ? Theme.of(context).colorScheme.error
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetDialog extends StatefulWidget {
  final String title;
  final List<CategoryModel> categories;
  final String? initialCategoryId;
  final double? initialAmount;
  final bool lockCategory;

  const _BudgetDialog({
    required this.title,
    required this.categories,
    this.initialCategoryId,
    this.initialAmount,
    this.lockCategory = false,
  });

  @override
  State<_BudgetDialog> createState() => _BudgetDialogState();
}

class _BudgetDialogState extends State<_BudgetDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();

    _selectedCategoryId =
        widget.initialCategoryId ?? widget.categories.firstOrNull?.id;

    if (widget.initialAmount != null) {
      _amountController.text = widget.initialAmount!.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final categoryId = _selectedCategoryId;

    if (categoryId == null || categoryId.isEmpty) {
      return;
    }

    final amount = double.tryParse(
      _amountController.text.trim().replaceAll(',', '.'),
    );

    if (amount == null || amount <= 0) {
      return;
    }

    Navigator.pop(
      context,
      _BudgetDialogResult(
        categoryId: categoryId,
        amount: amount,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedCategoryId,
                decoration: const InputDecoration(
                  labelText: 'Kategorie',
                  border: OutlineInputBorder(),
                ),
                items: widget.categories.map((category) {
                  return DropdownMenuItem<String>(
                    value: category.id,
                    child: Text(category.name),
                  );
                }).toList(),
                onChanged: widget.lockCategory
                    ? null
                    : (value) {
                        setState(() {
                          _selectedCategoryId = value;
                        });
                      },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Bitte Kategorie auswählen';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Budgetbetrag',
                  hintText: 'z.B. 400',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';

                  if (text.isEmpty) {
                    return 'Bitte Betrag eingeben';
                  }

                  final amount = double.tryParse(text.replaceAll(',', '.'));

                  if (amount == null || amount <= 0) {
                    return 'Bitte gültigen Betrag eingeben';
                  }

                  return null;
                },
                onFieldSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}

class _BudgetDialogResult {
  final String categoryId;
  final double amount;

  const _BudgetDialogResult({
    required this.categoryId,
    required this.amount,
  });
}
