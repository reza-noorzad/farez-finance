import 'package:flutter/material.dart';

import '../../shared/models/account_model.dart';
import '../../shared/models/debt_model.dart';
import '../../shared/models/financial_transaction_model.dart';

class EditDebtResult {
  final DebtModel debt;
  final FinancialTransactionModel transaction;

  const EditDebtResult({
    required this.debt,
    required this.transaction,
  });
}

class EditDebtPage extends StatefulWidget {
  final DebtModel debt;
  final double alreadyPaidAmount;
  final List<AccountModel> accounts;

  const EditDebtPage({
    super.key,
    required this.debt,
    required this.alreadyPaidAmount,
    required this.accounts,
  });

  @override
  State<EditDebtPage> createState() => _EditDebtPageState();
}

class _EditDebtPageState extends State<EditDebtPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _personController;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;

  late DebtKind _kind;
  AccountModel? _selectedAccount;
  late DateTime _debtDate;
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();

    _personController = TextEditingController(text: widget.debt.personName);
    _amountController = TextEditingController(
      text: widget.debt.originalAmount.toStringAsFixed(2),
    );
    _noteController = TextEditingController(text: widget.debt.note ?? '');

    _kind = widget.debt.kind;
    _debtDate = widget.debt.debtDate;
    _dueDate = widget.debt.dueDate;

    for (final account in widget.accounts) {
      if (account.id == widget.debt.accountId) {
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

      if (_dueDate != null && _dueDate!.isBefore(_debtDate)) {
        _dueDate = null;
      }
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

  void _clearDueDate() {
    setState(() {
      _dueDate = null;
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

    final updatedDebt = widget.debt.copyWith(
      personName: _personController.text.trim(),
      kind: _kind,
      originalAmount: amount,
      debtDate: _debtDate,
      dueDate: _dueDate,
      accountId: _selectedAccount!.id,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      isActive: true,
    );

    final transaction = FinancialTransactionModel(
      id: 'debt_${updatedDebt.id}',
      type: _kind == DebtKind.moneyLent
          ? FinancialTransactionType.debtGiven
          : FinancialTransactionType.debtBorrowed,
      amount: amount,
      transactionDate: _debtDate,
      createdAt: updatedDebt.createdAt,
      title: _kind == DebtKind.moneyLent
          ? 'Geld verliehen: ${updatedDebt.personName}'
          : 'Geld geliehen: ${updatedDebt.personName}',
      fromAccountId: _kind == DebtKind.moneyLent ? _selectedAccount!.id : null,
      toAccountId: _kind == DebtKind.moneyBorrowed ? _selectedAccount!.id : null,
      debtId: updatedDebt.id,
      note: updatedDebt.note,
    );

    Navigator.pop(
      context,
      EditDebtResult(
        debt: updatedDebt,
        transaction: transaction,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMoneyLent = _kind == DebtKind.moneyLent;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Schuld bearbeiten'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.alreadyPaidAmount > 0)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Bereits bezahlt: €${widget.alreadyPaidAmount.toStringAsFixed(2)}. '
                  'Der ursprüngliche Betrag darf nicht kleiner als dieser Betrag sein.',
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
                    labelText: 'Ursprünglicher Betrag',
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

                    if (parsed < widget.alreadyPaidAmount) {
                      return 'Betrag darf nicht kleiner als bereits bezahlt sein';
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
                    trailing: _dueDate == null
                        ? const Icon(Icons.chevron_right)
                        : IconButton(
                            onPressed: _clearDueDate,
                            icon: const Icon(Icons.close),
                          ),
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
                    onPressed: _save,
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
