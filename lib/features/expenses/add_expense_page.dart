import 'package:flutter/material.dart';

import '../../core/localization/app_strings.dart';
import '../../shared/models/account_model.dart';
import '../../shared/models/category_model.dart';
import '../../shared/models/expense_model.dart';
import '../../shared/models/expense_item_model.dart';
import '../../shared/models/financial_transaction_model.dart';
import '../../shared/widgets/help_text_card.dart';
import '../categories/add_category_page.dart';
import '../categories/category_mock_data.dart';
import 'receipt_json_parser.dart';

enum ExpenseEntryMethod {
  manual,
  receiptText,
  photoScanLater,
  pdfLater,
}

enum ReceiptAmountMismatchAction {
  useReceiptAmount,
  saveAnyway,
}

class AddExpenseResult {
  final ExpenseModel expense;
  final FinancialTransactionModel transaction;

  const AddExpenseResult({
    required this.expense,
    required this.transaction,
  });
}

class AddExpensePage extends StatefulWidget {
  final List<AccountModel> accounts;

  const AddExpensePage({
    super.key,
    required this.accounts,
  });

  @override
  State<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _receiptTextController = TextEditingController();

  late List<CategoryModel> _expenseCategories;

  CategoryModel? _selectedCategory;
  AccountModel? _selectedAccount;
  DateTime _selectedDate = DateTime.now();
  bool _isRecurring = false;
  bool _affectsBalance = true;
  ExpenseEntryMethod _entryMethod = ExpenseEntryMethod.manual;

  String? _reviewedReceiptText;
  List<ExpenseItemModel>? _reviewedItems;

  @override
  void initState() {
    super.initState();

    _expenseCategories = CategoryMockData.getExpenseCategories();

    if (_expenseCategories.isNotEmpty) {
      _selectedCategory = _expenseCategories.first;
    }

    if (widget.accounts.isNotEmpty) {
      _selectedAccount = widget.accounts.first;
    }

    _receiptTextController.addListener(() {
      if (!mounted) {
        return;
      }

      if (_entryMethod == ExpenseEntryMethod.receiptText) {
        if (_reviewedReceiptText != _receiptTextController.text.trim()) {
          _reviewedItems = null;
          _reviewedReceiptText = null;
        }
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    _receiptTextController.dispose();
    super.dispose();
  }

  ParsedReceiptData? _parseReceiptPreview() {
    if (_entryMethod != ExpenseEntryMethod.receiptText) {
      return null;
    }

    final rawText = _receiptTextController.text.trim();

    if (rawText.isEmpty) {
      return null;
    }

    return ReceiptJsonParser.parse(
      rawText: rawText,
      expenseId: 'preview',
      fallbackDate: _selectedDate,
      fallbackStoreName: _nameController.text.trim().isEmpty
          ? null
          : _nameController.text.trim(),
    );
  }

  double? _receiptTotalAmount(ParsedReceiptData? receipt) {
    if (receipt == null) {
      return null;
    }

    if (receipt.totalAmount != null && receipt.totalAmount! > 0) {
      return receipt.totalAmount;
    }

    if (receipt.items.isEmpty) {
      return null;
    }

    final sum = receipt.items.fold<double>(
      0,
      (total, item) => total + item.totalPrice,
    );

    if (sum <= 0) {
      return null;
    }

    return sum;
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

      _expenseCategories = CategoryMockData.getExpenseCategories();

      if (result.direction == CategoryDirection.expense ||
          result.direction == CategoryDirection.both) {
        _selectedCategory = result;
      } else if (_expenseCategories.isNotEmpty) {
        _selectedCategory = _expenseCategories.first;
      }
    });
  }

  void _showCategoryHelpDialog() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hilfe: Ausgabenkategorie'),
          content: const Text(
            'Kategorien werden im nächsten Schritt vollständig mit Supabase verbunden.\n\n'
            'Du kannst Ausgaben jetzt auch ohne Kategorie speichern.',
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

  String _entryMethodLabel(ExpenseEntryMethod method) {
    switch (method) {
      case ExpenseEntryMethod.manual:
        return AppStrings.manual;
      case ExpenseEntryMethod.receiptText:
        return AppStrings.receiptText;
      case ExpenseEntryMethod.photoScanLater:
        return AppStrings.photoScanLater;
      case ExpenseEntryMethod.pdfLater:
        return AppStrings.pdfLater;
    }
  }

  bool get _canSave {
    return _selectedAccount != null;
  }

  Future<void> _saveExpense() async {
    if (!_canSave) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final now = DateTime.now();
    final expenseId = now.microsecondsSinceEpoch.toString();

    final parsedReceipt = ReceiptJsonParser.parse(
      rawText: _receiptTextController.text.trim(),
      expenseId: expenseId,
      fallbackDate: _selectedDate,
      fallbackStoreName: _nameController.text.trim().isEmpty
          ? null
          : _nameController.text.trim(),
    );

    final typedName = _nameController.text.trim();
    final typedAmountText = _amountController.text.trim();
    final note = _noteController.text.trim();

    final finalName = typedName.isNotEmpty
        ? typedName
        : parsedReceipt?.storeName?.trim().isNotEmpty == true
            ? parsedReceipt!.storeName!.trim()
            : 'Ausgabe';

    final amountFromText = double.tryParse(
      typedAmountText.replaceAll(',', '.'),
    );

    final receiptAmount = _receiptTotalAmount(parsedReceipt);

    double finalAmount = amountFromText ?? receiptAmount ?? 0;

    if (amountFromText != null && receiptAmount != null) {
      final difference = (amountFromText - receiptAmount).abs();

      if (difference > 0.01) {
        final action = await _showReceiptAmountMismatchDialog(
          typedAmount: amountFromText,
          receiptAmount: receiptAmount,
        );

        if (action == null) {
          return;
        }

        if (action == ReceiptAmountMismatchAction.useReceiptAmount) {
          finalAmount = receiptAmount;
          _amountController.text = receiptAmount.toStringAsFixed(2);
        }

        if (action == ReceiptAmountMismatchAction.saveAnyway) {
          finalAmount = amountFromText;
        }
      }
    }

    final finalDate = parsedReceipt?.date ?? _selectedDate;
    final finalStoreName = parsedReceipt?.storeName ?? finalName;
    final parsedItems = _reviewedReceiptText == _receiptTextController.text.trim()
        ? (_reviewedItems ?? parsedReceipt?.items ?? [])
        : (parsedReceipt?.items ?? []);

    final categoryId = _selectedCategory?.id ?? '';

    final expense = ExpenseModel(
      id: expenseId,
      title: finalName,
      categoryId: categoryId,
      amount: finalAmount,
      transactionDate: finalDate,
      createdAt: now,
      storeName: finalStoreName,
      note: note.isEmpty ? null : note,
      isRecurring: _isRecurring,
      items: parsedItems,
    );

    final transaction = FinancialTransactionModel(
      id: 'tx_${now.microsecondsSinceEpoch}',
      type: FinancialTransactionType.expense,
      amount: finalAmount,
      transactionDate: finalDate,
      createdAt: now,
      title: finalName,
      fromAccountId: _selectedAccount!.id,
      toAccountId: null,
      categoryId: categoryId.isEmpty ? null : categoryId,
      note: note.isEmpty ? null : note,
      affectsBalance: _affectsBalance,
    );

    if (!mounted) {
      return;
    }

    Navigator.pop(
      context,
      AddExpenseResult(
        expense: expense,
        transaction: transaction,
      ),
    );
  }

  Future<ReceiptAmountMismatchAction?> _showReceiptAmountMismatchDialog({
    required double typedAmount,
    required double receiptAmount,
  }) async {
    return showDialog<ReceiptAmountMismatchAction>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Betrag stimmt nicht überein'),
          content: Text(
            'Der eingegebene Betrag stimmt nicht mit dem Kassenzettel überein.\n\n'
            'Eingegebener Betrag: €${typedAmount.toStringAsFixed(2)}\n'
            'Kassenzettel-Summe: €${receiptAmount.toStringAsFixed(2)}\n\n'
            'Was möchtest du tun?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  ReceiptAmountMismatchAction.saveAnyway,
                );
              },
              child: const Text('Trotzdem speichern'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  ReceiptAmountMismatchAction.useReceiptAmount,
                );
              },
              child: const Text('Betrag übernehmen'),
            ),
          ],
        );
      },
    );
  }


  Future<void> _openReceiptItemReviewDialog(
    ParsedReceiptData receipt,
  ) async {
    final reviewed = await showDialog<List<ExpenseItemModel>>(
      context: context,
      builder: (context) {
        return _ReceiptItemReviewDialog(items: receipt.items);
      },
    );

    if (reviewed == null) {
      return;
    }

    setState(() {
      _reviewedReceiptText = _receiptTextController.text.trim();
      _reviewedItems = reviewed;
    });
  }

  List<ExpenseItemModel> _previewItems(ParsedReceiptData receipt) {
    if (_reviewedReceiptText == _receiptTextController.text.trim() &&
        _reviewedItems != null) {
      return _reviewedItems!;
    }

    return receipt.items;
  }

  @override
  Widget build(BuildContext context) {
    final hasCategories = _expenseCategories.isNotEmpty;
    final hasAccounts = widget.accounts.isNotEmpty;
    final parsedPreview = _parseReceiptPreview();
    final receiptPreviewTotal = _receiptTotalAmount(parsedPreview);
    final hasReceiptText = _receiptTextController.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.addExpense),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!hasAccounts)
            const HelpTextCard(
              title: 'Noch kein Konto vorhanden',
              message:
                  'Bitte erstelle zuerst ein Konto oder eine Geldquelle, bevor du eine Ausgabe speicherst.',
              icon: Icons.account_balance_wallet_outlined,
            ),
          if (!hasAccounts) const SizedBox(height: 16),
          if (!hasCategories)
            const HelpTextCard(
              title: 'Noch keine Kategorien',
              message:
                  'Du kannst die Ausgabe jetzt trotzdem speichern. Kategorien verbinden wir im nächsten Schritt mit Supabase.',
              icon: Icons.info_outline,
            ),
          if (!hasCategories) const SizedBox(height: 16),
          Form(
            key: _formKey,
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    AppStrings.entryMethod,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ExpenseEntryMethod.values.map((method) {
                    return ChoiceChip(
                      label: Text(_entryMethodLabel(method)),
                      selected: _entryMethod == method,
                      onSelected: (selected) {
                        if (!selected) {
                          return;
                        }

                        setState(() {
                          _entryMethod = method;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                if (_entryMethod == ExpenseEntryMethod.receiptText)
                  TextFormField(
                    controller: _receiptTextController,
                    minLines: 4,
                    maxLines: 10,
                    decoration: const InputDecoration(
                      labelText: 'Kassenzettel-Text',
                      hintText:
                          'JSON von ChatGPT hier einfügen. Danach erscheint unten eine einfache Vorschau.',
                      border: OutlineInputBorder(),
                    ),
                  ),
                if (_entryMethod == ExpenseEntryMethod.receiptText)
                  const SizedBox(height: 12),
                if (_entryMethod == ExpenseEntryMethod.receiptText &&
                    hasReceiptText &&
                    parsedPreview == null)
                  const _ReceiptErrorCard(),
                if (_entryMethod == ExpenseEntryMethod.receiptText &&
                    parsedPreview != null)
                  _ReceiptPreviewCard(
                    receipt: parsedPreview,
                    items: _previewItems(parsedPreview),
                    dateText: _formatDate(parsedPreview.date ?? _selectedDate),
                    totalAmount: receiptPreviewTotal,
                    onReview: () => _openReceiptItemReviewDialog(parsedPreview),
                  ),
                if (_entryMethod == ExpenseEntryMethod.receiptText)
                  const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name / Geschäft',
                    hintText:
                        'Beispiel: Lidl, Miete, Strom. Bei gültigem JSON kann dieses Feld leer bleiben.',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    final parsedReceipt = _parseReceiptPreview();

                    if (text.isEmpty &&
                        (parsedReceipt?.storeName == null ||
                            parsedReceipt!.storeName!.trim().isEmpty)) {
                      return 'Bitte Name oder Geschäft eingeben';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<CategoryModel>(
                  value: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: AppStrings.expenseCategory,
                    border: const OutlineInputBorder(),
                  ),
                  items: _expenseCategories.map((category) {
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
                    labelText: AppStrings.paidFromAccount,
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
                  decoration: const InputDecoration(
                    labelText: 'Betrag',
                    hintText:
                        'Bei gültigem JSON kann dieses Feld leer bleiben.',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    final parsedReceipt = _parseReceiptPreview();
                    final receiptAmount = _receiptTotalAmount(parsedReceipt);

                    if (text.isEmpty && receiptAmount != null) {
                      return null;
                    }

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
                  title: Text(AppStrings.expenseDate),
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
                  title: Text(AppStrings.recurringExpense),
                  subtitle: Text(AppStrings.useThisLaterForMonthlyExpenses),
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
                    onPressed: _canSave ? _saveExpense : null,
                    icon: const Icon(Icons.save),
                    label: Text(AppStrings.saveExpense),
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

class _ReceiptErrorCard extends StatelessWidget {
  const _ReceiptErrorCard();


  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.warning_amber_outlined),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Der Kassenzettel-Text konnte nicht gelesen werden. Bitte prüfe, ob es gültiges JSON ist.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _ReceiptPreviewCard extends StatelessWidget {
  final ParsedReceiptData receipt;
  final List<ExpenseItemModel> items;
  final String dateText;
  final double? totalAmount;
  final VoidCallback onReview;

  const _ReceiptPreviewCard({
    required this.receipt,
    required this.items,
    required this.dateText,
    required this.totalAmount,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    final reviewItems = items.where((item) => item.needsReview).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kassenzettel-Vorschau',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Geschäft: ${receipt.storeName ?? '-'}'),
            Text('Datum: $dateText'),
            Text('Gesamt: €${(totalAmount ?? 0).toStringAsFixed(2)}'),
            Text('Produkte: ${items.length}'),
            if (reviewItems.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Theme.of(context).colorScheme.errorContainer,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.rule_outlined,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${reviewItems.length} Produkte brauchen Prüfung. '
                        'Du kannst sie jetzt korrigieren oder trotzdem als Menge unbekannt speichern.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: onReview,
                      child: const Text('Jetzt prüfen'),
                    ),
                  ],
                ),
              ),
            ],
            const Divider(),
            if (items.isEmpty)
              const Text('Keine Produkte gefunden.')
            else
              for (final item in items.take(8))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        item.needsReview
                            ? Icons.warning_amber_outlined
                            : Icons.check_circle_outline,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${item.originalName ?? item.name}\n'
                          '${item.measurementLabel}',
                        ),
                      ),
                      Text(
                        '€${item.totalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
            if (items.length > 8)
              Text(
                '+ ${items.length - 8} weitere Produkte',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptItemReviewDialog extends StatefulWidget {
  final List<ExpenseItemModel> items;

  const _ReceiptItemReviewDialog({
    required this.items,
  });

  @override
  State<_ReceiptItemReviewDialog> createState() =>
      _ReceiptItemReviewDialogState();
}

class _ReceiptItemReviewDialogState extends State<_ReceiptItemReviewDialog> {
  late List<ExpenseItemModel> _items;
  final Map<String, TextEditingController> _weightControllers = {};
  final Map<String, TextEditingController> _volumeControllers = {};
  final Map<String, TextEditingController> _countControllers = {};

  @override
  void initState() {
    super.initState();

    _items = List<ExpenseItemModel>.from(widget.items);

    for (final item in _items.where((item) => item.needsReview)) {
      _weightControllers[item.id] = TextEditingController(
        text: item.weightGrams?.toStringAsFixed(0) ?? '',
      );
      _volumeControllers[item.id] = TextEditingController(
        text: item.volumeMl?.toStringAsFixed(0) ?? '',
      );
      _countControllers[item.id] = TextEditingController(
        text: item.countUnits?.toStringAsFixed(0) ?? '',
      );
    }
  }

  @override
  void dispose() {
    for (final controller in [
      ..._weightControllers.values,
      ..._volumeControllers.values,
      ..._countControllers.values,
    ]) {
      controller.dispose();
    }

    super.dispose();
  }

  double? _readNumber(TextEditingController controller) {
    final text = controller.text.trim().replaceAll(',', '.');

    if (text.isEmpty) {
      return null;
    }

    return double.tryParse(text);
  }

  void _save() {
    final updated = <ExpenseItemModel>[];

    for (final item in _items) {
      if (!item.needsReview) {
        updated.add(item);
        continue;
      }

      final weight = _readNumber(_weightControllers[item.id]!);
      final volume = _readNumber(_volumeControllers[item.id]!);
      final count = _readNumber(_countControllers[item.id]!);
      final hasMeasurement = weight != null || volume != null || count != null;

      updated.add(
        item.copyWith(
          weightGrams: weight,
          volumeMl: volume,
          countUnits: count,
          needsReview: !hasMeasurement,
          measurementStatus: hasMeasurement ? 'reviewed' : 'unknown',
          reviewReason:
              hasMeasurement ? null : 'Menge wurde nicht korrigiert.',
        ),
      );
    }

    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    final reviewItems = _items.where((item) => item.needsReview).toList();

    return AlertDialog(
      title: const Text('Produkte prüfen'),
      content: SizedBox(
        width: 520,
        child: reviewItems.isEmpty
            ? const Text('Keine Produkte brauchen Prüfung.')
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Nur Produkte mit wichtiger, aber fehlender Menge werden hier angezeigt. '
                      'Du kannst leer lassen, dann wird 1 Packung / Menge unbekannt gespeichert.',
                    ),
                    const SizedBox(height: 12),
                    for (final item in reviewItems)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.originalName ?? item.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text('${item.quantity.toStringAsFixed(0)} ${item.unit} · ${item.category}'),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _weightControllers[item.id],
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                      decoration: const InputDecoration(
                                        labelText: 'Gramm',
                                        hintText: 'z.B. 500',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: _volumeControllers[item.id],
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                      decoration: const InputDecoration(
                                        labelText: 'ml',
                                        hintText: 'z.B. 1000',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: _countControllers[item.id],
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                      decoration: const InputDecoration(
                                        labelText: 'Stück',
                                        hintText: 'z.B. 10',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}
