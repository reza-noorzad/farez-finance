
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../core/formatters/money_formatter.dart';
import '../../core/supabase/app_data_loader_service.dart';
import '../../shared/models/account_model.dart';
import '../../shared/models/expense_item_model.dart';
import '../../shared/models/financial_transaction_model.dart';
import '../../shared/models/debt_model.dart';
import '../../shared/models/debt_payment_model.dart';
import '../../shared/models/saving_goal_reservation_model.dart';
import '../../shared/models/travel_contribution_model.dart';
import '../../shared/models/travel_plan_model.dart';
import '../expenses/expense_repository.dart';
import '../categories/category_mock_data.dart';
import '../debts/debt_repository.dart';
import '../savings/account_balance_calculator.dart';
import '../savings/account_mock_data.dart';
import '../savings/financial_transaction_mock_data.dart';
import '../savings/saving_goal_reservations_repository.dart';
import '../travel/travel_repository.dart';
import 'report_pdf_generator.dart';

enum ReportPeriodMode {
  monthly,
  yearly,
  custom,
}

class ReportExportOptions {
  final bool overview;
  final bool incomes;
  final bool expenses;
  final bool budgets;
  final bool debts;
  final bool travel;
  final bool savings;
  final bool products;
  final bool foodAmounts;
  final bool transactions;

  const ReportExportOptions({
    this.overview = true,
    this.incomes = true,
    this.expenses = true,
    this.budgets = false,
    this.debts = true,
    this.travel = true,
    this.savings = true,
    this.products = true,
    this.foodAmounts = true,
    this.transactions = false,
  });

  ReportExportOptions copyWith({
    bool? overview,
    bool? incomes,
    bool? expenses,
    bool? budgets,
    bool? debts,
    bool? travel,
    bool? savings,
    bool? products,
    bool? foodAmounts,
    bool? transactions,
  }) {
    return ReportExportOptions(
      overview: overview ?? this.overview,
      incomes: incomes ?? this.incomes,
      expenses: expenses ?? this.expenses,
      budgets: budgets ?? this.budgets,
      debts: debts ?? this.debts,
      travel: travel ?? this.travel,
      savings: savings ?? this.savings,
      products: products ?? this.products,
      foodAmounts: foodAmounts ?? this.foodAmounts,
      transactions: transactions ?? this.transactions,
    );
  }
}

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final TravelRepository _travelRepository = TravelRepository();
  final SavingGoalReservationsRepository _savingReservationsRepository =
      SavingGoalReservationsRepository();
  final ExpenseRepository _expenseRepository = ExpenseRepository();
  final DebtRepository _debtRepository = DebtRepository();

  ReportPeriodMode _periodMode = ReportPeriodMode.monthly;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  int _selectedYear = DateTime.now().year;
  DateTime _customStart = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _customEnd = DateTime.now();

  ReportExportOptions _exportOptions = const ReportExportOptions();

  List<TravelPlanModel> _travelPlans = [];
  List<TravelContributionModel> _travelContributions = [];
  List<SavingGoalReservationModel> _savingReservations = [];
  List<ExpenseItemModel> _expenseItems = [];
  List<DebtModel> _debts = [];
  List<DebtPaymentModel> _debtPayments = [];

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReportsData();
  }

  Future<void> _loadReportsData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await AppDataLoaderService.loadInitialFinanceData();

      final travelData = await _travelRepository.fetchTravelData();
      final savingReservations =
          await _savingReservationsRepository.fetchReservations();
      final expenseRecords =
          await _expenseRepository.fetchExpensesWithTransactions();
      final debtData = await _debtRepository.fetchDebtData();

      final items = <ExpenseItemModel>[];

      for (final record in expenseRecords) {
        items.addAll(record.expense.items);
      }

      if (!mounted) return;

      setState(() {
        _travelPlans = travelData.travelPlans;
        _travelContributions = travelData.contributions;
        _savingReservations = savingReservations;
        _expenseItems = items;
        _debts = debtData.debts;
        _debtPayments = debtData.payments;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Fehler beim Laden der Reports: $e';
        _isLoading = false;
      });
    }
  }

  DateTime get _rangeStart {
    switch (_periodMode) {
      case ReportPeriodMode.monthly:
        return DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      case ReportPeriodMode.yearly:
        return DateTime(_selectedYear, 1, 1);
      case ReportPeriodMode.custom:
        return DateTime(_customStart.year, _customStart.month, _customStart.day);
    }
  }

  DateTime get _rangeEnd {
    switch (_periodMode) {
      case ReportPeriodMode.monthly:
        return DateTime(
          _selectedMonth.year,
          _selectedMonth.month + 1,
          0,
          23,
          59,
          59,
        );
      case ReportPeriodMode.yearly:
        return DateTime(_selectedYear, 12, 31, 23, 59, 59);
      case ReportPeriodMode.custom:
        return DateTime(
          _customEnd.year,
          _customEnd.month,
          _customEnd.day,
          23,
          59,
          59,
        );
    }
  }

  List<FinancialTransactionModel> get _rangeTransactions {
    return FinancialTransactionMockData.transactions.where((transaction) {
      return !transaction.transactionDate.isBefore(_rangeStart) &&
          !transaction.transactionDate.isAfter(_rangeEnd);
    }).toList();
  }

  List<ExpenseItemModel> get _rangeItems {
    return _expenseItems.where((item) {
      return !item.date.isBefore(_rangeStart) && !item.date.isAfter(_rangeEnd);
    }).toList();
  }

  List<TravelContributionModel> get _rangeTravelReservations {
    return _travelContributions.where((item) {
      return !item.date.isBefore(_rangeStart) && !item.date.isAfter(_rangeEnd);
    }).toList();
  }

  List<SavingGoalReservationModel> get _rangeSavingReservations {
    return _savingReservations.where((item) {
      return !item.date.isBefore(_rangeStart) && !item.date.isAfter(_rangeEnd);
    }).toList();
  }

  List<AccountModel> get _accounts => AccountMockData.accounts;

  List<AccountModel> get _normalAccounts {
    return _accounts.where((account) {
      return account.isActive && account.kind == AccountKind.account;
    }).toList();
  }

  List<AccountModel> get _funds {
    return _accounts.where((account) {
      return account.isActive && account.kind == AccountKind.fund;
    }).toList();
  }

  double get _totalMoney {
    return _normalAccounts.fold(0.0, (sum, account) {
      return sum +
          AccountBalanceCalculator.calculateBalance(
            accountId: account.id,
            openingBalance: account.balance,
            transactions: FinancialTransactionMockData.transactions,
          );
    });
  }

  double get _activeTravelReserved {
    final activeTravelIds = _travelPlans
        .where((plan) => plan.status == TravelPlanStatus.active)
        .map((plan) => plan.id)
        .toSet();

    return _travelContributions.where((item) {
      return activeTravelIds.contains(item.travelPlanId);
    }).fold(0.0, (sum, item) => sum + item.amount);
  }

  double get _activeSavingReserved {
    final activeGoalIds = _funds.map((fund) => fund.id).toSet();

    return _savingReservations.where((item) {
      return activeGoalIds.contains(item.fundId);
    }).fold(0.0, (sum, item) => sum + item.amount);
  }

  double get _reservedTotal => _activeTravelReserved + _activeSavingReserved;

  double get _freeAvailable => _totalMoney - _reservedTotal;

  double get _openingReceivables {
    return _debts
        .where((debt) => debt.isOpeningBalance && debt.kind == DebtKind.moneyLent)
        .fold(0.0, (sum, debt) => sum + debt.originalAmount);
  }

  double get _openingLiabilities {
    return _debts
        .where((debt) => debt.isOpeningBalance && debt.kind == DebtKind.moneyBorrowed)
        .fold(0.0, (sum, debt) => sum + debt.originalAmount);
  }

  double get _openReceivables {
    return _debts
        .where((debt) => debt.isActive && debt.kind == DebtKind.moneyLent)
        .fold(0.0, (sum, debt) => sum + debt.remainingAmountFrom(_debtPayments));
  }

  double get _openLiabilities {
    return _debts
        .where((debt) => debt.isActive && debt.kind == DebtKind.moneyBorrowed)
        .fold(0.0, (sum, debt) => sum + debt.remainingAmountFrom(_debtPayments));
  }


  String _accountName(String? id) {
    if (id == null || id.isEmpty) return 'Unbekannt';
    try { return _accounts.firstWhere((a) => a.id == id).name; } catch (_) { return 'Unbekannt'; }
  }

  String _categoryName(String? id) {
    if (id == null || id.isEmpty) return 'Ohne Kategorie';
    return CategoryMockData.findById(id)?.name ?? 'Ohne Kategorie';
  }

  Map<String, double> get _paymentSourceTotals {
    final result = <String, double>{};
    for (final tx in _rangeTransactions.where((t) => t.type == FinancialTransactionType.expense)) {
      final name = _accountName(tx.fromAccountId);
      result[name] = (result[name] ?? 0) + tx.amount;
    }
    return result;
  }

  Map<String, Map<String, double>> get _paymentByCategory {
    final result = <String, Map<String, double>>{};
    for (final tx in _rangeTransactions.where((t) => t.type == FinancialTransactionType.expense)) {
      final category = _categoryName(tx.categoryId);
      final account = _accountName(tx.fromAccountId);
      final row = result.putIfAbsent(category, () => <String, double>{});
      row[account] = (row[account] ?? 0) + tx.amount;
    }
    return result;
  }

  Map<String, double> get _reservationDetails {
    final result = <String, double>{};
    for (final plan in _travelPlans.where((p) => p.status == TravelPlanStatus.active)) {
      final amount = _travelContributions.where((c) => c.travelPlanId == plan.id).fold(0.0, (sum, c) => sum + c.amount);
      if (amount.abs() > 0.005) result['Reise · ${plan.destination}'] = amount;
    }
    for (final fund in _funds) {
      final amount = _savingReservations.where((r) => r.fundId == fund.id).fold(0.0, (sum, r) => sum + r.amount);
      if (amount.abs() > 0.005) result['Sparziel · ${fund.name}'] = amount;
    }
    return result;
  }

  double _sumByType(FinancialTransactionType type) {
    return _rangeTransactions
        .where((transaction) => transaction.type == type)
        .fold(0.0, (sum, transaction) => sum + transaction.amount);
  }

  String _rangeTitle() {
    switch (_periodMode) {
      case ReportPeriodMode.monthly:
        return '${_monthName(_selectedMonth.month)} ${_selectedMonth.year}';
      case ReportPeriodMode.yearly:
        return 'Jahr $_selectedYear';
      case ReportPeriodMode.custom:
        return '${_formatDate(_rangeStart)} - ${_formatDate(_rangeEnd)}';
    }
  }

  String _monthName(int month) {
    const names = [
      'Januar',
      'Februar',
      'März',
      'April',
      'Mai',
      'Juni',
      'Juli',
      'August',
      'September',
      'Oktober',
      'November',
      'Dezember',
    ];

    return names[month - 1];
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day.$month.${date.year}';
  }

  Future<void> _pickCustomDate({required bool start}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _customStart : _customEnd,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    setState(() {
      if (start) {
        _customStart = picked;

        if (_customEnd.isBefore(_customStart)) {
          _customEnd = picked;
        }
      } else {
        _customEnd = picked;

        if (_customEnd.isBefore(_customStart)) {
          _customStart = picked;
        }
      }
    });
  }

  Future<void> _openExportOptions() async {
    final options = await showDialog<ReportExportOptions>(
      context: context,
      builder: (context) {
        return _ReportOptionsDialog(initialOptions: _exportOptions);
      },
    );

    if (options == null) return;

    setState(() {
      _exportOptions = options;
    });

    await _exportPdf();
  }

  Future<void> _exportPdf() async {
    try {
      final realIncome = _sumByType(FinancialTransactionType.income);
      final realExpenses = _sumByType(FinancialTransactionType.expense);
      final netResult = realIncome - realExpenses;

      final transfersAndSavings = _rangeTransactions.where((transaction) {
        return transaction.type == FinancialTransactionType.transfer ||
            transaction.type == FinancialTransactionType.travelSaving ||
            transaction.type == FinancialTransactionType.travelWithdrawal;
      }).fold(0.0, (sum, transaction) => sum + transaction.amount);

      final accountBalances = <String, double>{};
      final accountPeriodStartBalances = <String, double>{};
      final accountPeriodEndBalances = <String, double>{};

      final beforeRangeStart = _rangeStart.subtract(const Duration(seconds: 1));

      for (final account in _normalAccounts) {
        accountBalances[account.id] = AccountBalanceCalculator.calculateBalance(
          accountId: account.id,
          openingBalance: account.balance,
          transactions: FinancialTransactionMockData.transactions,
        );

        accountPeriodStartBalances[account.id] =
            AccountBalanceCalculator.calculateBalanceUntilDate(
          accountId: account.id,
          openingBalance: account.balance,
          transactions: FinancialTransactionMockData.transactions,
          endDate: beforeRangeStart,
        );

        accountPeriodEndBalances[account.id] =
            AccountBalanceCalculator.calculateBalanceUntilDate(
          accountId: account.id,
          openingBalance: account.balance,
          transactions: FinancialTransactionMockData.transactions,
          endDate: _rangeEnd,
        );
      }

      final bytes = await ReportPdfGenerator.generateFullReport(
        reportTitle: _rangeTitle(),
        generatedAt: DateTime.now(),
        totalMoney: _totalMoney,
        freeAvailable: _freeAvailable,
        reservedTotal: _reservedTotal,
        rangeStart: _rangeStart,
        rangeEnd: _rangeEnd,
        travelReservedTotal: _activeTravelReserved,
        savingReservedTotal: _activeSavingReserved,
        realIncome: realIncome,
        realExpenses: realExpenses,
        netResult: netResult,
        transfersAndSavings: transfersAndSavings,
        moneyLent: _sumByType(FinancialTransactionType.debtGiven),
        moneyReturned: _sumByType(FinancialTransactionType.debtReturned),
        moneyBorrowed: _sumByType(FinancialTransactionType.debtBorrowed),
        debtPaidBack: _sumByType(FinancialTransactionType.debtPaidBack),
        openingReceivables: _openingReceivables,
        openingLiabilities: _openingLiabilities,
        openReceivables: _openReceivables,
        openLiabilities: _openLiabilities,
        debts: _debts,
        debtPayments: _debtPayments,
        accounts: _normalAccounts,
        accountBalances: accountBalances,
        accountPeriodStartBalances: accountPeriodStartBalances,
        accountPeriodEndBalances: accountPeriodEndBalances,
        productItems: _rangeItems,
        transactions: _rangeTransactions,
        paymentSourceTotals: _paymentSourceTotals,
        reservationDetails: _reservationDetails,
        includeOverview: _exportOptions.overview,
        includeAccounts: true,
        includeIncomes: _exportOptions.incomes,
        includeExpenses: _exportOptions.expenses,
        includeDebts: _exportOptions.debts,
        includeTravel: _exportOptions.travel,
        includeSavings: _exportOptions.savings,
        includeProducts: _exportOptions.products,
        includeFoodAmounts: _exportOptions.foodAmounts,
        includeTransactions: _exportOptions.transactions,
      );

      await Printing.sharePdf(
        bytes: bytes,
        filename: 'farez_finance_${_rangeTitle().replaceAll(' ', '_')}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF konnte nicht erstellt werden: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  Map<String, _FoodAmountSummary> _foodAmounts() {
    final result = <String, _FoodAmountSummary>{};

    for (final item in _rangeItems.where((item) => item.isMeasurementImportant)) {
      final key = item.reportName.toLowerCase();
      final current = result[key] ?? _FoodAmountSummary(name: item.reportName);

      result[key] = current.add(item);
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Berichte')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Berichte')),
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

    final realIncome = _sumByType(FinancialTransactionType.income);
    final realExpenses = _sumByType(FinancialTransactionType.expense);
    final debtMovements = _rangeTransactions.where((transaction) {
      return transaction.type == FinancialTransactionType.debtGiven ||
          transaction.type == FinancialTransactionType.debtReturned ||
          transaction.type == FinancialTransactionType.debtBorrowed ||
          transaction.type == FinancialTransactionType.debtPaidBack;
    }).fold(0.0, (sum, item) => sum + item.amount);

    final foodSummaries = _foodAmounts().values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Berichte'),
        actions: [
          IconButton(
            onPressed: _loadReportsData,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: _openExportOptions,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'PDF Optionen',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadReportsData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<ReportPeriodMode>(
              segments: const [
                ButtonSegment(
                  value: ReportPeriodMode.monthly,
                  label: Text('Monat'),
                ),
                ButtonSegment(
                  value: ReportPeriodMode.yearly,
                  label: Text('Jahr'),
                ),
                ButtonSegment(
                  value: ReportPeriodMode.custom,
                  label: Text('Zeitraum'),
                ),
              ],
              selected: {_periodMode},
              onSelectionChanged: (selection) {
                setState(() {
                  _periodMode = selection.first;
                });
              },
            ),
            const SizedBox(height: 12),
            _PeriodSelector(
              mode: _periodMode,
              title: _rangeTitle(),
              onPrevious: () {
                setState(() {
                  if (_periodMode == ReportPeriodMode.monthly) {
                    _selectedMonth = DateTime(
                      _selectedMonth.year,
                      _selectedMonth.month - 1,
                    );
                  } else if (_periodMode == ReportPeriodMode.yearly) {
                    _selectedYear--;
                  }
                });
              },
              onNext: () {
                setState(() {
                  if (_periodMode == ReportPeriodMode.monthly) {
                    _selectedMonth = DateTime(
                      _selectedMonth.year,
                      _selectedMonth.month + 1,
                    );
                  } else if (_periodMode == ReportPeriodMode.yearly) {
                    _selectedYear++;
                  }
                });
              },
              onPickStart: () => _pickCustomDate(start: true),
              onPickEnd: () => _pickCustomDate(start: false),
            ),
            const SizedBox(height: 16),
            _ReportCard(
              title: 'Frei verfügbar',
              value: MoneyFormatter.format(_freeAvailable),
              icon: Icons.account_balance_wallet_outlined,
            ),
            _ReportCard(
              title: 'Gesamtvermögen',
              value: MoneyFormatter.format(_totalMoney),
              icon: Icons.account_balance_outlined,
            ),
            _ReportCard(
              title: 'Reserviert gesamt',
              value: MoneyFormatter.format(_reservedTotal),
              icon: Icons.lock_outline,
            ),
            const SizedBox(height: 16),
            _ReportCard(
              title: 'Echte Einnahmen',
              value: MoneyFormatter.format(realIncome),
              icon: Icons.trending_up_outlined,
            ),
            _ReportCard(
              title: 'Echte Ausgaben',
              value: MoneyFormatter.format(realExpenses),
              icon: Icons.trending_down_outlined,
            ),
            _ReportCard(
              title: 'Netto Ergebnis',
              value: MoneyFormatter.format(realIncome - realExpenses),
              icon: Icons.calculate_outlined,
            ),
            const SizedBox(height: 24),
            Text('Konten & Zahlungsarten', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (_paymentSourceTotals.isEmpty)
              const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Keine Ausgaben im Zeitraum.')))
            else ...[
              for (final entry in _paymentSourceTotals.entries)
                _ReportCard(
                  title: entry.key,
                  value: MoneyFormatter.format(entry.value),
                  icon: Icons.payments_outlined,
                ),
              ExpansionTile(
                title: const Text('Nach Kategorie anzeigen'),
                children: [
                  for (final category in _paymentByCategory.entries)
                    ListTile(
                      title: Text(category.key),
                      subtitle: Text(category.value.entries.map((e) => '${e.key}: ${MoneyFormatter.format(e.value)}').join(' · ')),
                      trailing: Text(MoneyFormatter.format(category.value.values.fold(0.0, (a, b) => a + b))),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            Text('Reservierungen nach Ziel', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (_reservationDetails.isEmpty)
              const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Keine aktiven Reservierungen.')))
            else
              for (final entry in _reservationDetails.entries)
                _ReportCard(title: entry.key, value: MoneyFormatter.format(entry.value), icon: Icons.lock_outline),
            const SizedBox(height: 16),
            _ReportCard(
              title: 'Reisen reserviert im Zeitraum',
              value: MoneyFormatter.format(
                _rangeTravelReservations.fold(0.0, (sum, item) => sum + item.amount),
              ),
              icon: Icons.flight_takeoff,
            ),
            _ReportCard(
              title: 'Sparziele reserviert im Zeitraum',
              value: MoneyFormatter.format(
                _rangeSavingReservations.fold(0.0, (sum, item) => sum + item.amount),
              ),
              icon: Icons.savings_outlined,
            ),
            _ReportCard(
              title: 'Schuldbewegungen',
              value: MoneyFormatter.format(debtMovements),
              icon: Icons.compare_arrows_outlined,
            ),
            const SizedBox(height: 24),
            Text(
              'Lebensmittel-Mengen',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (foodSummaries.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Keine Lebensmittel-Mengen im Zeitraum.'),
                ),
              )
            else
              for (final item in foodSummaries)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.restaurant_outlined),
                    title: Text(item.name),
                    subtitle: Text(item.measurementText),
                    trailing: Text(MoneyFormatter.format(item.totalCost)),
                  ),
                ),
            const SizedBox(height: 24),
            Text(
              'PDF-Auswahl',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: const Text('Ausgewählte Inhalte'),
                subtitle: Text(_selectedOptionsText()),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    IconButton(
                      tooltip: 'PDF direkt erstellen',
                      onPressed: _exportPdf,
                      icon: const Icon(Icons.download_outlined),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: _openExportOptions,
              ),
            ),
            const SizedBox(height: 90),
          ],
        ),
      ),
    );
  }

  String _selectedOptionsText() {
    final parts = <String>[];

    if (_exportOptions.overview) parts.add('Übersicht');
    if (_exportOptions.incomes) parts.add('Einnahmen');
    if (_exportOptions.expenses) parts.add('Ausgaben');
    if (_exportOptions.budgets) parts.add('Budgets');
    if (_exportOptions.debts) parts.add('Schulden');
    if (_exportOptions.travel) parts.add('Reisen');
    if (_exportOptions.savings) parts.add('Sparziele');
    if (_exportOptions.products) parts.add('Produkte');
    if (_exportOptions.foodAmounts) parts.add('Lebensmittel-Mengen');
    if (_exportOptions.transactions) parts.add('Transaktionen');

    return parts.join(', ');
  }
}

class _PeriodSelector extends StatelessWidget {
  final ReportPeriodMode mode;
  final String title;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  const _PeriodSelector({
    required this.mode,
    required this.title,
    required this.onPrevious,
    required this.onNext,
    required this.onPickStart,
    required this.onPickEnd,
  });

  @override
  Widget build(BuildContext context) {
    if (mode == ReportPeriodMode.custom) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onPickStart,
                      icon: const Icon(Icons.date_range),
                      label: const Text('Von'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onPickEnd,
                      icon: const Icon(Icons.date_range),
                      label: const Text('Bis'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Row(
        children: [
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Center(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _ReportCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title),
        trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _FoodAmountSummary {
  final String name;
  final double grams;
  final double ml;
  final double pieces;
  final double unknownPackages;
  final double totalCost;

  const _FoodAmountSummary({
    required this.name,
    this.grams = 0,
    this.ml = 0,
    this.pieces = 0,
    this.unknownPackages = 0,
    this.totalCost = 0,
  });

  _FoodAmountSummary add(ExpenseItemModel item) {
    return _FoodAmountSummary(
      name: name,
      grams: grams + (item.weightGrams ?? 0),
      ml: ml + (item.volumeMl ?? 0),
      pieces: pieces + (item.countUnits ?? 0),
      unknownPackages:
          unknownPackages + (item.hasPreciseMeasurement ? 0 : item.quantity),
      totalCost: totalCost + item.totalPrice,
    );
  }

  String get measurementText {
    final parts = <String>[];

    if (grams > 0) parts.add('${(grams / 1000).toStringAsFixed(2)} kg');
    if (ml > 0) parts.add('${(ml / 1000).toStringAsFixed(2)} L');
    if (pieces > 0) parts.add('${pieces.toStringAsFixed(0)} Stück');
    if (unknownPackages > 0) {
      parts.add('${unknownPackages.toStringAsFixed(0)} Packung/Stück unbekannt');
    }

    return parts.isEmpty ? 'Keine Mengenangabe' : parts.join(' · ');
  }
}

class _ReportOptionsDialog extends StatefulWidget {
  final ReportExportOptions initialOptions;

  const _ReportOptionsDialog({
    required this.initialOptions,
  });

  @override
  State<_ReportOptionsDialog> createState() => _ReportOptionsDialogState();
}

class _ReportOptionsDialogState extends State<_ReportOptionsDialog> {
  late ReportExportOptions _options;

  @override
  void initState() {
    super.initState();
    _options = widget.initialOptions;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('PDF Inhalte auswählen'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _switch('Übersicht', _options.overview,
                (v) => _options = _options.copyWith(overview: v)),
            _switch('Einnahmen', _options.incomes,
                (v) => _options = _options.copyWith(incomes: v)),
            _switch('Ausgaben', _options.expenses,
                (v) => _options = _options.copyWith(expenses: v)),
            _switch('Budgets', _options.budgets,
                (v) => _options = _options.copyWith(budgets: v)),
            _switch('Schulden', _options.debts,
                (v) => _options = _options.copyWith(debts: v)),
            _switch('Reisen', _options.travel,
                (v) => _options = _options.copyWith(travel: v)),
            _switch('Sparziele', _options.savings,
                (v) => _options = _options.copyWith(savings: v)),
            _switch('Produktanalyse', _options.products,
                (v) => _options = _options.copyWith(products: v)),
            _switch('Lebensmittel-Mengen', _options.foodAmounts,
                (v) => _options = _options.copyWith(foodAmounts: v)),
            _switch('Transaktionsliste', _options.transactions,
                (v) => _options = _options.copyWith(transactions: v)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _options),
          child: const Text('Übernehmen'),
        ),
      ],
    );
  }

  Widget _switch(String title, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      value: value,
      title: Text(title),
      onChanged: (newValue) {
        setState(() {
          onChanged(newValue);
        });
      },
    );
  }
}


