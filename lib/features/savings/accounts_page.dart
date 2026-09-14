
import 'package:flutter/material.dart';

import '../../shared/models/account_model.dart';
import '../../shared/models/financial_transaction_model.dart';
import '../../shared/models/saving_goal_reservation_model.dart';
import '../../shared/models/travel_contribution_model.dart';
import '../../shared/models/travel_plan_model.dart';
import '../../shared/widgets/section_title.dart';
import '../../shared/widgets/summary_card.dart';
import '../travel/travel_repository.dart';
import 'account_balance_calculator.dart';
import 'account_detail_page.dart';
import 'account_mock_data.dart';
import 'accounts_repository.dart';
import 'add_fund_page.dart';
import 'add_fund_reservation_page.dart';
import 'add_transfer_page.dart';
import 'financial_transaction_mock_data.dart';
import 'financial_transactions_repository.dart';
import 'initial_balances_page.dart';
import 'saving_goal_reservations_repository.dart';

class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key});

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  final AccountsRepository _accountsRepository = AccountsRepository();
  final FinancialTransactionsRepository _transactionsRepository =
      FinancialTransactionsRepository();
  final TravelRepository _travelRepository = TravelRepository();
  final SavingGoalReservationsRepository _savingReservationsRepository =
      SavingGoalReservationsRepository();

  List<AccountModel> _accounts = [];
  List<FinancialTransactionModel> _transactions = [];
  List<TravelPlanModel> _travelPlans = [];
  List<TravelContributionModel> _travelContributions = [];
  List<SavingGoalReservationModel> _savingReservations = [];

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final accounts = await _accountsRepository.fetchAccounts();
      final transactions = await _transactionsRepository.fetchTransactions();
      final travelData = await _travelRepository.fetchTravelData();
      final savingReservations =
          await _savingReservationsRepository.fetchReservations();

      AccountMockData.accounts
        ..clear()
        ..addAll(accounts);

      FinancialTransactionMockData.transactions
        ..clear()
        ..addAll(transactions);

      if (!mounted) {
        return;
      }

      setState(() {
        _accounts = accounts;
        _transactions = transactions;
        _travelPlans = travelData.travelPlans;
        _travelContributions = travelData.contributions;
        _savingReservations = savingReservations;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Fehler beim Laden der Konten: $e';
        _isLoading = false;
      });
    }
  }

  List<AccountModel> get _activeAccounts {
    return _accounts.where((account) {
      return account.isActive;
    }).toList();
  }

  List<AccountModel> get _normalAccounts {
    return _activeAccounts.where((account) {
      return account.kind == AccountKind.account;
    }).toList();
  }

  List<AccountModel> get _funds {
    return _activeAccounts.where((account) {
      return account.kind == AccountKind.fund;
    }).toList();
  }

  double _currentBalance(AccountModel account) {
    return AccountBalanceCalculator.calculateBalance(
      accountId: account.id,
      openingBalance: account.balance,
      transactions: _transactions,
    );
  }

  double _totalBalance(List<AccountModel> accounts) {
    return accounts.fold(
      0,
      (sum, account) => sum + _currentBalance(account),
    );
  }

  bool _hasTransactions(AccountModel account) {
    return _transactions.any((transaction) {
      return transaction.fromAccountId == account.id ||
          transaction.toAccountId == account.id;
    });
  }

  double _savingReservedAmountForFund(AccountModel fund) {
    return _savingReservations
        .where((reservation) => reservation.fundId == fund.id)
        .fold(0.0, (sum, reservation) => sum + reservation.amount);
  }

  Map<String, double> _savingReservedByAccountForFund(AccountModel fund) {
    final result = <String, double>{};

    for (final reservation in _savingReservations) {
      if (reservation.fundId != fund.id) {
        continue;
      }

      final accountId = reservation.sourceAccountId ?? 'unknown';

      result[accountId] = (result[accountId] ?? 0.0) + reservation.amount;
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

  List<_ReservedMoneyInfo> _reservationsForAccount(AccountModel account) {
    final result = <_ReservedMoneyInfo>[];

    final activeTravelPlanIds = _travelPlans
        .where((plan) => plan.status == TravelPlanStatus.active)
        .map((plan) => plan.id)
        .toSet();

    final amountByTravelPlanId = <String, double>{};

    for (final contribution in _travelContributions) {
      if (contribution.sourceAccountId != account.id) {
        continue;
      }

      if (!activeTravelPlanIds.contains(contribution.travelPlanId)) {
        continue;
      }

      amountByTravelPlanId[contribution.travelPlanId] =
          (amountByTravelPlanId[contribution.travelPlanId] ?? 0) +
              contribution.amount;
    }

    for (final entry in amountByTravelPlanId.entries) {
      final travelPlan = _travelPlans.firstWhere(
        (plan) => plan.id == entry.key,
        orElse: () => TravelPlanModel(
          id: entry.key,
          destination: 'Reise',
          targetBudget: 0,
          travelDate: DateTime.now(),
          status: TravelPlanStatus.active,
          createdAt: DateTime.now(),
        ),
      );

      result.add(
        _ReservedMoneyInfo(
          title: travelPlan.destination,
          amount: entry.value,
          typeLabel: 'Reise',
        ),
      );
    }

    final amountByFundId = <String, double>{};

    for (final reservation in _savingReservations) {
      if (reservation.sourceAccountId != account.id) {
        continue;
      }

      amountByFundId[reservation.fundId] =
          (amountByFundId[reservation.fundId] ?? 0) + reservation.amount;
    }

    for (final entry in amountByFundId.entries) {
      AccountModel? fund;

      try {
        fund = _funds.firstWhere((item) => item.id == entry.key);
      } catch (_) {
        fund = null;
      }

      if (fund == null) {
        continue;
      }

      result.add(
        _ReservedMoneyInfo(
          title: fund.name,
          amount: entry.value,
          typeLabel: 'Sparziel',
        ),
      );
    }

    result.sort((a, b) {
      final typeCompare = a.typeLabel.compareTo(b.typeLabel);

      if (typeCompare != 0) {
        return typeCompare;
      }

      return a.title.compareTo(b.title);
    });

    return result;
  }


  Map<String, double> _availableAmountByAccountId() {
    final result = <String, double>{};

    for (final account in _normalAccounts) {
      final balance = _currentBalance(account);
      final reserved = _reservationsForAccount(account).fold(
        0.0,
        (sum, reservation) => sum + reservation.amount,
      );

      result[account.id] = balance - reserved;
    }

    return result;
  }

  Future<void> _openAddTransferPage() async {
    if (_activeAccounts.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Für einen Transfer brauchst du mindestens zwei Konten.'),
        ),
      );
      return;
    }

    final result = await Navigator.push<AddTransferResult>(
      context,
      MaterialPageRoute(
        builder: (context) => AddTransferPage(
          accounts: _activeAccounts,
        ),
      ),
    );

    if (result == null) {
      return;
    }

    try {
      await _transactionsRepository.createTransaction(result.transaction);
      await _loadData();
    } catch (e) {
      _showError('Transfer konnte nicht gespeichert werden: $e');
    }
  }

  Future<void> _openAddFundPage() async {
    final result = await Navigator.push<AddFundResult>(
      context,
      MaterialPageRoute(
        builder: (context) => AddFundPage(
          sourceAccounts: _normalAccounts,
        ),
      ),
    );

    if (result == null) {
      return;
    }

    try {
      final savedFund = await _accountsRepository.createAccount(result.fund);

      if (result.initialReservation != null) {
        final oldReservation = result.initialReservation!;

        await _savingReservationsRepository.createReservation(
          oldReservation.copyWith(
            fundId: savedFund.id,
          ),
        );
      }

      await _loadData();
    } catch (e) {
      _showError('Sparziel konnte nicht gespeichert werden: $e');
    }
  }

  Future<void> _openEditFundPage(AccountModel fund) async {
    final result = await Navigator.push<AddFundResult>(
      context,
      MaterialPageRoute(
        builder: (context) => AddFundPage(
          initialFund: fund,
          sourceAccounts: _normalAccounts,
        ),
      ),
    );

    if (result == null) {
      return;
    }

    try {
      await _accountsRepository.updateAccount(result.fund);
      await _loadData();
    } catch (e) {
      _showError('Sparziel konnte nicht bearbeitet werden: $e');
    }
  }


  Future<void> _openEditAccountStartBalance(AccountModel account) async {
    final amountController = TextEditingController(
      text: account.balance.toStringAsFixed(2),
    );

    final result = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('${account.name} bearbeiten'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Anfangsbestand ist der Startsaldo beim Beginn der App-Nutzung. '
                'Das ist keine Einnahme und keine Ausgabe.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Anfangsbestand / Startsaldo',
                  hintText: 'z.B. 3500',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () {
                final parsed = double.tryParse(
                  amountController.text.trim().replaceAll(',', '.'),
                );

                if (parsed == null) {
                  return;
                }

                Navigator.pop(context, parsed);
              },
              child: const Text('Speichern'),
            ),
          ],
        );
      },
    );

    amountController.dispose();

    if (result == null) {
      return;
    }

    try {
      await _accountsRepository.updateAccount(
        account.copyWith(balance: result),
      );
      await _loadData();
    } catch (e) {
      _showError('Anfangsbestand konnte nicht gespeichert werden: $e');
    }
  }

  Future<void> _openAddFundReservationPage(AccountModel fund) async {
    if (_normalAccounts.isEmpty) {
      _showError('Bitte erstelle zuerst Bank Account oder Cash Wallet.');
      return;
    }

    final result = await Navigator.push<AddFundReservationResult>(
      context,
      MaterialPageRoute(
        builder: (context) => AddFundReservationPage(
          fund: fund,
          sourceAccounts: _normalAccounts,
          availableAmountByAccountId: _availableAmountByAccountId(),
        ),
      ),
    );

    if (result == null) {
      return;
    }

    try {
      await _savingReservationsRepository.createReservation(result.reservation);
      await _loadData();
    } catch (e) {
      _showError('Reservierung konnte nicht gespeichert werden: $e');
    }
  }

  Future<void> _releaseFundReservation(AccountModel fund) async {
    final reservedByAccount = _savingReservedByAccountForFund(fund)
      ..removeWhere((_, amount) => amount <= 0.000001);
    final total = reservedByAccount.values.fold(0.0, (sum, amount) => sum + amount);

    if (total <= 0) {
      _showError('Für dieses Sparziel ist kein Geld reserviert.');
      return;
    }

    final eligibleAccounts = _normalAccounts
        .where((account) => (reservedByAccount[account.id] ?? 0.0) > 0.000001)
        .toList();

    if (eligibleAccounts.isEmpty) {
      _showError('Für die Reservierung wurde kein gültiges Quellkonto gefunden.');
      return;
    }

    final amountController = TextEditingController();
    AccountModel sourceAccount = eligibleAccounts.first;

    final result = await showDialog<double>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final reservedOnSelectedAccount =
              reservedByAccount[sourceAccount.id] ?? 0.0;

          return AlertDialog(
            title: Text('Aus ${fund.name} entnehmen'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Gesamt reserviert: €${total.toStringAsFixed(2)}'),
                const SizedBox(height: 12),
                if (eligibleAccounts.length > 1) ...[
                  DropdownButtonFormField<AccountModel>(
                    value: sourceAccount,
                    decoration: const InputDecoration(
                      labelText: 'Reservierung auf Konto',
                      border: OutlineInputBorder(),
                    ),
                    items: eligibleAccounts.map((account) {
                      final reserved = reservedByAccount[account.id] ?? 0.0;
                      return DropdownMenuItem(
                        value: account,
                        child: Text(
                          '${account.name} · €${reserved.toStringAsFixed(2)} reserviert',
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        sourceAccount = value;
                        amountController.clear();
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                ] else
                  Text(
                    'Reserviert auf ${sourceAccount.name}: '
                    '€${reservedOnSelectedAccount.toStringAsFixed(2)}',
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Betrag',
                    helperText:
                        'Max. €${reservedOnSelectedAccount.toStringAsFixed(2)}',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Der Betrag wird nur freigegeben. Der Kontostand ändert sich '
                  'nicht; Frei verfügbar erhöht sich auf diesem Konto.',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Abbrechen'),
              ),
              FilledButton(
                onPressed: () {
                  final value = double.tryParse(
                    amountController.text.trim().replaceAll(',', '.'),
                  );
                  final maxAmount = reservedByAccount[sourceAccount.id] ?? 0.0;

                  if (value == null || value <= 0 || value > maxAmount) {
                    return;
                  }

                  Navigator.pop(context, value);
                },
                child: const Text('Freigeben'),
              ),
            ],
          );
        },
      ),
    );

    amountController.dispose();
    if (result == null) return;

    try {
      await _savingReservationsRepository.releaseReservation(
        fundId: fund.id,
        destinationAccountId: sourceAccount.id,
        amount: result,
        date: DateTime.now(),
        note: 'Aus ${fund.name} auf ${sourceAccount.name} freigegeben',
      );
      await _loadData();
    } catch (e) {
      _showError('Reservierung konnte nicht freigegeben werden: $e');
    }
  }

  Future<void> _closeFund(AccountModel fund) async {
    final balance = _currentBalance(fund);
    final hasTransactions = _hasTransactions(fund);
    final reservedAmount = _savingReservedAmountForFund(fund);

    if (reservedAmount > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Sparziel schließen'),
            content: Text(
              'Für "${fund.name}" sind €${reservedAmount.toStringAsFixed(2)} reserviert. '
              'Wenn du dieses Sparziel schließt, werden diese Reservierungen gelöscht.',
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
                child: const Text('Schließen'),
              ),
            ],
          );
        },
      );

      if (confirmed != true) {
        return;
      }

      try {
        await _savingReservationsRepository.deleteReservationsByFundId(fund.id);

        final archivedFund = fund.copyWith(
          isActive: false,
          showInDashboard: false,
        );

        await _accountsRepository.updateAccount(archivedFund);
        await _loadData();
      } catch (e) {
        _showError('Sparziel konnte nicht geschlossen werden: $e');
      }

      return;
    }

    if (balance > 0) {
      final destination = await _selectDestinationForClosingFund(
        fund: fund,
        balance: balance,
      );

      if (destination == null) {
        return;
      }

      final now = DateTime.now();

      final closingTransfer = FinancialTransactionModel(
        id: 'tx_close_${now.microsecondsSinceEpoch}',
        type: FinancialTransactionType.transfer,
        amount: balance,
        transactionDate: now,
        createdAt: now,
        title: 'Sparziel geschlossen: ${fund.name}',
        fromAccountId: fund.id,
        toAccountId: destination.id,
        note: 'Restbetrag von ${fund.name} wurde übertragen.',
      );

      final archivedFund = fund.copyWith(
        isActive: false,
        showInDashboard: false,
      );

      try {
        await _transactionsRepository.createTransaction(closingTransfer);
        await _accountsRepository.updateAccount(archivedFund);
        await _loadData();
      } catch (e) {
        _showError('Sparziel konnte nicht geschlossen werden: $e');
      }

      return;
    }

    final confirmed = await _confirmCloseEmptyFund(fund);

    if (!confirmed) {
      return;
    }

    try {
      if (hasTransactions) {
        final archivedFund = fund.copyWith(
          isActive: false,
          showInDashboard: false,
        );

        await _accountsRepository.updateAccount(archivedFund);
      } else {
        await _accountsRepository.deleteAccount(fund.id);
      }

      await _loadData();
    } catch (e) {
      _showError('Sparziel konnte nicht geschlossen werden: $e');
    }
  }

  Future<bool> _confirmCloseEmptyFund(AccountModel fund) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sparziel schließen'),
          content: Text(
            'Möchtest du das Sparziel "${fund.name}" wirklich schließen?',
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
              child: const Text('Schließen'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<AccountModel?> _selectDestinationForClosingFund({
    required AccountModel fund,
    required double balance,
  }) async {
    final destinations = _activeAccounts.where((account) {
      return account.id != fund.id;
    }).toList();

    if (destinations.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return const AlertDialog(
            title: Text('Kein Zielkonto vorhanden'),
            content: Text(
              'Es gibt kein anderes aktives Konto oder Sparziel, wohin der Restbetrag übertragen werden kann.',
            ),
          );
        },
      );

      return null;
    }

    return showModalBottomSheet<AccountModel>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Restbetrag übertragen',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'In "${fund.name}" sind noch €${balance.toStringAsFixed(2)}. '
                'Wohin wurde dieses Geld übertragen?',
              ),
              const SizedBox(height: 16),
              for (final destination in destinations)
                Card(
                  child: ListTile(
                    leading: Icon(
                      destination.kind == AccountKind.account
                          ? Icons.account_balance_outlined
                          : Icons.savings_outlined,
                    ),
                    title: Text(destination.name),
                    subtitle: Text(
                      destination.kind == AccountKind.account
                          ? 'Account'
                          : 'Sparziel',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.pop(context, destination);
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openAccountDetail(AccountModel account) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AccountDetailPage(
          account: account,
          transactions: _transactions,
        ),
      ),
    );

    await _loadData();
  }


  Future<void> _openInitialSetupPage() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const InitialBalancesPage(),
      ),
    );

    if (changed == true) {
      await _loadData();
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

  Future<void> _refresh() async {
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        appBar: _AccountsAppBar(),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: const _AccountsAppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.red,
                ),
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
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

    final accountsBalance = _totalBalance(_normalAccounts);
    final fundsBalance = _funds.fold(
      0.0,
      (sum, fund) => sum + _savingReservedAmountForFund(fund),
    );
    final totalMoney = accountsBalance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sparen'),
        actions: [
          IconButton(
            onPressed: _openInitialSetupPage,
            icon: const Icon(Icons.tune_outlined),
            tooltip: 'App-Start & Anfangsbestand',
          ),
          IconButton(
            onPressed: _openAddFundPage,
            icon: const Icon(Icons.add),
            tooltip: 'Sparziel erstellen',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SummaryCard(
              title: 'Total Money',
              amount: '€${totalMoney.toStringAsFixed(2)}',
              icon: Icons.account_balance_wallet_outlined,
            ),
            const SizedBox(height: 12),
            SummaryCard(
              title: 'Accounts Balance',
              amount: '€${accountsBalance.toStringAsFixed(2)}',
              icon: Icons.account_balance_outlined,
            ),
            const SizedBox(height: 12),
            SummaryCard(
              title: 'Reserved In Sparziele',
              amount: '€${fundsBalance.toStringAsFixed(2)}',
              icon: Icons.savings_outlined,
            ),

            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.tune_outlined),
                ),
                title: const Text('App-Start & Anfangsbestand'),
                subtitle: const Text(
                  'Startdatum, Bank/Cash-Startsaldo und alte Forderungen/Schulden einmalig einrichten.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openInitialSetupPage,
              ),
            ),
            const SizedBox(height: 24),
            const SectionTitle(title: 'Accounts'),
            const SizedBox(height: 12),
            if (_normalAccounts.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Noch keine normalen Konten vorhanden.'),
                ),
              )
            else
              for (final account in _normalAccounts)
                _AccountCard(
                  account: account,
                  openingBalance: account.balance,
                  movements: _currentBalance(account) - account.balance,
                  balance: _currentBalance(account),
                  reservations: _reservationsForAccount(account),
                  onTap: () => _openAccountDetail(account),
                ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(
                  child: SectionTitle(title: 'Sparziele'),
                ),
                TextButton.icon(
                  onPressed: _openAddFundPage,
                  icon: const Icon(Icons.add),
                  label: const Text('Neu'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_funds.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Noch keine Sparziele vorhanden.',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Erstelle eigene Sparziele wie Laptop, Notfallgeld oder Auto-Reparatur. '
                        'Danach kannst du Geld von Bank/Cash dafür reservieren.',
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: _openAddFundPage,
                        icon: const Icon(Icons.add),
                        label: const Text('Sparziel erstellen'),
                      ),
                    ],
                  ),
                ),
              )
            else
              for (final fund in _funds)
                _FundCard(
                  fund: fund,
                  reservedAmount: _savingReservedAmountForFund(fund),
                  reservedByAccount: _savingReservedByAccountForFund(fund),
                  accountNameForId: _accountName,
                  onTap: () => _openAccountDetail(fund),
                  onReserve: () => _openAddFundReservationPage(fund),
                  onRelease: () => _releaseFundReservation(fund),
                  onEdit: () => _openEditFundPage(fund),
                  onClose: () => _closeFund(fund),
                ),
            const SizedBox(height: 90),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddTransferPage,
        icon: const Icon(Icons.swap_horiz),
        label: const Text('Transfer'),
      ),
    );
  }
}

class _AccountsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _AccountsAppBar();

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('Sparen'),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _ReservedMoneyInfo {
  final String title;
  final double amount;
  final String typeLabel;

  const _ReservedMoneyInfo({
    required this.title,
    required this.amount,
    required this.typeLabel,
  });
}

class _AccountCard extends StatelessWidget {
  final AccountModel account;
  final double openingBalance;
  final double movements;
  final double balance;
  final List<_ReservedMoneyInfo> reservations;
  final VoidCallback onTap;

  const _AccountCard({
    required this.account,
    required this.openingBalance,
    required this.movements,
    required this.balance,
    required this.reservations,
    required this.onTap,
  });

  double get _reservedAmount {
    return reservations.fold(
      0.0,
      (sum, reservation) => sum + reservation.amount,
    );
  }

  double get _freeAmount {
    return balance - _reservedAmount;
  }

  String _money(double value) {
    final sign = value > 0 ? '+' : '';
    return '$sign€${value.toStringAsFixed(2)}';
  }

  Widget _line({
    required IconData icon,
    required String title,
    required String value,
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title,
              style: bold ? const TextStyle(fontWeight: FontWeight.bold) : null,
            ),
          ),
          Text(
            value,
            style: bold ? const TextStyle(fontWeight: FontWeight.bold) : null,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasReservations = reservations.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    child: Icon(Icons.account_balance_outlined),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        const Text('Aktueller Kontostand'),
                      ],
                    ),
                  ),
                  Text(
                    '€${balance.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              _line(
                icon: Icons.flag_outlined,
                title: 'Anfangsbestand / Startsaldo',
                value: '€${openingBalance.toStringAsFixed(2)}',
              ),
              _line(
                icon: Icons.compare_arrows_outlined,
                title: 'Bewegungen seit Start',
                value: _money(movements),
              ),
              _line(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Aktueller Kontostand',
                value: '€${balance.toStringAsFixed(2)}',
                bold: true,
              ),
              if (hasReservations) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                _line(
                  icon: Icons.lock_outline,
                  title: 'Reserviert',
                  value: '€${_reservedAmount.toStringAsFixed(2)}',
                  bold: true,
                ),
                for (final reservation in reservations)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        const SizedBox(width: 24),
                        Expanded(
                          child: Text(
                            '${reservation.title} · ${reservation.typeLabel}',
                          ),
                        ),
                        Text('€${reservation.amount.toStringAsFixed(2)}'),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                _line(
                  icon: Icons.wallet_outlined,
                  title: 'Frei verfügbar',
                  value: '€${_freeAmount.toStringAsFixed(2)}',
                  bold: true,
                ),
              ] else ...[
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Keine Reservierungen'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}


class _FundCard extends StatelessWidget {
  final AccountModel fund;
  final double reservedAmount;
  final Map<String, double> reservedByAccount;
  final String Function(String? accountId) accountNameForId;
  final VoidCallback onTap;
  final VoidCallback onReserve;
  final VoidCallback onRelease;
  final VoidCallback onEdit;
  final VoidCallback onClose;

  const _FundCard({
    required this.fund,
    required this.reservedAmount,
    required this.reservedByAccount,
    required this.accountNameForId,
    required this.onTap,
    required this.onReserve,
    required this.onRelease,
    required this.onEdit,
    required this.onClose,
  });

  bool get _hasTarget {
    return fund.targetAmount != null && fund.targetAmount! > 0;
  }

  bool get _isGoalReached {
    if (!_hasTarget) {
      return false;
    }

    return reservedAmount >= fund.targetAmount!;
  }

  double? get _progress {
    if (!_hasTarget) {
      return null;
    }

    final progress = reservedAmount / fund.targetAmount!;

    if (progress < 0) {
      return 0;
    }

    if (progress > 1) {
      return 1;
    }

    return progress;
  }

  double get _remainingAmount {
    if (!_hasTarget) {
      return 0;
    }

    final remaining = fund.targetAmount! - reservedAmount;

    if (remaining < 0) {
      return 0;
    }

    return remaining;
  }

  double get _overTargetAmount {
    if (!_hasTarget) {
      return 0;
    }

    final overTarget = reservedAmount - fund.targetAmount!;

    if (overTarget < 0) {
      return 0;
    }

    return overTarget;
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day.$month.$year';
  }

  String _progressText() {
    if (!_hasTarget) {
      return '';
    }

    final percent = ((_progress ?? 0) * 100).round();

    if (_isGoalReached && _overTargetAmount > 0) {
      return 'Ziel erreicht · +€${_overTargetAmount.toStringAsFixed(2)} über Ziel';
    }

    if (_isGoalReached) {
      return 'Ziel erreicht';
    }

    return '$percent% erreicht · Noch €${_remainingAmount.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    child: Icon(Icons.savings_outlined),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      fund.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    '€${reservedAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        onEdit();
                      }

                      if (value == 'close') {
                        onClose();
                      }
                    },
                    itemBuilder: (context) {
                      return const [
                        PopupMenuItem(
                          value: 'edit',
                          child: Text('Bearbeiten'),
                        ),
                        PopupMenuItem(
                          value: 'close',
                          child: Text('Schließen'),
                        ),
                      ];
                    },
                  ),
                ],
              ),
              if (_hasTarget) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: _progress,
                ),
                const SizedBox(height: 6),
                Text(
                  'Ziel: €${fund.targetAmount!.toStringAsFixed(2)}',
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      _isGoalReached
                          ? Icons.check_circle_outline
                          : Icons.timelapse_outlined,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(_progressText()),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              const Text(
                'Reserviert nach Konto',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              if (reservedByAccount.isEmpty)
                const Text('Noch keine Reservierung.')
              else
                for (final entry in reservedByAccount.entries)
                  Text(
                    '${accountNameForId(entry.key)}: €${entry.value.toStringAsFixed(2)}',
                  ),
              if (fund.startDate != null) ...[
                const SizedBox(height: 4),
                Text('Startdatum: ${_formatDate(fund.startDate!)}'),
              ],
              if (fund.targetDate != null) ...[
                const SizedBox(height: 4),
                Text('Zieldatum: ${_formatDate(fund.targetDate!)}'),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onReserve,
                      icon: const Icon(Icons.lock_outline),
                      label: const Text('Reservieren'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: reservedAmount > 0 ? onRelease : null,
                      icon: const Icon(Icons.lock_open_outlined),
                      label: const Text('Entnehmen'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


