import 'package:flutter/material.dart';

import '../../shared/models/account_model.dart';
import '../../shared/models/debt_model.dart';
import '../../shared/models/debt_payment_model.dart';
import '../../shared/models/financial_transaction_model.dart';

class AddDebtPaymentResult {
  final DebtPaymentModel payment;
  final FinancialTransactionModel transaction;

  const AddDebtPaymentResult({
    required this.payment,
    required this.transaction,
  });
}

class AddDebtPaymentPage extends StatefulWidget {
  final DebtModel debt;
  final double remainingAmount;
  final List<AccountModel> accounts;

  const AddDebtPaymentPage({
    super.key,
    required this.debt,
    required this.remainingAmount,
    required this.accounts,
  });

  @override
  State<AddDebtPaymentPage> createState() => _AddDebtPaymentPageState();
}

class _AddDebtPaymentPageState extends State<AddDebtPaymentPage> {
  final _formKey = GlobalKey<FormState>();

  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  AccountModel? _selectedAccount;
  DateTime _paymentDate = DateTime.now();

  bool get _isMoneyLent {
    return widget.debt.kind == DebtKind.moneyLent;
  }

  @override
  void initState() {
    super.initState();

    if (widget.accounts.isNotEmpty) {
      _selectedAccount = widget.accounts.first;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickPaymentDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (pickedDate == null) {
      return;
    }

    setState(() {
      _paymentDate = pickedDate;
    });
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day.$month.$year';
  }

  void _savePayment() {
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

    final payment = DebtPaymentModel(
      id: now.microsecondsSinceEpoch.toString(),
      debtId: widget.debt.id,
      amount: amount,
      paymentDate: _paymentDate,
      createdAt: now,
      accountId: _selectedAccount!.id,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
    );

    final transaction = FinancialTransactionModel(
      id: 'debt_payment_${payment.id}',
      type: _isMoneyLent
          ? FinancialTransactionType.debtReturned
          : FinancialTransactionType.debtPaidBack,
      amount: amount,
      transactionDate: _paymentDate,
      createdAt: now,
      title: _isMoneyLent
          ? 'Rückzahlung erhalten: ${widget.debt.personName}'
          : 'Schuld zurückgezahlt: ${widget.debt.personName}',
      fromAccountId: _isMoneyLent ? null : _selectedAccount!.id,
      toAccountId: _isMoneyLent ? _selectedAccount!.id : null,
      debtId: widget.debt.id,
      note: payment.note,
    );

    Navigator.pop(
      context,
      AddDebtPaymentResult(
        payment: payment,
        transaction: transaction,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _isMoneyLent ? 'Rückzahlung erhalten' : 'Schuld zurückzahlen';

    final accountLabel = _isMoneyLent ? 'Geld erhalten auf' : 'Bezahlt von';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Offen: €${widget.remainingAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          Form(
            key: _formKey,
            child: Column(
              children: [
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

                    if (parsed > widget.remainingAmount) {
                      return 'Betrag ist höher als der offene Betrag';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                DropdownButtonFormField<AccountModel>(
                  value: _selectedAccount,
                  decoration: InputDecoration(
                    labelText: accountLabel,
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
                    subtitle: Text(_formatDate(_paymentDate)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _pickPaymentDate,
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
                    onPressed: _savePayment,
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
