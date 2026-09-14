import 'package:flutter/material.dart';

import '../../shared/models/account_model.dart';
import '../../shared/models/debt_model.dart';
import '../../shared/models/financial_transaction_model.dart';

class AddDebtResult {
  final DebtModel debt;
  final FinancialTransactionModel transaction;

  const AddDebtResult({
    required this.debt,
    required this.transaction,
  });
}

class AddDebtPage extends StatefulWidget {
  final List<AccountModel> accounts;

  const AddDebtPage({
    super.key,
    required this.accounts,
  });

  @override
  State<AddDebtPage> createState() => _AddDebtPageState();
}

class _AddDebtPageState extends State<AddDebtPage> {
  final _formKey = GlobalKey<FormState>();

  final _personController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  DebtKind _kind = DebtKind.moneyLent;
  AccountModel? _selectedAccount;
  DateTime _debtDate = DateTime.now();
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();

    if (widget.accounts.isNotEmpty) {
      _selectedAccount = widget.accounts.first;
    }
  }

  @override
  void dispose() {
    _personController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDebtDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _debtDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (pickedDate == null) {
      return;
    }

    setState(() {
      _debtDate = pickedDate;
    });
  }

  Future<void> _pickDueDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? _debtDate,
      firstDate: _debtDate,
      lastDate: DateTime(2100),
    );

    if (pickedDate == null) {
      return;
    }

    setState(() {
      _dueDate = pickedDate;
    });
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day.$month.$year';
  }

  void _saveDebt() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte Konto auswählen.'),
        ),
      );

      return;
    }

    final now = DateTime.now();
    final amount = double.parse(
      _amountController.text.trim().replaceAll(',', '.'),
    );

    final debtId = now.microsecondsSinceEpoch.toString();

    final debt = DebtModel(
      id: debtId,
      personName: _personController.text.trim(),
      kind: _kind,
      originalAmount: amount,
      debtDate: _debtDate,
      createdAt: now,
      dueDate: _dueDate,
      accountId: _selectedAccount!.id,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      isActive: true,
    );

    final transaction = FinancialTransactionModel(
      id: 'tx_debt_${now.microsecondsSinceEpoch}',
      type: _kind == DebtKind.moneyLent
          ? FinancialTransactionType.debtGiven
          : FinancialTransactionType.debtBorrowed,
      amount: amount,
      transactionDate: _debtDate,
      createdAt: now,
      title: _kind == DebtKind.moneyLent
          ? 'Geld verliehen: ${debt.personName}'
          : 'Geld geliehen: ${debt.personName}',
      fromAccountId: _kind == DebtKind.moneyLent ? _selectedAccount!.id : null,
      toAccountId: _kind == DebtKind.moneyBorrowed ? _selectedAccount!.id : null,
      debtId: debt.id,
      note: debt.note,
    );

    Navigator.pop(
      context,
      AddDebtResult(
        debt: debt,
        transaction: transaction,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMoneyLent = _kind == DebtKind.moneyLent;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Schuld hinzufügen'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Schulden sind keine normalen Einnahmen oder Ausgaben. '
                'Sie werden separat als Schuldbewegungen gezählt.',
              ),
            ),
          ),

          const SizedBox(height: 16),

          Form(
            key: _formKey,
            child: Column(
              children: [
                SegmentedButton<DebtKind>(
                  segments: const [
                    ButtonSegment(
                      value: DebtKind.moneyLent,
                      label: Text('Ich habe Geld gegeben'),
                      icon: Icon(Icons.north_east),
                    ),
                    ButtonSegment(
                      value: DebtKind.moneyBorrowed,
                      label: Text('Ich habe Geld bekommen'),
                      icon: Icon(Icons.south_west),
                    ),
                  ],
                  selected: {_kind},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _kind = selection.first;
                    });
                  },
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _personController,
                  decoration: const InputDecoration(
                    labelText: 'Person',
                    hintText: 'Name der Person',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Bitte Person eingeben';
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
                    labelText: 'Betrag',
                    hintText: 'Beispiel: 100',
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

                DropdownButtonFormField<AccountModel>(
                  value: _selectedAccount,
                  decoration: InputDecoration(
                    labelText: isMoneyLent
                        ? 'Geld gegeben von'
                        : 'Geld erhalten auf',
                    border: const OutlineInputBorder(),
                  ),
                  items: widget.accounts.map((account) {
                    return DropdownMenuItem<AccountModel>(
                      value: account,
                      child: Text(account.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedAccount = value;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Bitte Konto auswählen';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                Card(
                  child: ListTile(
                    leading: const Icon(Icons.calendar_month),
                    title: const Text('Datum'),
                    subtitle: Text(_formatDate(_debtDate)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _pickDebtDate,
                  ),
                ),

                const SizedBox(height: 12),

                Card(
                  child: ListTile(
                    leading: const Icon(Icons.event_available),
                    title: const Text('Fälligkeitsdatum optional'),
                    subtitle: Text(
                      _dueDate == null
                          ? 'Kein Datum ausgewählt'
                          : _formatDate(_dueDate!),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _pickDueDate,
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

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saveDebt,
                    icon: const Icon(Icons.save),
                    label: const Text('Speichern'),
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
