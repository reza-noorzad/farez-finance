import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../shared/models/account_model.dart';
import '../../shared/models/expense_item_model.dart';
import '../../shared/models/financial_transaction_model.dart';
import '../../shared/models/debt_model.dart';
import '../../shared/models/debt_payment_model.dart';

class ReportPdfGenerator {
  static Future<Uint8List> generateFullReport({
    required String reportTitle,
    required DateTime generatedAt,
    required double totalMoney,
    required double freeAvailable,
    required double reservedTotal,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required double travelReservedTotal,
    required double savingReservedTotal,
    required double realIncome,
    required double realExpenses,
    required double netResult,
    required double transfersAndSavings,
    required double moneyLent,
    required double moneyReturned,
    required double moneyBorrowed,
    required double debtPaidBack,
    required double openingReceivables,
    required double openingLiabilities,
    required double openReceivables,
    required double openLiabilities,
    required List<DebtModel> debts,
    required List<DebtPaymentModel> debtPayments,
    required List<AccountModel> accounts,
    required Map<String, double> accountBalances,
    required Map<String, double> accountPeriodStartBalances,
    required Map<String, double> accountPeriodEndBalances,
    required List<ExpenseItemModel> productItems,
    required List<FinancialTransactionModel> transactions,
    required Map<String, double> paymentSourceTotals,
    required Map<String, double> reservationDetails,
    required bool includeOverview,
    required bool includeAccounts,
    required bool includeIncomes,
    required bool includeExpenses,
    required bool includeDebts,
    required bool includeTravel,
    required bool includeSavings,
    required bool includeProducts,
    required bool includeFoodAmounts,
    required bool includeTransactions,
  }) async {
    final document = pw.Document();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) {
          final widgets = <pw.Widget>[
            _header(reportTitle, generatedAt),
            pw.SizedBox(height: 18),
          ];

          if (includeOverview) {
            widgets.addAll([
              _section('Übersicht'),
              _keyValue('Gesamtvermögen', _money(totalMoney)),
              _keyValue('Frei verfügbar', _money(freeAvailable)),
              _keyValue('Reserviert gesamt', _money(reservedTotal)),
              pw.SizedBox(height: 14),
            ]);
          }

          if (includeAccounts) {
            widgets.addAll([
              _section('Konten im Zeitraum'),
              pw.Text(
                'Zeitraum: ${_date(rangeStart)} bis ${_date(rangeEnd)}. Diese Tabelle zeigt Monats-/Zeitraumwerte, nicht nur den heutigen Kontostand.',
                style: const pw.TextStyle(fontSize: 9),
              ),
              pw.SizedBox(height: 6),
              _accountsPeriodTable(
                accounts,
                accountPeriodStartBalances,
                accountPeriodEndBalances,
              ),
              pw.SizedBox(height: 14),
            ]);
          }

          if (includeIncomes || includeExpenses) {
            widgets.addAll([
              _section('Einnahmen / Ausgaben'),
              if (includeIncomes) _keyValue('Echte Einnahmen', _money(realIncome)),
              if (includeExpenses) _keyValue('Echte Ausgaben', _money(realExpenses)),
              _keyValue('Netto Ergebnis', _money(netResult)),
              _keyValue('Transfers & interne Bewegungen', _money(transfersAndSavings)),
              pw.SizedBox(height: 14),
            ]);
          }

          if (includeExpenses && paymentSourceTotals.isNotEmpty) {
            final totalPaid = paymentSourceTotals.values.fold(0.0, (a, b) => a + b);
            widgets.addAll([
              _section('Konten & Zahlungsarten'),
              for (final entry in paymentSourceTotals.entries)
                _keyValue(
                  entry.key,
                  '${_money(entry.value)}${totalPaid > 0 ? ' (${(entry.value / totalPaid * 100).toStringAsFixed(1)}%)' : ''}',
                ),
              pw.SizedBox(height: 14),
            ]);
          }

          if (includeTravel || includeSavings) {
            widgets.addAll([
              _section('Reservierungen'),
              if (reservationDetails.isEmpty) ...[
                if (includeTravel) _keyValue('Reisen reserviert', _money(travelReservedTotal)),
                if (includeSavings) _keyValue('Sparziele reserviert', _money(savingReservedTotal)),
              ] else
                for (final entry in reservationDetails.entries)
                  _keyValue(entry.key, _money(entry.value)),
              pw.SizedBox(height: 14),
            ]);
          }

          if (includeDebts) {
            widgets.addAll([
              _section('Schulden & Forderungen'),
              _keyValue('Forderungen Anfangsbestand', _money(openingReceivables)),
              _keyValue('Verbindlichkeiten Anfangsbestand', _money(openingLiabilities)),
              _keyValue('Offene Forderungen aktuell', _money(openReceivables)),
              _keyValue('Offene Verbindlichkeiten aktuell', _money(openLiabilities)),
              pw.SizedBox(height: 8),
              _keyValue('Verliehenes Geld im Zeitraum', _money(moneyLent)),
              _keyValue('Zurückerhaltenes Geld', _money(moneyReturned)),
              _keyValue('Geliehenes Geld', _money(moneyBorrowed)),
              _keyValue('Schulden zurückgezahlt', _money(debtPaidBack)),
              if (debts.isNotEmpty) ...[
                pw.SizedBox(height: 8),
                _debtsTable(debts, debtPayments),
              ],
              pw.SizedBox(height: 14),
            ]);
          }

          if (includeProducts) {
            widgets.addAll([
              _section('Produktanalyse'),
              if (productItems.isEmpty)
                pw.Text('Keine Produktdaten im Zeitraum.')
              else
                _productCostTable(productItems),
              pw.SizedBox(height: 14),
            ]);
          }

          if (includeFoodAmounts) {
            widgets.addAll([
              _section('Mengen & Gewicht unbekannt'),
              if (productItems.where((item) => item.isMeasurementImportant).isEmpty)
                pw.Text('Keine wichtigen Mengen im Zeitraum.')
              else
                _foodAmountTable(productItems),
              pw.SizedBox(height: 14),
            ]);
          }

          if (includeTransactions) {
            widgets.addAll([
              _section('Transaktionsliste'),
              if (transactions.isEmpty)
                pw.Text('Keine Transaktionen im Zeitraum.')
              else
                _transactionsTable(transactions),
            ]);
          }

          return widgets;
        },
      ),
    );

    return document.save();
  }

  static pw.Widget _header(String reportTitle, DateTime generatedAt) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Farez Finance',
          style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text('Finanzbericht: $reportTitle'),
        pw.Text('Erstellt am: ${_date(generatedAt)}'),
      ],
    );
  }

  static pw.Widget _section(String title) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      margin: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
      child: pw.Text(
        title,
        style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  static pw.Widget _keyValue(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [pw.Text(label), pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))],
      ),
    );
  }

  static pw.Widget _accountsTable(
    List<AccountModel> accounts,
    Map<String, double> accountBalances,
  ) {
    return pw.TableHelper.fromTextArray(
      headers: ['Konto', 'Anfangsbestand', 'Bewegungen', 'Aktueller Stand'],
      data: accounts.map((account) {
        final current = accountBalances[account.id] ?? account.balance;
        final movement = current - account.balance;
        return [
          account.name,
          _money(account.balance),
          _moneyWithSign(movement),
          _money(current),
        ];
      }).toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignment: pw.Alignment.centerLeft,
    );
  }

  static pw.Widget _accountsPeriodTable(
    List<AccountModel> accounts,
    Map<String, double> periodStartBalances,
    Map<String, double> periodEndBalances,
  ) {
    return pw.TableHelper.fromTextArray(
      headers: ['Konto', 'Stand am Anfang', 'Bewegungen im Zeitraum', 'Stand am Ende'],
      data: accounts.map((account) {
        final start = periodStartBalances[account.id] ?? account.balance;
        final end = periodEndBalances[account.id] ?? start;
        final movement = end - start;
        return [
          account.name,
          _money(start),
          _moneyWithSign(movement),
          _money(end),
        ];
      }).toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignment: pw.Alignment.centerLeft,
    );
  }


  static pw.Widget _debtsTable(
    List<DebtModel> debts,
    List<DebtPaymentModel> payments,
  ) {
    final rows = debts.where((debt) => debt.isActive).take(20).map((debt) {
      return [
        debt.kind == DebtKind.moneyLent ? 'Forderung' : 'Verbindlichkeit',
        debt.isOpeningBalance ? 'Altbestand' : 'Neu',
        debt.personName,
        _money(debt.originalAmount),
        _money(debt.remainingAmountFrom(payments)),
      ];
    }).toList();

    if (rows.isEmpty) {
      return pw.Text('Keine offenen Schulden oder Forderungen.');
    }

    return pw.TableHelper.fromTextArray(
      headers: ['Typ', 'Quelle', 'Person', 'Ursprünglich', 'Offen'],
      data: rows,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 9),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellAlignment: pw.Alignment.centerLeft,
    );
  }

  static pw.Widget _productCostTable(List<ExpenseItemModel> items) {
    final grouped = <String, _ProductPdfSummary>{};

    for (final item in items) {
      final key = item.reportName.toLowerCase().trim();
      grouped[key] = (grouped[key] ?? _ProductPdfSummary(item.reportName, item.category)).add(item);
    }

    final summaries = grouped.values.toList()
      ..sort((a, b) => b.totalCost.compareTo(a.totalCost));

    return pw.TableHelper.fromTextArray(
      headers: ['Produkt', 'Kategorie', 'Menge', 'Kosten'],
      data: summaries.take(40).map((item) {
        return [item.name, item.category, item.measurementText, _money(item.totalCost)];
      }).toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellAlignment: pw.Alignment.centerLeft,
    );
  }

  static pw.Widget _foodAmountTable(List<ExpenseItemModel> items) {
    final important = items.where((item) => item.isMeasurementImportant).toList();
    final grouped = <String, _ProductPdfSummary>{};

    for (final item in important) {
      final key = item.reportName.toLowerCase();
      grouped[key] = (grouped[key] ?? _ProductPdfSummary(item.reportName, item.category)).add(item);
    }

    final summaries = grouped.values.toList()..sort((a, b) => a.name.compareTo(b.name));

    return pw.TableHelper.fromTextArray(
      headers: ['Produkt', 'Menge', 'Gewicht unbekannt', 'Kosten'],
      data: summaries.map((item) {
        return [item.name, item.measurementText, item.unknownText, _money(item.totalCost)];
      }).toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellAlignment: pw.Alignment.centerLeft,
    );
  }

  static pw.Widget _transactionsTable(List<FinancialTransactionModel> transactions) {
    final sorted = List<FinancialTransactionModel>.from(transactions)
      ..sort((a, b) => a.transactionDate.compareTo(b.transactionDate));

    return pw.TableHelper.fromTextArray(
      headers: ['Datum', 'Titel', 'Typ', 'Betrag'],
      data: sorted.map((transaction) {
        return [
          _date(transaction.transactionDate),
          transaction.title,
          _transactionTypeLabel(transaction.type),
          _money(transaction.amount),
        ];
      }).toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellAlignment: pw.Alignment.centerLeft,
      columnWidths: {
        0: const pw.FixedColumnWidth(60),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(1.2),
        3: const pw.FixedColumnWidth(70),
      },
    );
  }

  static String _money(double value) => 'EUR ${value.toStringAsFixed(2)}';

  static String _moneyWithSign(double value) {
    final prefix = value > 0 ? '+' : '';
    return '$prefix${_money(value)}';
  }

  static String _date(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }

  static String _transactionTypeLabel(FinancialTransactionType type) {
    switch (type) {
      case FinancialTransactionType.income:
        return 'Einnahme';
      case FinancialTransactionType.expense:
        return 'Ausgabe';
      case FinancialTransactionType.transfer:
        return 'Transfer';
      case FinancialTransactionType.debtGiven:
        return 'Geld verliehen';
      case FinancialTransactionType.debtReturned:
        return 'Rückzahlung erhalten';
      case FinancialTransactionType.debtBorrowed:
        return 'Geld geliehen';
      case FinancialTransactionType.debtPaidBack:
        return 'Schuld zurückgezahlt';
      case FinancialTransactionType.travelSaving:
        return 'Reise sparen';
      case FinancialTransactionType.travelWithdrawal:
        return 'Reise Entnahme';
    }
  }
}

class _ProductPdfSummary {
  final String name;
  final String category;
  final double totalCost;
  final double grams;
  final double ml;
  final double pieces;
  final double unknownPackages;

  const _ProductPdfSummary(
    this.name,
    this.category, {
    this.totalCost = 0,
    this.grams = 0,
    this.ml = 0,
    this.pieces = 0,
    this.unknownPackages = 0,
  });

  _ProductPdfSummary add(ExpenseItemModel item) {
    return _ProductPdfSummary(
      name,
      category,
      totalCost: totalCost + item.totalPrice,
      grams: grams + (item.weightGrams ?? 0),
      ml: ml + (item.volumeMl ?? 0),
      pieces: pieces + (item.countUnits ?? 0),
      unknownPackages: unknownPackages + (item.hasPreciseMeasurement ? 0 : item.quantity),
    );
  }

  String get measurementText {
    final parts = <String>[];
    if (grams > 0) parts.add('${(grams / 1000).toStringAsFixed(2)} kg');
    if (ml > 0) parts.add('${(ml / 1000).toStringAsFixed(2)} L');
    if (pieces > 0) parts.add('${pieces.toStringAsFixed(0)} Stück');
    if (unknownPackages > 0) parts.add('${unknownPackages.toStringAsFixed(0)} Packung/Stück unbekannt');
    return parts.isEmpty ? 'Keine Mengenangabe' : parts.join(' · ');
  }

  String get unknownText {
    if (unknownPackages <= 0) return '-';
    return '${unknownPackages.toStringAsFixed(0)} Packung/Stück';
  }
}
