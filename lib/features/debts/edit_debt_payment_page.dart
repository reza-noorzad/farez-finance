import 'package:flutter/material.dart';

import '../../shared/models/account_model.dart';
import '../../shared/models/debt_model.dart';
import '../../shared/models/debt_payment_model.dart';
import '../../shared/models/financial_transaction_model.dart';

class EditDebtPaymentResult {
  final DebtPaymentModel payment;
  final FinancialTransactionModel transaction;

  const EditDebtPaymentResult({
    required this.payment,
    required this.transaction,
  });
}

class EditDebtPaymentPage extends StatefulWidget {
  final DebtModel debt;
  final DebtPaymentModel payment;
  final double maxAmount;
  final List<AccountModel> accounts;

  const EditDebtPaymentPage({
    super.key,
    required this.debt,
    required this.payment,
    required this.maxAmount,
    required this.accounts,
  });

  @override
  State<EditDebtPaymentPage> createState() => _EditDebtPaymentPageState();
}

class _EditDebtPaymentPageState extends State<EditDebtPaymentPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _amountController;
  late final TextEditingController _noteController;

  AccountModel? _selectedAccount;
  late DateTime _paymentDate;

  bool get _isMoneyLent {
    return widget.debt.kind == DebtKind.moneyLent;
  }

  @override
  void initState() {
    super.initState();

    _amountController = TextEditingController(
      text: widget.payment.amount.toStringAsFixed(2),
    );
    _noteController = TextEditingController(text: widget.payment.note ?? '');
    _paymentDate = widget.payment.paymentDate;

    for (final account in widget.accounts) {
      if (account.id == widget.payment.accountId) {
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

    final updatedPayment = widget.payment.copyWith(
      amount: amount,
      paymentDate: _paymentDate,
      accountId: _selectedAccount!.id,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
    );

    final transaction = FinancialTransactionModel(
      id: 'debt_payment_${updatedPayment.id}',
      type: _isMoneyLent
          ? FinancialTransactionType.debtReturned
          : FinancialTransactionType.debtPaidBack,
      amount: amount,
      transactionDate: _paymentDate,
      createdAt: updatedPayment.createdAt,
      title: _isMoneyLent
          ? 'Rückzahlung erhalten: ${widget.debt.personName}'
          : 'Schuld zurückgezahlt: ${widget.debt.personName}',
      fromAccountId: _isMoneyLent ? null : _selectedAccount!.id,
      toAccountId: _isMoneyLent ? _selectedAccount!.id : null,
      debtId: widget.debt.id,
      note: updatedPayment.note,
    );

    Navigator.pop(
      context,
      EditDebtPaymentResult(
        payment: updatedPayment,
        transaction: transaction,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accountLabel = _isMoneyLent ? 'Geld erhalten auf' : 'Bezahlt von';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zahlung bearbeiten'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Maximal erlaubt: €${widget.maxAmount.toStringAsFixed(2)}',
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

                    if (parsed > widget.maxAmount) {
                      return 'Betrag ist höher als erlaubt';
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
