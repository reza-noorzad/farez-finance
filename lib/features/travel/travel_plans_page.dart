import 'package:flutter/material.dart';

import '../../core/supabase/app_data_loader_service.dart';
import '../../shared/models/account_model.dart';
import '../../shared/models/financial_transaction_model.dart';
import '../../shared/models/saving_goal_reservation_model.dart';
import '../../shared/models/travel_contribution_model.dart';
import '../../shared/models/travel_plan_model.dart';
import '../../shared/widgets/section_title.dart';
import '../../shared/widgets/summary_card.dart';
import '../savings/account_balance_calculator.dart';
import '../savings/account_mock_data.dart';
import '../savings/financial_transaction_mock_data.dart';
import '../savings/saving_goal_reservations_repository.dart';
import 'add_travel_contribution_page.dart';
import 'add_travel_plan_page.dart';
import 'travel_mock_data.dart';
import 'travel_repository.dart';

class TravelPlansPage extends StatefulWidget {
  const TravelPlansPage({super.key});

  @override
  State<TravelPlansPage> createState() => _TravelPlansPageState();
}

class _TravelPlansPageState extends State<TravelPlansPage> {
  final TravelRepository _travelRepository = TravelRepository();
  final SavingGoalReservationsRepository _savingReservationsRepository =
      SavingGoalReservationsRepository();

  List<TravelPlanModel> _travelPlans = [];
  List<TravelContributionModel> _contributions = [];
  List<AccountModel> _accounts = [];
  List<FinancialTransactionModel> _transactions = [];
  List<SavingGoalReservationModel> _savingReservations = [];

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTravelData();
  }

  Future<void> _loadTravelData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await AppDataLoaderService.loadInitialFinanceData();

      final travelData = await _travelRepository.fetchTravelData();
      final savingReservations =
          await _savingReservationsRepository.fetchReservations();

      TravelMockData.travelPlans
        ..clear()
        ..addAll(travelData.travelPlans);

      TravelMockData.contributions
        ..clear()
        ..addAll(travelData.contributions);

      if (!mounted) {
        return;
      }

      setState(() {
        _travelPlans = travelData.travelPlans;
        _contributions = travelData.contributions;
        _accounts = AccountMockData.accounts;
        _transactions = FinancialTransactionMockData.transactions;
        _savingReservations = savingReservations;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Fehler beim Laden der Reisepläne: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    await _loadTravelData();
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day.$month.$year';
  }

  List<AccountModel> get _normalAccounts {
    return _accounts.where((account) {
      return account.isActive && account.kind == AccountKind.account;
    }).toList();
  }

  List<TravelPlanModel> get _activeTravelPlans {
    return _travelPlans
        .where((plan) => plan.status == TravelPlanStatus.active)
        .toList();
  }

  List<TravelPlanModel> get _completedTravelPlans {
    return _travelPlans
        .where((plan) => plan.status == TravelPlanStatus.completed)
        .toList();
  }

  List<TravelContributionModel> _contributionsForTrip(String travelPlanId) {
    final tripContributions = _contributions.where((contribution) {
      return contribution.travelPlanId == travelPlanId;
    }).toList();

    tripContributions.sort(
      (a, b) => b.date.compareTo(a.date),
    );

    return tripContributions;
  }

  double _savedAmountForTrip(String travelPlanId) {
    return _contributionsForTrip(travelPlanId).fold(
      0.0,
      (sum, contribution) => sum + contribution.amount,
    );
  }

  Map<String, double> _savedByAccountForTrip(String travelPlanId) {
    final result = <String, double>{};

    for (final contribution in _contributionsForTrip(travelPlanId)) {
      final accountId = contribution.sourceAccountId ?? 'unknown';

      result[accountId] = (result[accountId] ?? 0) + contribution.amount;
    }

    return result;
  }

  String _accountName(String? accountId) {
    if (accountId == null || accountId.isEmpty || accountId == 'unknown') {
      return 'Unbekannt';
    }

    try {
      return _accounts.firstWhere((account) => account.id == accountId).name;
    } catch (_) {
      return 'Unbekannt';
    }
  }

  double get _totalActiveTargetBudget {
    return _activeTravelPlans.fold(
      0.0,
      (sum, plan) => sum + plan.targetBudget,
    );
  }

  double get _totalActiveSavedAmount {
    return _activeTravelPlans.fold(
      0.0,
      (sum, plan) => sum + _savedAmountForTrip(plan.id),
    );
  }


  double _currentBalance(AccountModel account) {
    return AccountBalanceCalculator.calculateBalance(
      accountId: account.id,
      openingBalance: account.balance,
      transactions: _transactions,
    );
  }

  Map<String, double> _availableAmountByAccountId() {
    final result = <String, double>{};

    final activeTravelPlanIds = _activeTravelPlans.map((plan) => plan.id).toSet();

    for (final account in _normalAccounts) {
      final balance = _currentBalance(account);

      final travelReserved = _contributions.where((contribution) {
        return contribution.sourceAccountId == account.id &&
            activeTravelPlanIds.contains(contribution.travelPlanId);
      }).fold(
        0.0,
        (sum, contribution) => sum + contribution.amount,
      );

      final savingGoalReserved = _savingReservations.where((reservation) {
        return reservation.sourceAccountId == account.id;
      }).fold(
        0.0,
        (sum, reservation) => sum + reservation.amount,
      );

      result[account.id] = balance - travelReserved - savingGoalReserved;
    }

    return result;
  }

  Future<void> _openAddTravelPlanPage() async {
    final TravelPlanModel? result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddTravelPlanPage(),
      ),
    );

    if (result == null) {
      return;
    }

    try {
      await _travelRepository.createTravelPlan(result);
      await _loadTravelData();
    } catch (e) {
      _showError('Reiseplan konnte nicht gespeichert werden: $e');
    }
  }

  Future<void> _openAddTravelContributionPage(
    TravelPlanModel travelPlan,
  ) async {
    if (_normalAccounts.isEmpty) {
      _showError('Bitte erstelle zuerst Bank Account oder Cash Wallet.');
      return;
    }

    final AddTravelContributionResult? result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddTravelContributionPage(
          travelPlan: travelPlan,
          accounts: _normalAccounts,
          availableAmountByAccountId: _availableAmountByAccountId(),
        ),
      ),
    );

    if (result == null) {
      return;
    }

    try {
      await _travelRepository.createContribution(
        contribution: result.contribution,
      );

      await _loadTravelData();
    } catch (e) {
      _showError('Reisereservierung konnte nicht gespeichert werden: $e');
    }
  }

  Future<void> _releaseTravelReservation(TravelPlanModel travelPlan) async {
    final total = _savedAmountForTrip(travelPlan.id);
    if (total <= 0 || _normalAccounts.isEmpty) {
      _showError('Für diese Reise ist kein Geld reserviert.');
      return;
    }
    final amountController = TextEditingController();
    AccountModel destination = _normalAccounts.first;
    final result = await showDialog<double>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Aus ${travelPlan.destination} entnehmen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Reserviert: €${total.toStringAsFixed(2)}'),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Betrag', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AccountModel>(
                value: destination,
                decoration: const InputDecoration(labelText: 'Freigeben auf', border: OutlineInputBorder()),
                items: _normalAccounts.map((a) => DropdownMenuItem(value: a, child: Text(a.name))).toList(),
                onChanged: (value) { if (value != null) setDialogState(() => destination = value); },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
            FilledButton(
              onPressed: () {
                final value = double.tryParse(amountController.text.replaceAll(',', '.'));
                if (value == null || value <= 0 || value > total) return;
                Navigator.pop(context, value);
              },
              child: const Text('Freigeben'),
            ),
          ],
        ),
      ),
    );
    amountController.dispose();
    if (result == null) return;
    try {
      await _travelRepository.releaseContribution(
        travelPlanId: travelPlan.id,
        destinationAccountId: destination.id,
        amount: result,
        date: DateTime.now(),
        note: 'Aus ${travelPlan.destination} freigegeben auf ${destination.name}',
      );
      await _loadTravelData();
    } catch (e) {
      _showError('Reisereservierung konnte nicht freigegeben werden: $e');
    }
  }

  Future<void> _markTripAsCompleted(TravelPlanModel travelPlan) async {
    try {
      await _travelRepository.updateTravelPlan(
        travelPlan.copyWith(status: TravelPlanStatus.completed),
      );

      await _loadTravelData();
    } catch (e) {
      _showError('Reise konnte nicht abgeschlossen werden: $e');
    }
  }

  Future<void> _deleteTravelPlan(TravelPlanModel travelPlan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reiseplan löschen'),
          content: Text(
            'Möchtest du "${travelPlan.destination}" wirklich löschen?\n\n'
            'Alle Reservierungen zu dieser Reise werden auch entfernt.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Löschen'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _travelRepository.deleteTravelPlan(travelPlan.id);
      await _loadTravelData();
    } catch (e) {
      _showError('Reiseplan konnte nicht gelöscht werden: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Widget _buildLoadingState() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Travel Plans'),
      ),
      body: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorState() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Travel Plans'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage ?? 'Unbekannter Fehler',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Erneut versuchen'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    final totalRemaining =
        _totalActiveTargetBudget - _totalActiveSavedAmount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Travel Plans'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Aktualisieren',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            SummaryCard(
              title: 'Active Travel Target',
              amount: '€${_totalActiveTargetBudget.toStringAsFixed(2)}',
              icon: Icons.flight_takeoff,
            ),
            const SizedBox(height: 12),
            SummaryCard(
              title: 'Reserved For Active Trips',
              amount: '€${_totalActiveSavedAmount.toStringAsFixed(2)}',
              icon: Icons.savings_outlined,
            ),
            const SizedBox(height: 12),
            SummaryCard(
              title: 'Remaining For Active Trips',
              amount: '€${totalRemaining.toStringAsFixed(2)}',
              icon: Icons.calculate_outlined,
            ),
            const SizedBox(height: 24),
            const SectionTitle(title: 'Active Trips'),
            const SizedBox(height: 12),
            if (_activeTravelPlans.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No active travel plans.'),
                ),
              ),
            for (final travelPlan in _activeTravelPlans)
              _TravelPlanCard(
                travelPlan: travelPlan,
                savedAmount: _savedAmountForTrip(travelPlan.id),
                savedByAccount: _savedByAccountForTrip(travelPlan.id),
                accountNameForId: _accountName,
                contributions: _contributionsForTrip(travelPlan.id),
                travelDateText: _formatDate(travelPlan.travelDate),
                isCompleted: false,
                onAddSaving: () {
                  _openAddTravelContributionPage(travelPlan);
                },
                onRelease: () {
                  _releaseTravelReservation(travelPlan);
                },
                onMarkCompleted: () {
                  _markTripAsCompleted(travelPlan);
                },
                onDelete: () {
                  _deleteTravelPlan(travelPlan);
                },
              ),
            const SizedBox(height: 24),
            const SectionTitle(title: 'Completed Trips'),
            const SizedBox(height: 12),
            if (_completedTravelPlans.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No completed trips yet.'),
                ),
              ),
            for (final travelPlan in _completedTravelPlans)
              _TravelPlanCard(
                travelPlan: travelPlan,
                savedAmount: _savedAmountForTrip(travelPlan.id),
                savedByAccount: _savedByAccountForTrip(travelPlan.id),
                accountNameForId: _accountName,
                contributions: _contributionsForTrip(travelPlan.id),
                travelDateText: _formatDate(travelPlan.travelDate),
                isCompleted: true,
                onAddSaving: null,
                onRelease: null,
                onMarkCompleted: null,
                onDelete: () {
                  _deleteTravelPlan(travelPlan);
                },
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddTravelPlanPage,
        icon: const Icon(Icons.add),
        label: const Text('Add Trip'),
      ),
    );
  }
}

class _TravelPlanCard extends StatelessWidget {
  final TravelPlanModel travelPlan;
  final double savedAmount;
  final Map<String, double> savedByAccount;
  final String Function(String? accountId) accountNameForId;
  final List<TravelContributionModel> contributions;
  final String travelDateText;
  final bool isCompleted;
  final VoidCallback? onAddSaving;
  final VoidCallback? onRelease;
  final VoidCallback? onMarkCompleted;
  final VoidCallback onDelete;

  const _TravelPlanCard({
    required this.travelPlan,
    required this.savedAmount,
    required this.savedByAccount,
    required this.accountNameForId,
    required this.contributions,
    required this.travelDateText,
    required this.isCompleted,
    required this.onAddSaving,
    required this.onRelease,
    required this.onMarkCompleted,
    required this.onDelete,
  });

  double get _remainingAmount {
    final remaining = travelPlan.targetBudget - savedAmount;
    return remaining < 0 ? 0 : remaining;
  }

  double get _progress {
    if (travelPlan.targetBudget <= 0) return 0;

    final progress = savedAmount / travelPlan.targetBudget;
    return progress > 1 ? 1 : progress;
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day.$month.$year';
  }

  @override
  Widget build(BuildContext context) {
    final progressPercent = (_progress * 100).toStringAsFixed(0);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Icon(
                    isCompleted ? Icons.check : Icons.flight_takeoff,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    travelPlan.destination,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isCompleted)
                  const Chip(
                    label: Text('Completed'),
                  ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (context) {
                    return const [
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Löschen'),
                      ),
                    ];
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 12),
            Text('Target Budget: €${travelPlan.targetBudget.toStringAsFixed(2)}'),
            Text('Reserved: €${savedAmount.toStringAsFixed(2)}'),
            Text('Remaining: €${_remainingAmount.toStringAsFixed(2)}'),
            Text('Progress: $progressPercent%'),
            Text('Travel Date: $travelDateText'),
            if (travelPlan.note != null && travelPlan.note!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Note: ${travelPlan.note}'),
            ],
            const SizedBox(height: 12),
            const Text(
              'Reserved by account',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            if (savedByAccount.isEmpty)
              const Text('No reservations yet.')
            else
              for (final entry in savedByAccount.entries)
                Text(
                  '${accountNameForId(entry.key)}: €${entry.value.toStringAsFixed(2)}',
                ),
            if (!isCompleted) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: onAddSaving,
                    icon: const Icon(Icons.savings_outlined),
                    label: const Text('Reservieren'),
                  ),
                  OutlinedButton.icon(
                    onPressed: savedAmount > 0 ? onRelease : null,
                    icon: const Icon(Icons.lock_open_outlined),
                    label: const Text('Entnehmen'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onMarkCompleted,
                    icon: const Icon(Icons.check),
                    label: const Text('Abschließen'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Reservation History'),
              children: [
                if (contributions.isEmpty)
                  const ListTile(
                    title: Text('No reservations yet.'),
                  ),
                for (final contribution in contributions)
                  ListTile(
                    leading: const Icon(Icons.savings_outlined),
                    title: Text(
                      '${contribution.amount >= 0 ? '+' : '−'} €${contribution.amount.abs().toStringAsFixed(2)}',
                    ),
                    subtitle: Text(
                      '${_formatDate(contribution.date)} • ${accountNameForId(contribution.sourceAccountId)}'
                      '${contribution.note == null || contribution.note!.isEmpty ? '' : ' • ${contribution.note}'}',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}