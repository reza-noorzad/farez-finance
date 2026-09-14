import 'package:flutter/material.dart';

import '../../shared/models/account_model.dart';
import '../../shared/models/saving_goal_reservation_model.dart';

class AddFundResult {
  final AccountModel fund;
  final SavingGoalReservationModel? initialReservation;

  const AddFundResult({
    required this.fund,
    this.initialReservation,
  });
}

class AddFundPage extends StatefulWidget {
  final AccountModel? initialFund;
  final List<AccountModel> sourceAccounts;

  const AddFundPage({
    super.key,
    this.initialFund,
    this.sourceAccounts = const [],
  });

  @override
  State<AddFundPage> createState() => _AddFundPageState();
}

class _AddFundPageState extends State<AddFundPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _targetAmountController = TextEditingController();
  final _openingBalanceController = TextEditingController();

  late DateTime _startDate;
  DateTime? _targetDate;
  AccountModel? _selectedSourceAccount;

  bool get _isEditMode {
    return widget.initialFund != null;
  }

  double get _openingBalance {
    final text = _openingBalanceController.text.trim();

    if (text.isEmpty) {
      return 0;
    }

    return double.tryParse(text.replaceAll(',', '.')) ?? 0;
  }

  bool get _needsSourceAccount {
    return !_isEditMode && _openingBalance > 0;
  }

  @override
  void initState() {
    super.initState();

    final fund = widget.initialFund;

    _nameController.text = fund?.name ?? '';

    if (fund?.targetAmount != null) {
      _targetAmountController.text = fund!.targetAmount!.toStringAsFixed(2);
    }

    _startDate = fund?.startDate ?? DateTime.now();
    _targetDate = fund?.targetDate;

    if (widget.sourceAccounts.isNotEmpty) {
      _selectedSourceAccount = widget.sourceAccounts.first;
    }

    _openingBalanceController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetAmountController.dispose();
    _openingBalanceController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (pickedDate == null) {
      return;
    }

    setState(() {
      _startDate = pickedDate;

      if (_targetDate != null && _targetDate!.isBefore(_startDate)) {
        _targetDate = null;
      }
    });
  }

  Future<void> _pickTargetDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? _startDate,
      firstDate: _startDate,
      lastDate: DateTime(2100),
    );

    if (pickedDate == null) {
      return;
    }

    setState(() {
      _targetDate = pickedDate;
    });
  }

  void _clearTargetDate() {
    setState(() {
      _targetDate = null;
    });
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day.$month.$year';
  }

  void _saveFund() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_needsSourceAccount && _selectedSourceAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte Quelle für den Startbetrag auswählen.'),
        ),
      );

      return;
    }

    final now = DateTime.now();

    final targetAmountText = _targetAmountController.text.trim();

    final targetAmount = targetAmountText.isEmpty
        ? null
        : double.tryParse(targetAmountText.replaceAll(',', '.'));

    final oldFund = widget.initialFund;
    final fundId = oldFund?.id ?? now.microsecondsSinceEpoch.toString();
    final startAmount = _openingBalance;

    final fund = AccountModel(
      id: fundId,
      name: _nameController.text.trim(),
      kind: AccountKind.fund,
      balance: oldFund?.balance ?? 0.0,
      iconName: oldFund?.iconName ?? 'savings',
      colorValue: oldFund?.colorValue ?? Colors.blue.toARGB32(),
      isActive: true,
      showInDashboard: oldFund?.showInDashboard ?? true,
      createdAt: oldFund?.createdAt ?? now,
      targetAmount: targetAmount,
      startDate: _startDate,
      targetDate: _targetDate,
    );

    SavingGoalReservationModel? initialReservation;

    if (!_isEditMode && startAmount > 0 && _selectedSourceAccount != null) {
      initialReservation = SavingGoalReservationModel(
        id: 'res_start_${now.microsecondsSinceEpoch}',
        fundId: fund.id,
        sourceAccountId: _selectedSourceAccount!.id,
        amount: startAmount,
        date: _startDate,
        createdAt: now,
        note: 'Startbetrag für neues Sparziel.',
      );
    }

    Navigator.pop(
      context,
      AddFundResult(
        fund: fund,
        initialReservation: initialReservation,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canCreateStartReservation =
        !_isEditMode && widget.sourceAccounts.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditMode ? 'Sparziel bearbeiten' : 'Sparziel erstellen',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _isEditMode
                    ? 'Hier kannst du Name, Zielbetrag und Datum dieses Sparziels bearbeiten. Reserviertes Geld wird separat erfasst.'
                    : 'Ein Sparziel ist kein neues Einkommen und keine Ausgabe. Wenn du einen Startbetrag einträgst, wird er nur als reserviertes Geld markiert. Bank/Cash wird nicht verändert.',
              ),
            ),
          ),
          const SizedBox(height: 16),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name des Sparziels',
                    hintText: 'Beispiel: Laptop, Notfallgeld, Auto-Reparatur',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Bitte Namen eingeben';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _targetAmountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Zielbetrag optional',
                    hintText: 'Beispiel: 1000',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';

                    if (text.isEmpty) {
                      return null;
                    }

                    final parsed = double.tryParse(
                      text.replaceAll(',', '.'),
                    );

                    if (parsed == null || parsed <= 0) {
                      return 'Bitte gültigen Zielbetrag eingeben';
                    }

                    return null;
                  },
                ),
                if (!_isEditMode) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _openingBalanceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Startbetrag optional',
                      hintText: 'Wenn du direkt Geld für dieses Sparziel reservierst',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';

                      if (text.isEmpty) {
                        return null;
                      }

                      final parsed = double.tryParse(
                        text.replaceAll(',', '.'),
                      );

                      if (parsed == null || parsed < 0) {
                        return 'Bitte gültigen Startbetrag eingeben';
                      }

                      if (parsed > 0 && !canCreateStartReservation) {
                        return 'Es gibt kein Konto für den Startbetrag.';
                      }

                      return null;
                    },
                  ),
                  if (_needsSourceAccount) ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<AccountModel>(
                      value: _selectedSourceAccount,
                      decoration: const InputDecoration(
                        labelText: 'Startbetrag ist in',
                        border: OutlineInputBorder(),
                      ),
                      items: widget.sourceAccounts.map((account) {
                        return DropdownMenuItem<AccountModel>(
                          value: account,
                          child: Text(account.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedSourceAccount = value;
                        });
                      },
                      validator: (value) {
                        if (_needsSourceAccount && value == null) {
                          return 'Bitte Konto auswählen';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Der Startbetrag wird nur reserviert. Bank/Cash bleibt unverändert.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.play_arrow_outlined),
                    title: const Text('Startdatum'),
                    subtitle: Text(_formatDate(_startDate)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _pickStartDate,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.flag_outlined),
                    title: const Text('Zieldatum optional'),
                    subtitle: Text(
                      _targetDate == null
                          ? 'Kein Zieldatum ausgewählt'
                          : _formatDate(_targetDate!),
                    ),
                    trailing: _targetDate == null
                        ? const Icon(Icons.chevron_right)
                        : IconButton(
                            onPressed: _clearTargetDate,
                            icon: const Icon(Icons.close),
                          ),
                    onTap: _pickTargetDate,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saveFund,
                    icon: const Icon(Icons.save),
                    label: Text(
                      _isEditMode
                          ? 'Änderungen speichern'
                          : 'Sparziel speichern',
                    ),
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
