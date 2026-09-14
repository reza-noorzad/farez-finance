import 'package:flutter/material.dart';

import '../../core/localization/app_strings.dart';
import '../../shared/models/account_model.dart';
import '../../shared/models/category_model.dart';
import '../../shared/models/financial_transaction_model.dart';
import '../../shared/models/income_model.dart';
import '../../shared/widgets/help_text_card.dart';
import '../categories/add_category_page.dart';
import '../categories/category_mock_data.dart';

class AddIncomeResult {
  final IncomeModel income;
  final FinancialTransactionModel transaction;

  const AddIncomeResult({
    required this.income,
    required this.transaction,
  });
}

class AddIncomePage extends StatefulWidget {
  final List<AccountModel> accounts;

  const AddIncomePage({
    super.key,
    required this.accounts,
  });

  @override
  State<AddIncomePage> createState() => _AddIncomePageState();
}

class _AddIncomePageState extends State<AddIncomePage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  late List<CategoryModel> _incomeCategories;

  CategoryModel? _selectedCategory;
  AccountModel? _selectedAccount;
  DateTime _selectedDate = DateTime.now();
  bool _isRecurring = false;
  bool _affectsBalance = true;

  @override
  void initState() {
    super.initState();

    _incomeCategories = CategoryMockData.getIncomeCategories();

    if (_incomeCategories.isNotEmpty) {
      _selectedCategory = _incomeCategories.first;
    }

    if (widget.accounts.isNotEmpty) {
      _selectedAccount = widget.accounts.first;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _openAddCategoryPage() async {
    final result = await Navigator.push<CategoryModel>(
      context,
      MaterialPageRoute(
        builder: (context) => const AddCategoryPage(),
      ),
    );

    if (result == null) {
      return;
    }

    setState(() {
      CategoryMockData.categories.add(result);
      _incomeCategories = CategoryMockData.getIncomeCategories();

      if (result.direction == CategoryDirection.income ||
          result.direction == CategoryDirection.both) {
        _selectedCategory = result;
      }
    });
  }

  void _showCategoryHelpDialog() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hilfe: Einnahmekategorie'),
          content: const Text(
            'Kategorien werden im nächsten Schritt vollständig mit Supabase verbunden.\n\n'
            'Du kannst Einnahmen jetzt auch ohne Kategorie speichern.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
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

  bool get _canSave {
    return _selectedAccount != null;
  }

  void _saveIncome() {
    if (!_canSave) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final now = DateTime.now();
    final amount = double.parse(
      _amountController.text.trim().replaceAll(',', '.'),
    );

    final name = _nameController.text.trim();
    final note = _noteController.text.trim();
    final categoryId = _selectedCategory?.id ?? '';

    final income = IncomeModel(
      id: now.microsecondsSinceEpoch.toString(),
      title: name,
      categoryId: categoryId,
      amount: amount,
      transactionDate: _selectedDate,
      createdAt: now,
      note: note.isEmpty ? null : note,
      isRecurring: _isRecurring,
    );

    final transaction = FinancialTransactionModel(
      id: 'tx_${now.microsecondsSinceEpoch}',
      type: FinancialTransactionType.income,
      amount: amount,
      transactionDate: _selectedDate,
      createdAt: now,
      title: name,
      fromAccountId: null,
      toAccountId: _selectedAccount!.id,
      categoryId: categoryId.isEmpty ? null : categoryId,
      note: note.isEmpty ? null : note,
      affectsBalance: _affectsBalance,
    );

    Navigator.pop(
      context,
      AddIncomeResult(
        income: income,
        transaction: transaction,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasCategories = _incomeCategories.isNotEmpty;
    final hasAccounts = widget.accounts.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.addIncome),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!hasAccounts)
            const HelpTextCard(
              title: 'Noch kein Konto vorhanden',
              message:
                  'Bitte erstelle zuerst ein Konto oder eine Geldquelle, bevor du eine Einnahme speicherst.',
              icon: Icons.account_balance_wallet_outlined,
            ),
          if (!hasAccounts) const SizedBox(height: 16),
          if (!hasCategories)
            const HelpTextCard(
              title: 'Noch keine Kategorien',
              message:
                  'Du kannst die Einnahme jetzt trotzdem speichern. Kategorien verbinden wir im nächsten Schritt mit Supabase.',
              icon: Icons.info_outline,
            ),
          if (!hasCategories) const SizedBox(height: 16),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name / Quelle',
                    hintText: 'Beispiel: Gehalt, AMS, Rückzahlung',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Bitte Name oder Quelle eingeben';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<CategoryModel>(
                  value: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: AppStrings.incomeCategory,
                    border: const OutlineInputBorder(),
                  ),
                  items: _incomeCategories.map((category) {
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
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _openAddCategoryPage,
                      icon: const Icon(Icons.add),
                      label: const Text('Kategorie hinzufügen'),
                    ),
                    IconButton(
                      onPressed: _showCategoryHelpDialog,
                      icon: const Icon(Icons.help_outline),
                      tooltip: 'Hilfe',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<AccountModel>(
                  value: _selectedAccount,
                  decoration: InputDecoration(
                    labelText: AppStrings.destinationAccount,
                    border: const OutlineInputBorder(),
                  ),
                  items: widget.accounts.map((account) {
                    return DropdownMenuItem<AccountModel>(
                      value: account,
                      child: Text(account.name),
                    );
                  }).toList(),
                  onChanged: hasAccounts
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
                  decoration: InputDecoration(
                    labelText: AppStrings.amount,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';

                    if (text.isEmpty) {
                      return 'Bitte Betrag eingeben';
                    }

                    final parsedValue = double.tryParse(
                      text.replaceAll(',', '.'),
                    );

                    if (parsedValue == null || parsedValue <= 0) {
                      return 'Bitte gültigen Betrag eingeben';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(AppStrings.incomeDate),
                  subtitle: Text(_formatDate(_selectedDate)),
                  trailing: const Icon(Icons.calendar_month),
                  onTap: _pickDate,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _noteController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: AppStrings.note,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Kontostand ändern'),
                  subtitle: const Text(
                    'Aus: nur für Berichte speichern, ohne Bank/Cash zu verändern.',
                  ),
                  value: _affectsBalance,
                  onChanged: (value) {
                    setState(() {
                      _affectsBalance = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(AppStrings.recurringIncome),
                  subtitle: const Text(
                    'Später für monatliche Einnahmen verwenden',
                  ),
                  value: _isRecurring,
                  onChanged: (value) {
                    setState(() {
                      _isRecurring = value;
                    });
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _canSave ? _saveIncome : null,
                    icon: const Icon(Icons.save),
                    label: Text(AppStrings.saveIncome),
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
