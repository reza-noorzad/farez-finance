import 'package:flutter/material.dart';

import '../../core/formatters/money_formatter.dart';
import '../../core/localization/app_strings.dart';
import '../../shared/models/expense_item_model.dart';
import '../../shared/widgets/simple_finance_charts.dart';
import '../expenses/expense_repository.dart';
import 'product_mock_data.dart';

class ProductAnalyticsPage extends StatefulWidget {
  const ProductAnalyticsPage({super.key});

  @override
  State<ProductAnalyticsPage> createState() => _ProductAnalyticsPageState();
}

class _ProductAnalyticsPageState extends State<ProductAnalyticsPage> {
  final ExpenseRepository _expenseRepository = ExpenseRepository();

  DateTime _selectedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProductItems();
  }

  Future<void> _loadProductItems() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final records = await _expenseRepository.fetchExpensesWithTransactions();
      final items = <ExpenseItemModel>[];

      for (final record in records) {
        items.addAll(record.expense.items);
      }

      ProductMockData.items
        ..clear()
        ..addAll(items);

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Fehler beim Laden der Produktdaten: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    await _loadProductItems();
  }

  List<ExpenseItemModel> get _monthlyItems {
    return ProductMockData.items.where((item) {
      return item.date.year == _selectedMonth.year &&
          item.date.month == _selectedMonth.month;
    }).toList();
  }

  List<ExpenseItemModel> get _itemsNeedingReview {
    return _monthlyItems.where((item) => item.needsReview).toList();
  }

  String _monthTitle() {
    return '${AppStrings.monthName(_selectedMonth.month)} ${_selectedMonth.year}';
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month - 1,
      );
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + 1,
      );
    });
  }

  double get _totalCost {
    return _monthlyItems.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  Map<String, _ProductSummary> _buildProductSummaries() {
    final result = <String, _ProductSummary>{};

    for (final item in _monthlyItems) {
      final key = item.reportName.toLowerCase().trim();

      final current = result[key] ??
          _ProductSummary(
            name: item.reportName,
            category: item.category,
          );

      result[key] = current.add(item);
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(AppStrings.productAnalytics)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: Text(AppStrings.productAnalytics)),
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

    final summaries = _buildProductSummaries().values.toList()
      ..sort((a, b) => b.totalCost.compareTo(a.totalCost));

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.productAnalytics),
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
            FinanceBarChartCard(
              title: 'Top Produkte nach Kosten',
              valuePrefix: '€',
              data: summaries.take(6).map((item) {
                return FinanceBarDatum(
                  label: item.name.length > 8 ? item.name.substring(0, 8) : item.name,
                  value: item.totalCost,
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            Card(
              child: Row(
                children: [
                  IconButton(
                    onPressed: _previousMonth,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        _monthTitle(),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _nextMonth,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
_OverviewCard(
              title: 'Produkte gesamt',
              value: _monthlyItems.length.toString(),
              icon: Icons.shopping_basket_outlined,
            ),
            const SizedBox(height: 12),
            _OverviewCard(
              title: 'Kosten gesamt',
              value: MoneyFormatter.format(_totalCost),
              icon: Icons.payments_outlined,
            ),
            const SizedBox(height: 12),
            _OverviewCard(
              title: 'Menge unbekannt',
              value: _itemsNeedingReview.length.toString(),
              icon: Icons.rule_outlined,
            ),
            if (_itemsNeedingReview.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Produkte mit unbekannter Menge',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              for (final item in _itemsNeedingReview.take(8))
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.warning_amber_outlined),
                    title: Text(item.originalName ?? item.name),
                    subtitle: Text(
                      '${item.quantity.toStringAsFixed(0)} ${item.unit} · ${item.category}\n'
                      '${item.reviewReason ?? 'Menge unbekannt'}',
                    ),
                    isThreeLine: true,
                    trailing: Text(MoneyFormatter.format(item.totalPrice)),
                  ),
                ),
            ],
            const SizedBox(height: 24),
            Text(
              'Verbrauch nach Produkt',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (summaries.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Keine Produktdaten in diesem Monat.'),
                ),
              )
            else
              for (final summary in summaries)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.inventory_2_outlined),
                    title: Text(summary.name),
                    subtitle: Text(
                      '${summary.category}\n${summary.measurementText}',
                    ),
                    isThreeLine: true,
                    trailing: Text(
                      MoneyFormatter.format(summary.totalCost),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            const SizedBox(height: 90),
          ],
        ),
      ),
    );
  }
}

class _ProductSummary {
  final String name;
  final String category;
  final double totalCost;
  final double grams;
  final double ml;
  final double pieces;
  final double unknownPackages;

  const _ProductSummary({
    required this.name,
    required this.category,
    this.totalCost = 0,
    this.grams = 0,
    this.ml = 0,
    this.pieces = 0,
    this.unknownPackages = 0,
  });

  _ProductSummary add(ExpenseItemModel item) {
    return _ProductSummary(
      name: name,
      category: category,
      totalCost: totalCost + item.totalPrice,
      grams: grams + (item.weightGrams ?? 0),
      ml: ml + (item.volumeMl ?? 0),
      pieces: pieces + (item.countUnits ?? 0),
      unknownPackages:
          unknownPackages + (item.needsReview || !item.hasPreciseMeasurement ? item.quantity : 0),
    );
  }

  String get measurementText {
    final parts = <String>[];

    if (grams > 0) {
      parts.add('${(grams / 1000).toStringAsFixed(2)} kg');
    }

    if (ml > 0) {
      parts.add('${(ml / 1000).toStringAsFixed(2)} L');
    }

    if (pieces > 0) {
      parts.add('${pieces.toStringAsFixed(0)} Stück');
    }

    if (unknownPackages > 0) {
      parts.add('${unknownPackages.toStringAsFixed(0)} Packung/Stück unbekannt');
    }

    if (parts.isEmpty) {
      return 'Keine Mengenangabe';
    }

    return parts.join(' · ');
  }
}

class _OverviewCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _OverviewCard({
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
        trailing: Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
