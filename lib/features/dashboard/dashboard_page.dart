import 'package:flutter/material.dart';

import '../../core/formatters/money_formatter.dart';
import '../../core/localization/app_strings.dart';
import '../../core/supabase/app_data_loader_service.dart';
import '../../shared/models/account_model.dart';
import '../../shared/models/financial_transaction_model.dart';
import '../../shared/models/profile_model.dart';
import '../../shared/models/saving_goal_reservation_model.dart';
import '../../shared/models/travel_contribution_model.dart';
import '../../shared/models/travel_plan_model.dart';
import '../../shared/widgets/simple_finance_charts.dart';
import '../profile/profile_repository.dart';
import '../savings/account_balance_calculator.dart';
import '../savings/account_mock_data.dart';
import '../savings/financial_transaction_mock_data.dart';
import '../savings/saving_goal_reservations_repository.dart';
import '../travel/travel_repository.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final TravelRepository _travelRepository = TravelRepository();
  final SavingGoalReservationsRepository _savingReservationsRepository =
      SavingGoalReservationsRepository();
  final ProfileRepository _profileRepository = ProfileRepository();

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  List<TravelPlanModel> _travelPlans = [];
  List<TravelContributionModel> _travelContributions = [];
  List<SavingGoalReservationModel> _savingReservations = [];
  ProfileModel? _profile;
  bool _showAllAccounts = false;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await AppDataLoaderService.loadInitialFinanceData();
      final results = await Future.wait<dynamic>([
        _travelRepository.fetchTravelData(),
        _savingReservationsRepository.fetchReservations(),
        _profileRepository.fetchOrCreateProfile(),
      ]);
      if (!mounted) return;
      final travelData = results[0] as TravelDbData;
      setState(() {
        _travelPlans = travelData.travelPlans;
        _travelContributions = travelData.contributions;
        _savingReservations = results[1] as List<SavingGoalReservationModel>;
        _profile = results[2] as ProfileModel;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Fehler beim Laden des Dashboards: $e';
        _isLoading = false;
      });
    }
  }

  List<FinancialTransactionModel> get _transactions =>
      FinancialTransactionMockData.transactions;
  List<AccountModel> get _accounts => AccountMockData.accounts;
  List<AccountModel> get _normalAccounts => _accounts
      .where((a) => a.isActive && a.kind == AccountKind.account)
      .toList();
  List<AccountModel> get _activeSavingGoals => _accounts
      .where((a) => a.isActive && a.kind == AccountKind.fund)
      .toList();
  List<TravelPlanModel> get _activeTravelPlans => _travelPlans
      .where((p) => p.status == TravelPlanStatus.active)
      .toList();

  bool _inSelectedMonth(DateTime date) =>
      date.year == _selectedMonth.year && date.month == _selectedMonth.month;

  List<FinancialTransactionModel> get _monthlyTransactions =>
      _transactions.where((t) => _inSelectedMonth(t.transactionDate)).toList();

  String get _selectedMonthText =>
      '${AppStrings.monthName(_selectedMonth.month)} ${_selectedMonth.year}';

  double _currentBalance(AccountModel account) =>
      AccountBalanceCalculator.calculateBalance(
        accountId: account.id,
        openingBalance: account.balance,
        transactions: _transactions,
      );

  double get _accountsBalance =>
      _normalAccounts.fold(0.0, (sum, a) => sum + _currentBalance(a));

  double get _travelReservedTotal {
    final ids = _activeTravelPlans.map((p) => p.id).toSet();
    return _travelContributions
        .where((item) => ids.contains(item.travelPlanId))
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  double get _savingReservedTotal {
    final ids = _activeSavingGoals.map((g) => g.id).toSet();
    return _savingReservations
        .where((item) => ids.contains(item.fundId))
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  double get _reservedTotal => _travelReservedTotal + _savingReservedTotal;
  double get _freeAvailable => _accountsBalance - _reservedTotal;

  double _sumByType(FinancialTransactionType type) => _monthlyTransactions
      .where((t) => t.type == type)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get _realIncome => _sumByType(FinancialTransactionType.income);
  double get _realExpenses => _sumByType(FinancialTransactionType.expense);
  double get _monthlySavings =>
      _travelContributions.where((i) => _inSelectedMonth(i.date)).fold(
            0.0,
            (sum, i) => sum + i.amount,
          ) +
      _savingReservations.where((i) => _inSelectedMonth(i.date)).fold(
            0.0,
            (sum, i) => sum + i.amount,
          );
  double get _monthlyDebtOutflow =>
      _sumByType(FinancialTransactionType.debtPaidBack) +
      _sumByType(FinancialTransactionType.debtGiven);
  double get _remainingIncome =>
      _realIncome - _realExpenses - _monthlySavings - _monthlyDebtOutflow;

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Guten Morgen 👋';
    if (hour < 18) return 'Guten Tag 👋';
    return 'Guten Abend 👋';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(AppStrings.dashboard)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: Text(AppStrings.dashboard)),
        body: Center(
          child: FilledButton.icon(
            onPressed: _loadDashboardData,
            icon: const Icon(Icons.refresh),
            label: const Text('Erneut versuchen'),
          ),
        ),
      );
    }

    final visibleAccounts =
        _showAllAccounts ? _normalAccounts : _normalAccounts.take(3).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.dashboard),
        actions: [
          IconButton(
            onPressed: _loadDashboardData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Aktualisieren',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _ProfileHeader(profile: _profile, greeting: _greeting()),
            const SizedBox(height: 14),
            _HeroMoneyCard(
              title: 'Frei verfügbar',
              amount: MoneyFormatter.format(_freeAvailable),
              subtitle:
                  'Gesamt: ${MoneyFormatter.format(_accountsBalance)} · Reserviert: ${MoneyFormatter.format(_reservedTotal)}',
            ),
            const SizedBox(height: 14),
            _MonthSelector(
              title: _selectedMonthText,
              onPrevious: () => setState(() => _selectedMonth =
                  DateTime(_selectedMonth.year, _selectedMonth.month - 1)),
              onNext: () => setState(() => _selectedMonth =
                  DateTime(_selectedMonth.year, _selectedMonth.month + 1)),
            ),
            const SizedBox(height: 14),
            _IncomeAllocationCard(
              income: _realIncome,
              expenses: _realExpenses,
              savings: _monthlySavings,
              debt: _monthlyDebtOutflow,
              remaining: _remainingIncome,
            ),
            const SizedBox(height: 14),
            FinanceBarChartCard(
              title: 'Monatsübersicht',
              subtitle: 'Beträge des ausgewählten Monats',
              valuePrefix: '€',
              data: [
                FinanceBarDatum(label: 'Einnahmen', value: _realIncome),
                FinanceBarDatum(label: 'Ausgaben', value: _realExpenses),
                FinanceBarDatum(label: 'Sparen', value: _monthlySavings),
                FinanceBarDatum(label: 'Schulden', value: _monthlyDebtOutflow),
              ],
            ),
            const SizedBox(height: 14),
            FinanceProgressSplitCard(
              title: 'Frei verfügbar vs. reserviert',
              firstValue: _freeAvailable,
              secondValue: _reservedTotal,
              firstLabel: 'Frei',
              secondLabel: 'Reserviert',
              formatter: MoneyFormatter.format,
            ),
            const SizedBox(height: 22),
            _SectionHeader(title: 'Konten'),
            const SizedBox(height: 8),
            if (visibleAccounts.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Keine Konten vorhanden.'),
                ),
              )
            else
              for (final account in visibleAccounts)
                _AccountCompactCard(
                  name: account.name,
                  balance: _currentBalance(account),
                ),
            if (_normalAccounts.length > 3)
              TextButton.icon(
                onPressed: () =>
                    setState(() => _showAllAccounts = !_showAllAccounts),
                icon: Icon(_showAllAccounts
                    ? Icons.expand_less
                    : Icons.expand_more),
                label: Text(
                    _showAllAccounts ? 'Weniger anzeigen' : 'Mehr anzeigen'),
              ),
            const SizedBox(height: 18),
            const _SectionHeader(title: 'Reservierungen'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _MiniStatCard(
                    title: 'Reisen',
                    value: MoneyFormatter.format(_travelReservedTotal),
                    icon: Icons.flight_takeoff,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MiniStatCard(
                    title: 'Sparziele',
                    value: MoneyFormatter.format(_savingReservedTotal),
                    icon: Icons.savings_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 90),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final ProfileModel? profile;
  final String greeting;
  const _ProfileHeader({required this.profile, required this.greeting});

  @override
  Widget build(BuildContext context) {
    final url = profile?.avatarUrl;
    return Row(
      children: [
        CircleAvatar(
          radius: 27,
          backgroundImage: url != null && url.isNotEmpty ? NetworkImage(url) : null,
          child: url == null || url.isEmpty
              ? const Icon(Icons.person_outline, size: 28)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile?.displayName.isNotEmpty == true
                    ? profile!.displayName
                    : 'Benutzer',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 2),
              Text(greeting,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      )),
            ],
          ),
        ),
      ],
    );
  }
}

class _IncomeAllocationCard extends StatelessWidget {
  final double income;
  final double expenses;
  final double savings;
  final double debt;
  final double remaining;
  const _IncomeAllocationCard({
    required this.income,
    required this.expenses,
    required this.savings,
    required this.debt,
    required this.remaining,
  });

  @override
  Widget build(BuildContext context) {
    if (income <= 0) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Für diesen Monat gibt es noch kein Einkommen. Deshalb werden keine Prozentwerte berechnet.',
          ),
        ),
      );
    }
    double percent(double value) => value / income * 100;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Verwendung des Monatseinkommens',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    )),
            const SizedBox(height: 4),
            Text('Basis: ${MoneyFormatter.format(income)} Einnahmen'),
            const SizedBox(height: 14),
            _AllocationRow(label: 'Ausgaben', value: expenses, percent: percent(expenses)),
            _AllocationRow(label: 'Sparen', value: savings, percent: percent(savings)),
            _AllocationRow(label: 'Schulden', value: debt, percent: percent(debt)),
            _AllocationRow(
              label: remaining < 0 ? 'Überzogen' : 'Übrig',
              value: remaining.abs(),
              percent: percent(remaining).abs(),
              isWarning: remaining < 0,
            ),
          ],
        ),
      ),
    );
  }
}

class _AllocationRow extends StatelessWidget {
  final String label;
  final double value;
  final double percent;
  final bool isWarning;
  const _AllocationRow({
    required this.label,
    required this.value,
    required this.percent,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isWarning
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text('${percent.toStringAsFixed(1)}%',
              style: TextStyle(fontWeight: FontWeight.w700, color: color)),
          const SizedBox(width: 10),
          SizedBox(
            width: 90,
            child: Text(MoneyFormatter.format(value), textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}

class _MonthSelector extends StatelessWidget {
  final String title;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  const _MonthSelector({required this.title, required this.onPrevious, required this.onNext});
  @override
  Widget build(BuildContext context) => Card(
        child: Row(
          children: [
            IconButton(onPressed: onPrevious, icon: const Icon(Icons.chevron_left)),
            Expanded(
              child: Text(title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ),
            IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
          ],
        ),
      );
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) => Text(title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700));
}

class _HeroMoneyCard extends StatelessWidget {
  final String title;
  final String amount;
  final String subtitle;
  const _HeroMoneyCard({required this.title, required this.amount, required this.subtitle});
  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title),
            const SizedBox(height: 7),
            Text(amount,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 7),
            Text(subtitle),
          ]),
        ),
      );
}

class _MiniStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  const _MiniStatCard({required this.title, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon),
            const SizedBox(height: 9),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ]),
        ),
      );
}

class _AccountCompactCard extends StatelessWidget {
  final String name;
  final double balance;
  const _AccountCompactCard({required this.name, required this.balance});
  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.account_balance_wallet_outlined)),
          title: Text(name),
          trailing: Text(MoneyFormatter.format(balance),
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      );
}
