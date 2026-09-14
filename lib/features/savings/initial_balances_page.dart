import 'package:flutter/material.dart';

import '../../shared/models/account_model.dart';
import '../../shared/models/debt_model.dart';
import '../../shared/models/debt_payment_model.dart';
import '../debts/debt_repository.dart';
import 'account_mock_data.dart';
import 'accounts_repository.dart';

class InitialBalancesPage extends StatefulWidget {
  const InitialBalancesPage({super.key});

  @override
  State<InitialBalancesPage> createState() => _InitialBalancesPageState();
}

class _InitialBalancesPageState extends State<InitialBalancesPage> {
  final AccountsRepository _accountsRepository = AccountsRepository();
  final DebtRepository _debtRepository = DebtRepository();

  final Map<String, TextEditingController> _accountControllers = {};
  final List<_OpeningDebtDraft> _debtDrafts = [];

  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  bool _isSaving = false;
  bool _isLoading = true;
  String? _errorMessage;

  List<AccountModel> _accounts = [];
  List<DebtModel> _existingOpeningDebts = [];
  List<DebtPaymentModel> _debtPayments = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _accountControllers.values) {
      controller.dispose();
    }
    for (final draft in _debtDrafts) {
      draft.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final accounts = await _accountsRepository.fetchAccounts();
      final debtData = await _debtRepository.fetchDebtData();

      for (final controller in _accountControllers.values) {
        controller.dispose();
      }
      _accountControllers.clear();

      final normalAccounts = accounts.where((account) {
        return account.isActive && account.kind == AccountKind.account;
      }).toList();

      for (final account in normalAccounts) {
        _accountControllers[account.id] = TextEditingController(
          text: account.balance.toStringAsFixed(2),
        );
      }

      if (!mounted) return;

      setState(() {
        _accounts = normalAccounts;
        _existingOpeningDebts = debtData.debts
            .where((debt) => debt.isOpeningBalance && debt.isActive)
            .toList();
        _debtPayments = debtData.payments;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'App-Start konnte nicht geladen werden: $e';
        _isLoading = false;
      });
    }
  }

  double? _parseAmount(String text) {
    return double.tryParse(text.trim().replaceAll(',', '.'));
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    setState(() {
      _startDate = picked;
    });
  }

  void _addDebtDraft(DebtKind kind) {
    setState(() {
      _debtDrafts.add(_OpeningDebtDraft(kind: kind));
    });
  }

  void _removeDebtDraft(_OpeningDebtDraft draft) {
    setState(() {
      _debtDrafts.remove(draft);
      draft.dispose();
    });
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
    });

    try {
      for (final account in _accounts) {
        final controller = _accountControllers[account.id];
        if (controller == null) continue;

        final amount = _parseAmount(controller.text);
        if (amount == null) {
          throw Exception('Ungültiger Anfangsbestand für ${account.name}.');
        }

        await _accountsRepository.updateAccount(
          account.copyWith(balance: amount),
        );
      }

      final now = DateTime.now();

      for (final draft in _debtDrafts) {
        final person = draft.personController.text.trim();
        final amount = _parseAmount(draft.amountController.text);
        final note = draft.noteController.text.trim();

        if (person.isEmpty && (amount == null || amount <= 0)) {
          continue;
        }

        if (person.isEmpty) {
          throw Exception('Bitte Person bei Altbestand eingeben.');
        }

        if (amount == null || amount <= 0) {
          throw Exception('Bitte gültigen Betrag bei Altbestand eingeben.');
        }

        await _debtRepository.createOpeningDebt(
          DebtModel(
            id: 'opening_${now.microsecondsSinceEpoch}',
            personName: person,
            kind: draft.kind,
            originalAmount: amount,
            debtDate: _startDate,
            createdAt: now,
            accountId: '',
            isActive: true,
            note: note.isEmpty ? 'Altbestand am ${_formatDate(_startDate)}' : note,
            isOpeningBalance: true,
          ),
        );
      }

      final updated = await _accountsRepository.fetchAccounts();
      AccountMockData.accounts
        ..clear()
        ..addAll(updated);

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('App-Start konnte nicht gespeichert werden: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _editOpeningDebt(DebtModel debt) async {
    final paidAmount = debt.paidAmountFrom(_debtPayments);

    final result = await showDialog<DebtModel>(
      context: context,
      builder: (context) {
        return _OpeningDebtEditDialog(
          debt: debt,
          paidAmount: paidAmount,
          formatDate: _formatDate,
        );
      },
    );

    if (result == null) return;

    try {
      await _debtRepository.updateOpeningDebt(result);
      await _load();
    } catch (e) {
      _showError('Altbestand konnte nicht bearbeitet werden: $e');
    }
  }

  Future<void> _deleteOpeningDebt(DebtModel debt) async {
    final paidAmount = debt.paidAmountFrom(_debtPayments);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Altbestand löschen'),
          content: Text(
            paidAmount > 0
                ? 'Für diesen Altbestand gibt es bereits Zahlungen über €${paidAmount.toStringAsFixed(2)}. Wenn du ihn löschst, werden auch die Zahlungen und Kontobewegungen dazu gelöscht. Fortfahren?'
                : 'Möchtest du diesen Altbestand wirklich löschen?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Löschen'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _debtRepository.deleteOpeningDebt(debt.id);
      await _load();
    } catch (e) {
      _showError('Altbestand konnte nicht gelöscht werden: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        appBar: _SetupAppBar(),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: const _SetupAppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: const _SetupAppBar(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Hier richtest du die App einmalig sauber ein. Anfangsbestand ist keine Einnahme und keine Ausgabe. Alte Forderungen/Schulden verändern Bank/Cash nicht; spätere Zahlungen verändern Bank/Cash normal.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.event_outlined),
              title: const Text('Startdatum'),
              subtitle: Text(_formatDate(_startDate)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickStartDate,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Konten',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          if (_accounts.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Keine Bank/Cash-Konten vorhanden.'),
              ),
            )
          else
            for (final account in _accounts)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _accountControllers[account.id],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: account.name,
                      helperText: 'Anfangsbestand / Startsaldo',
                      border: const OutlineInputBorder(),
                      prefixText: '€ ',
                    ),
                  ),
                ),
              ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Alte Forderungen & Schulden',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              PopupMenuButton<DebtKind>(
                tooltip: 'Altbestand hinzufügen',
                onSelected: _addDebtDraft,
                itemBuilder: (context) {
                  return const [
                    PopupMenuItem(
                      value: DebtKind.moneyLent,
                      child: Text('Offene Forderung'),
                    ),
                    PopupMenuItem(
                      value: DebtKind.moneyBorrowed,
                      child: Text('Offene Verbindlichkeit'),
                    ),
                  ];
                },
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.add_circle_outline),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_existingOpeningDebts.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bereits gespeicherte Altbestände',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    for (final debt in _existingOpeningDebts)
                      _ExistingOpeningDebtTile(
                        debt: debt,
                        payments: _debtPayments,
                        onEdit: () => _editOpeningDebt(debt),
                        onDelete: () => _deleteOpeningDebt(debt),
                      ),
                  ],
                ),
              ),
            ),
          if (_debtDrafts.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Nur alte offene Forderungen/Schulden vom Startdatum hier eintragen. Normale neue Schulden später im Bereich Schulden erfassen.',
                ),
              ),
            )
          else
            for (final draft in _debtDrafts)
              _OpeningDebtDraftCard(
                draft: draft,
                onRemove: () => _removeDebtDraft(draft),
              ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: const Icon(Icons.save),
            label: Text(_isSaving ? 'Speichern...' : 'App-Start speichern'),
          ),
          const SizedBox(height: 90),
        ],
      ),
    );
  }
}

class _SetupAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _SetupAppBar();

  @override
  Widget build(BuildContext context) {
    return AppBar(title: const Text('App-Start & Anfangsbestand'));
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _ExistingOpeningDebtTile extends StatelessWidget {
  final DebtModel debt;
  final List<DebtPaymentModel> payments;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ExistingOpeningDebtTile({
    required this.debt,
    required this.payments,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isReceivable = debt.kind == DebtKind.moneyLent;
    final paid = debt.paidAmountFrom(payments);
    final open = debt.remainingAmountFrom(payments);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(isReceivable ? Icons.call_made_outlined : Icons.call_received_outlined),
        title: Text(debt.personName),
        subtitle: Text(
          '${isReceivable ? 'Forderung' : 'Verbindlichkeit'} · Ursprünglich €${debt.originalAmount.toStringAsFixed(2)} · Offen €${open.toStringAsFixed(2)}'
          '${paid > 0 ? ' · bezahlt €${paid.toStringAsFixed(2)}' : ''}',
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') onEdit();
            if (value == 'delete') onDelete();
          },
          itemBuilder: (context) {
            return const [
              PopupMenuItem(value: 'edit', child: Text('Bearbeiten')),
              PopupMenuItem(value: 'delete', child: Text('Löschen')),
            ];
          },
        ),
      ),
    );
  }
}

class _OpeningDebtEditDialog extends StatefulWidget {
  final DebtModel debt;
  final double paidAmount;
  final String Function(DateTime) formatDate;

  const _OpeningDebtEditDialog({
    required this.debt,
    required this.paidAmount,
    required this.formatDate,
  });

  @override
  State<_OpeningDebtEditDialog> createState() => _OpeningDebtEditDialogState();
}

class _OpeningDebtEditDialogState extends State<_OpeningDebtEditDialog> {
  late final TextEditingController _personController;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late DebtKind _kind;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    _personController = TextEditingController(text: widget.debt.personName);
    _amountController = TextEditingController(
      text: widget.debt.originalAmount.toStringAsFixed(2),
    );
    _noteController = TextEditingController(text: widget.debt.note ?? '');
    _kind = widget.debt.kind;
    _date = widget.debt.debtDate;
  }

  @override
  void dispose() {
    _personController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double? _parseAmount(String text) {
    return double.tryParse(text.trim().replaceAll(',', '.'));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    setState(() {
      _date = picked;
    });
  }

  void _save() {
    final person = _personController.text.trim();
    final amount = _parseAmount(_amountController.text);
    final note = _noteController.text.trim();

    if (person.isEmpty) {
      return;
    }

    if (amount == null || amount <= 0) {
      return;
    }

    if (amount < widget.paidAmount) {
      return;
    }

    Navigator.pop(
      context,
      widget.debt.copyWith(
        personName: person,
        kind: _kind,
        originalAmount: amount,
        debtDate: _date,
        accountId: '',
        note: note.isEmpty ? null : note,
        isActive: true,
        isOpeningBalance: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final amount = _parseAmount(_amountController.text);
    final amountIsTooLow = amount != null && amount < widget.paidAmount;

    return AlertDialog(
      title: const Text('Altbestand bearbeiten'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<DebtKind>(
                segments: const [
                  ButtonSegment(
                    value: DebtKind.moneyLent,
                    label: Text('Forderung'),
                    icon: Icon(Icons.call_made_outlined),
                  ),
                  ButtonSegment(
                    value: DebtKind.moneyBorrowed,
                    label: Text('Verbindlichkeit'),
                    icon: Icon(Icons.call_received_outlined),
                  ),
                ],
                selected: {_kind},
                onSelectionChanged: (selection) {
                  setState(() {
                    _kind = selection.first;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _personController,
                decoration: const InputDecoration(
                  labelText: 'Person',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Ursprünglicher Betrag',
                  prefixText: '€ ',
                  border: const OutlineInputBorder(),
                  errorText: amountIsTooLow
                      ? 'Betrag darf nicht kleiner als bereits bezahlt sein'
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (widget.paidAmount > 0) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Bereits bezahlt: €${widget.paidAmount.toStringAsFixed(2)}',
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.event_outlined),
                  title: const Text('Startdatum'),
                  subtitle: Text(widget.formatDate(_date)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _pickDate,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notiz optional',
                  border: OutlineInputBorder(),
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
          onPressed: amountIsTooLow ? null : _save,
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}

class _OpeningDebtDraft {
  final DebtKind kind;
  final TextEditingController personController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController noteController = TextEditingController();

  _OpeningDebtDraft({required this.kind});

  void dispose() {
    personController.dispose();
    amountController.dispose();
    noteController.dispose();
  }
}

class _OpeningDebtDraftCard extends StatelessWidget {
  final _OpeningDebtDraft draft;
  final VoidCallback onRemove;

  const _OpeningDebtDraftCard({
    required this.draft,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isReceivable = draft.kind == DebtKind.moneyLent;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isReceivable ? Icons.call_made_outlined : Icons.call_received_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isReceivable ? 'Offene Forderung' : 'Offene Verbindlichkeit',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: draft.personController,
              decoration: const InputDecoration(
                labelText: 'Person',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: draft.amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Betrag',
                prefixText: '€ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: draft.noteController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notiz optional',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
