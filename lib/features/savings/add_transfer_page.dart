import 'package:flutter/material.dart';

import '../../shared/models/account_model.dart';
import '../../shared/models/financial_transaction_model.dart';

class AddTransferResult {
  final FinancialTransactionModel transaction;

  const AddTransferResult({
    required this.transaction,
  });
}

class AddTransferPage extends StatefulWidget {
  final List<AccountModel> accounts;

  const AddTransferPage({
    super.key,
    required this.accounts,
  });

  @override
  State<AddTransferPage> createState() => _AddTransferPageState();
}

class _AddTransferPageState extends State<AddTransferPage> {
  final _formKey = GlobalKey<FormState>();

  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  AccountModel? _fromAccount;
  AccountModel? _toAccount;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();

    // Standardmäßig wählen wir die ersten zwei Konten aus,
    // damit der Benutzer schneller einen Transfer erstellen kann.
    if (widget.accounts.isNotEmpty) {
      _fromAccount = widget.accounts.first;
    }

    if (widget.accounts.length > 1) {
      _toAccount = widget.accounts[1];
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    // Dieses Format zeigt das Datum benutzerfreundlich an.
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day.$month.$year';
  }

  String _accountKindLabel(AccountKind kind) {
    // Diese Funktion zeigt, ob es sich um ein normales Konto oder einen Fonds handelt.
    switch (kind) {
      case AccountKind.account:
        return 'Account';
      case AccountKind.fund:
        return 'Fund';
    }
  }

  Future<void> _pickDate() async {
    // Der Benutzer kann das Datum des Transfers auswählen.
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (pickedDate == null) return;

    setState(() {
      _selectedDate = pickedDate;
    });
  }

  void _saveTransfer() {
    // Das Formular wird geprüft, bevor der Transfer erstellt wird.
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_fromAccount == null || _toAccount == null) {
      return;
    }

    if (_fromAccount!.id == _toAccount!.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('From and To cannot be the same.'),
        ),
      );
      return;
    }

    final amount = double.parse(
      _amountController.text.trim().replaceAll(',', '.'),
    );

    final transactionId = DateTime.now().millisecondsSinceEpoch.toString();

    final transaction = FinancialTransactionModel(
      id: transactionId,
      type: FinancialTransactionType.transfer,
      amount: amount,
      transactionDate: _selectedDate,
      createdAt: DateTime.now(),
      title: 'Transfer',
      fromAccountId: _fromAccount!.id,
      toAccountId: _toAccount!.id,
      categoryId: null,
      travelPlanId: null,
      debtId: null,
      note: _noteController.text.trim().isEmpty
          ? '${_fromAccount!.name} → ${_toAccount!.name}'
          : _noteController.text.trim(),
    );

    Navigator.pop(
      context,
      AddTransferResult(transaction: transaction),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Diese Seite erstellt einen Transfer zwischen Accounts und Funds.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Transfer'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<AccountModel>(
              initialValue: _fromAccount,
              decoration: const InputDecoration(
                labelText: 'From',
                border: OutlineInputBorder(),
              ),
              items: widget.accounts.map((account) {
                return DropdownMenuItem(
                  value: account,
                  child: Text(
                    '${account.name} (${_accountKindLabel(account.kind)})',
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _fromAccount = value;
                });
              },
              validator: (value) {
                if (value == null) {
                  return 'Please select a source account';
                }

                return null;
              },
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<AccountModel>(
              initialValue: _toAccount,
              decoration: const InputDecoration(
                labelText: 'To',
                border: OutlineInputBorder(),
              ),
              items: widget.accounts.map((account) {
                return DropdownMenuItem(
                  value: account,
                  child: Text(
                    '${account.name} (${_accountKindLabel(account.kind)})',
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _toAccount = value;
                });
              },
              validator: (value) {
                if (value == null) {
                  return 'Please select a destination account';
                }

                return null;
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount',
                hintText: 'Example: 200',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter an amount';
                }

                final amount = double.tryParse(
                  value.trim().replaceAll(',', '.'),
                );

                if (amount == null || amount <= 0) {
                  return 'Please enter a valid amount';
                }

                return null;
              },
            ),

            const SizedBox(height: 16),

            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_month_outlined),
                title: const Text('Transfer Date'),
                subtitle: Text(_formatDate(_selectedDate)),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: _pickDate,
              ),
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Note',
                hintText: 'Optional note',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 24),

            FilledButton.icon(
              onPressed: _saveTransfer,
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Save Transfer'),
            ),
          ],
        ),
      ),
    );
  }
}