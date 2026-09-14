import '../../features/settings/app_settings_mock_data.dart';
import '../../shared/models/app_settings_model.dart';

class AppStrings {
  static AppLanguage get _language => AppSettingsMockData.settings.language;

  static bool get _isGerman => _language == AppLanguage.german;

  static String _text({
    required String en,
    required String de,
  }) {
    return _isGerman ? de : en;
  }

  // Allgemein
  static String get appName => 'Farez Finance';

  static String get save => _text(
        en: 'Save',
        de: 'Speichern',
      );

  static String get cancel => _text(
        en: 'Cancel',
        de: 'Abbrechen',
      );

  static String get edit => _text(
        en: 'Edit',
        de: 'Bearbeiten',
      );

  static String get delete => _text(
        en: 'Delete',
        de: 'Löschen',
      );

  static String get add => _text(
        en: 'Add',
        de: 'Hinzufügen',
      );

  static String get back => _text(
        en: 'Back',
        de: 'Zurück',
      );

  static String get date => _text(
        en: 'Date',
        de: 'Datum',
      );

  static String get title => _text(
        en: 'Title',
        de: 'Titel',
      );

  static String get amount => _text(
        en: 'Amount',
        de: 'Betrag',
      );

  static String get note => _text(
        en: 'Note',
        de: 'Notiz',
      );

  static String get category => _text(
        en: 'Category',
        de: 'Kategorie',
      );

  static String get account => _text(
        en: 'Account',
        de: 'Konto',
      );

  static String get fund => _text(
        en: 'Fund',
        de: 'Spartopf',
      );

  static String get storeName => _text(
        en: 'Store Name',
        de: 'Geschäftsname',
      );

  static String get storeNameHint => _text(
        en: 'Example: Lidl, Hofer, Billa, Spar',
        de: 'Beispiel: Lidl, Hofer, Billa, Spar',
      );

  // Bottom Navigation
  static String get dashboard => _text(
        en: 'Dashboard',
        de: 'Übersicht',
      );

  static String get income => _text(
        en: 'Income',
        de: 'Einnahmen',
      );

  static String get expenses => _text(
        en: 'Expenses',
        de: 'Ausgaben',
      );

  static String get savings => _text(
        en: 'Savings',
        de: 'Sparen',
      );

  static String get more => _text(
        en: 'More',
        de: 'Mehr',
      );

  // Dashboard
  static String get totalMoney => _text(
        en: 'Total Money',
        de: 'Gesamtvermögen',
      );

  static String get accountsBalance => _text(
        en: 'Accounts Balance',
        de: 'Kontostand',
      );

  static String get fundsBalance => _text(
        en: 'Funds Balance',
        de: 'Spartöpfe',
      );

  static String get monthlyResult => _text(
        en: 'Monthly Result',
        de: 'Monatsergebnis',
      );

  static String get realIncome => _text(
        en: 'Real Income',
        de: 'Echte Einnahmen',
      );

  static String get realExpenses => _text(
        en: 'Real Expenses',
        de: 'Echte Ausgaben',
      );

  static String get netResult => _text(
        en: 'Net Result',
        de: 'Netto-Ergebnis',
      );

  static String get internalMovements => _text(
        en: 'Internal Movements',
        de: 'Interne Bewegungen',
      );

  static String get transfersAndSavings => _text(
        en: 'Transfers & Savings',
        de: 'Transfers & Sparen',
      );

  static String get debtMovements => _text(
        en: 'Debt Movements',
        de: 'Schulden & Forderungen',
      );

  static String get moneyLent => _text(
        en: 'Money Lent',
        de: 'Verliehenes Geld',
      );

  static String get moneyReturnedToYou => _text(
        en: 'Money Returned To You',
        de: 'Zurückerhaltenes Geld',
      );

  static String get moneyBorrowed => _text(
        en: 'Money Borrowed',
        de: 'Geliehenes Geld',
      );

  static String get debtPaidBack => _text(
        en: 'Debt Paid Back',
        de: 'Schulden zurückgezahlt',
      );

  // Income
  static String get addIncome => _text(
        en: 'Add Income',
        de: 'Einnahme hinzufügen',
      );

  static String get saveIncome => _text(
        en: 'Save Income',
        de: 'Einnahme speichern',
      );

  static String get incomeCategory => _text(
        en: 'Income Category',
        de: 'Einnahmekategorie',
      );

  static String get destinationAccount => _text(
        en: 'Destination Account',
        de: 'Zielkonto',
      );

  static String get incomeDate => _text(
        en: 'Income Date',
        de: 'Einnahmedatum',
      );

  static String get recurringIncome => _text(
        en: 'Recurring Income',
        de: 'Wiederkehrende Einnahme',
      );

  // Expenses
  static String get addExpense => _text(
        en: 'Add Expense',
        de: 'Ausgabe hinzufügen',
      );

  static String get saveExpense => _text(
        en: 'Save Expense',
        de: 'Ausgabe speichern',
      );

  static String get entryMethod => _text(
        en: 'Entry Method',
        de: 'Eingabemethode',
      );

  static String get manual => _text(
        en: 'Manual',
        de: 'Manuell',
      );

  static String get receiptText => _text(
        en: 'Receipt Text',
        de: 'Kassenzettel-Text',
      );

  static String get photoScanLater => _text(
        en: 'Photo Scan later',
        de: 'Foto-Scan später',
      );

  static String get pdfLater => _text(
        en: 'PDF later',
        de: 'PDF später',
      );

  static String get expenseCategory => _text(
        en: 'Expense Category',
        de: 'Ausgabenkategorie',
      );

  static String get paidFromAccount => _text(
        en: 'Paid From Account',
        de: 'Bezahlt von Konto',
      );

  static String get expenseDate => _text(
        en: 'Expense Date',
        de: 'Ausgabedatum',
      );

  static String get recurringExpense => _text(
        en: 'Recurring Expense',
        de: 'Wiederkehrende Ausgabe',
      );

  static String get useThisLaterForMonthlyExpenses => _text(
        en: 'Use this later for monthly expenses',
        de: 'Später für monatliche Ausgaben verwenden',
      );

  // More Page
  static String get travelPlans => _text(
        en: 'Travel Plans',
        de: 'Reisepläne',
      );

  static String get travelPlansSubtitle => _text(
        en: 'Plan trips and track travel savings.',
        de: 'Reisen planen und Reisegeld verfolgen.',
      );

  static String get productAnalytics => _text(
        en: 'Product Analytics',
        de: 'Produktanalyse',
      );

  static String get productAnalyticsSubtitle => _text(
        en: 'Analyze products from receipts.',
        de: 'Produkte aus Kassenzetteln analysieren.',
      );

  static String get debtsReceivables => _text(
        en: 'Debts & Receivables',
        de: 'Schulden & Forderungen',
      );

  static String get debtsReceivablesSubtitle => _text(
        en: 'Track money you owe and money owed to you.',
        de: 'Schulden und Forderungen verfolgen.',
      );

  static String get reports => _text(
        en: 'Reports',
        de: 'Berichte',
      );

  static String get reportsSubtitle => _text(
        en: 'Monthly and yearly financial reports.',
        de: 'Monatliche und jährliche Finanzberichte.',
      );

  static String get categories => _text(
        en: 'Categories',
        de: 'Kategorien',
      );

  static String get categoriesSubtitle => _text(
        en: 'Manage income, expense and balance categories.',
        de: 'Einnahmen-, Ausgaben- und Kontokategorien verwalten.',
      );

  static String get settings => _text(
        en: 'Settings',
        de: 'Einstellungen',
      );

  static String get settingsSubtitle => _text(
        en: 'Language, currency and app preferences.',
        de: 'Sprache, Währung und App-Einstellungen.',
      );

  // Reports
  static String get monthlyFinancialReport => _text(
        en: 'Monthly Financial Report',
        de: 'Monatlicher Finanzbericht',
      );

  static String get exportPdf => _text(
        en: 'Export PDF',
        de: 'PDF exportieren',
      );

  static String get productAnalyticsSummary => _text(
        en: 'Product Analytics Summary',
        de: 'Zusammenfassung der Produktanalyse',
      );

  static String get trackedProductCosts => _text(
        en: 'Tracked Product Costs',
        de: 'Erfasste Produktkosten',
      );

  static String get monthlyTransactions => _text(
        en: 'Monthly Transactions',
        de: 'Monatliche Transaktionen',
      );

  static String get noProductDataInThisMonth => _text(
        en: 'No product data in this month.',
        de: 'Keine Produktdaten in diesem Monat.',
      );

  static String get noTransactionsInThisMonth => _text(
        en: 'No transactions in this month.',
        de: 'Keine Transaktionen in diesem Monat.',
      );

  static String get products => _text(
        en: 'products',
        de: 'Produkte',
      );

  static String get stores => _text(
        en: 'Stores',
        de: 'Geschäfte',
      );

  static String get store => _text(
        en: 'Store',
        de: 'Geschäft',
      );

  // Transaction Types
  static String get transfer => _text(
        en: 'Transfer',
        de: 'Transfer',
      );

  static String get travelSaving => _text(
        en: 'Travel Saving',
        de: 'Reisesparen',
      );

  static String get travelWithdrawal => _text(
        en: 'Travel Withdrawal',
        de: 'Reiseentnahme',
      );

  static String get moneyReturned => _text(
        en: 'Money Returned',
        de: 'Geld zurückerhalten',
      );

  // Month Names
  static String monthName(int month) {
    switch (month) {
      case 1:
        return _text(en: 'January', de: 'Januar');
      case 2:
        return _text(en: 'February', de: 'Februar');
      case 3:
        return _text(en: 'March', de: 'März');
      case 4:
        return _text(en: 'April', de: 'April');
      case 5:
        return _text(en: 'May', de: 'Mai');
      case 6:
        return _text(en: 'June', de: 'Juni');
      case 7:
        return _text(en: 'July', de: 'Juli');
      case 8:
        return _text(en: 'August', de: 'August');
      case 9:
        return _text(en: 'September', de: 'September');
      case 10:
        return _text(en: 'October', de: 'Oktober');
      case 11:
        return _text(en: 'November', de: 'November');
      case 12:
        return _text(en: 'December', de: 'Dezember');
      default:
        return '';
    }
  }
}