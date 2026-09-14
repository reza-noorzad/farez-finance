import 'package:flutter/material.dart';

import '../../shared/models/account_model.dart';
import '../../shared/models/travel_contribution_model.dart';
import '../../shared/models/travel_plan_model.dart';

class AddTravelContributionResult {
  final TravelContributionModel contribution;

  const AddTravelContributionResult({
    required this.contribution,
  });
}

class AddTravelContributionPage extends StatefulWidget {
  final TravelPlanModel travelPlan;
  final List<AccountModel> accounts;
  final Map<String, double> availableAmountByAccountId;

  const AddTravelContributionPage({
    super.key,
    required this.travelPlan,
    required this.accounts,
    this.availableAmountByAccountId = const {},
  });

  @override
  State<AddTravelContributionPage> createState() =>
      _AddTravelContributionPageState();
}

class _AddTravelContributionPageState extends State<AddTravelContributionPage> {
  final _formKey = GlobalKey<FormState>();

  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  AccountModel? _sourceAccount;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();

    if (widget.accounts.isNotEmpty) {
      _sourceAccount = widget.accounts.first;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double _availableFor(AccountModel? account) {
    if (account == null) {
      return 0.0;
    }

    return widget.availableAmountByAccountId[account.id] ?? 0.0;
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day.$month.$year';
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

  void _saveContribution() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_sourceAccount == null) {
      return;
    }

    final now = DateTime.now();

    final amount = double.parse(
      _amountController.text.trim().replaceAll(',', '.'),
    );

    final contribution = TravelContributionModel(
      id: now.microsecondsSinceEpoch.toString(),
      travelPlanId: widget.travelPlan.id,
      sourceAccountId: _sourceAccount!.id,
      amount: amount,
      date: _selectedDate,
      createdAt: now,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
    );

    Navigator.pop(
      context,
      AddTravelContributionResult(
        contribution: contribution,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedAvailable = _availableFor(_sourceAccount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reserve for Travel'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.flight_takeoff),
                title: Text(widget.travelPlan.destination),
                subtitle: Text(
                  'Target Budget: €${widget.travelPlan.targetBudget.toStringAsFixed(2)}',
                ),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<AccountModel>(
              value: _sourceAccount,
              decoration: const InputDecoration(
                labelText: 'Reserved from',
                border: OutlineInputBorder(),
              ),
              items: widget.accounts.map((account) {
                final available = _availableFor(account);

                return DropdownMenuItem(
                  value: account,
                  child: Text(
                    '${account.name} · frei €${available.toStringAsFixed(2)}',
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _sourceAccount = value;
                });
              },
              validator: (value) {
                if (value == null) {
                  return 'Please select where this money is located';
                }

                if (_availableFor(value) <= 0) {
                  return 'Dieses Konto hat kein frei verfügbares Geld';
                }

                return null;
              },
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Frei verfügbar in diesem Konto: €${selectedAvailable.toStringAsFixed(2)}\n'
                  'This does not move money. It only marks part of this account as reserved for this trip.',
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
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

                final available = _availableFor(_sourceAccount);

                if (amount > available) {
                  return 'Maximal frei verfügbar: €${available.toStringAsFixed(2)}';
                }

                return null;
              },
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_month_outlined),
                title: const Text('Reservation Date'),
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
              onPressed: _saveContribution,
              icon: const Icon(Icons.save),
              label: const Text('Save Reservation'),
            ),
          ],
        ),
      ),
    );
  }
}
