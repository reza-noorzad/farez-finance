import 'package:flutter/material.dart';

import '../../shared/models/account_model.dart';
import '../../shared/models/category_model.dart';
import '../../shared/models/expense_model.dart';
import '../../shared/models/financial_transaction_model.dart';

class EditExpenseResult {
  final ExpenseModel expense;
  final FinancialTransactionModel transaction;

  const EditExpenseResult({
    required this.expense,
    required this.transaction,
  });
}

class EditExpensePage extends StatefulWidget {
  final ExpenseModel expense;
  final FinancialTransactionModel transaction;
  final List<CategoryModel> categories;
  final List<AccountModel> accounts;

  const EditExpensePage({
    super.key,
    required this.expense,
    required this.transaction,
    required this.categories,
    required this.accounts,
  });

  @override
  State<EditExpensePage> createState() => _EditExpensePageState();
}

class _EditExpensePageState extends State<EditExpensePage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _storeController;
  late final TextEditingController _noteController;

  CategoryModel? _selectedCategory;
  AccountModel? _selectedAccount;
  late DateTime _selectedDate;
  late bool _isRecurring;
  late bool _affectsBalance;

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(text: widget.expense.title);
    _amountController = TextEditingController(
      text: widget.expense.amount.toStringAsFixed(2),
    );
    _storeController = TextEditingController(
      text: widget.expense.storeName ?? widget.expense.title,
    );
    _noteController = TextEditingController(text: widget.expense.note ?? '');

    _selectedDate = widget.expense.transactionDate;
    _isRecurring = widget.expense.isRecurring;
    _affectsBalance = widget.transaction.affectsBalance;

    for (final category in widget.categories) {
      if (category.id == widget.expense.categoryId) {
        _selectedCategory = category;
        break;
      }
    }

    for (final account in widget.accounts) {
      if (account.id == widget.transaction.fromAccountId) {
        _selectedAccount = account;
        break;
      }
    }

    if (_selectedAccount == null && widget.accounts.isNotEmpty) {
      _selectedAccount = widget.accounts.first;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _storeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (pickedDate == null) {
      return;
    }

    setState(() {
      _selectedDate = pickedDate;
    });
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day.$month.$year';
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedAccount == null) {
      return;
    }

    final amount = double.parse(
      _amountController.text.trim().replaceAll(',', '.'),
    );

    final title = _titleController.text.trim();
    final storeName = _storeController.text.trim().isEmpty
        ? null
        : _storeController.text.trim();
    final note = _noteController.text.trim();
    final categoryId = _selectedCategory?.id ?? '';

    final updatedExpense = widget.expense.copyWith(
      title: title,
      categoryId: categoryId,
      amount: amount,
      transactionDate: _selectedDate,
      storeName: storeName,
      note: note.isEmpty ? null : note,
      isRecurring: _isRecurring,
    );

    final updatedTransaction = widget.transaction.copyWith(
      id: widget.transaction.id,
      type: FinancialTransactionType.expense,
      amount: amount,
      transactionDate: _selectedDate,
      title: title,
      fromAccountId: _selectedAccount!.id,
      toAccountId: null,
      categoryId: categoryId.isEmpty ? null : categoryId,
      note: note.isEmpty ? null : note,
      affectsBalance: _affectsBalance,
    );

    Navigator.pop(
      context,
      EditExpenseResult(
        expense: updatedExpense,
        transaction: updatedTransaction,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSave = widget.accounts.isNotEmpty;
    final hasCategories = widget.categories.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ausgabe bearbeiten'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!canSave)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Du brauchst mindestens ein Konto.',
                ),
              ),
            ),
          if (!hasCategories)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Keine Kategorie vorhanden. Die Ausgabe kann trotzdem gespeichert werden.',
                ),
              ),
            ),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Bitte Name eingeben';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _storeController,
                  decoration: const InputDecoration(
                    labelText: 'Geschäft optional',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<CategoryModel>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Ausgabenkategorie',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.categories.map((category) {
                    return DropdownMenuItem<CategoryModel>(
                      value: category,
                      child: Text(category.name),
                    );
                  }).toList(),
                  onChanged: hasCategories
                      ? (value) {
                          setState(() {
                            _selectedCategory = value;
                          });
                        }
                      : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<AccountModel>(
                  value: _selectedAccount,
                  decoration: const InputDecoration(
                    labelText: 'Bezahlt von',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.accounts.map((account) {
                    return DropdownMenuItem<AccountModel>(
                      value: account,
                      child: Text(account.name),
                    );
                  }).toList(),
                  onChanged: canSave
                      ? (value) {
                          setState(() {
                            _selectedAccount = value;
                          });
                        }
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Betrag',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';

                    if (text.isEmpty) {
                      return 'Bitte Betrag eingeben';
                    }

                    final parsed = double.tryParse(text.replaceAll(',', '.'));

                    if (parsed == null || parsed <= 0) {
                      return 'Bitte gültigen Betrag eingeben';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.calendar_month),
                    title: const Text('Datum'),
                    subtitle: Text(_formatDate(_selectedDate)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _noteController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notiz optional',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  value: _affectsBalance,
                  onChanged: (value) {
                    setState(() {
                      _affectsBalance = value;
                    });
                  },
                  title: const Text('Kontostand ändern'),
                  subtitle: const Text(
                    'Aus: nur für Berichte speichern, ohne Bank/Cash zu verändern.',
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  value: _isRecurring,
                  onChanged: (value) {
                    setState(() {
                      _isRecurring = value;
                    });
                  },
                  title: const Text('Wiederkehrende Ausgabe'),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: canSave ? _save : null,
                    icon: const Icon(Icons.save),
                    label: const Text('Änderungen speichern'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
