import '../../features/categories/category_mock_data.dart';
import '../../features/categories/category_repository.dart';
import '../../features/savings/account_mock_data.dart';
import '../../features/savings/accounts_repository.dart';
import '../../features/savings/financial_transaction_mock_data.dart';
import '../../features/savings/financial_transactions_repository.dart';
import '../../features/settings/app_settings_mock_data.dart';
import '../../features/settings/settings_repository.dart';

class AppDataLoaderService {
  static final AccountsRepository _accountsRepository = AccountsRepository();
  static final FinancialTransactionsRepository _transactionsRepository =
      FinancialTransactionsRepository();
  static final CategoryRepository _categoryRepository = CategoryRepository();
  static final SettingsRepository _settingsRepository = SettingsRepository();

  static Future<void> loadInitialFinanceData() async {
    final accounts = await _accountsRepository.fetchAccounts();
    final transactions = await _transactionsRepository.fetchTransactions();
    final categories = await _categoryRepository.fetchCategories();
    final settings = await _settingsRepository.fetchOrCreateSettings();

    AccountMockData.accounts
      ..clear()
      ..addAll(accounts);

    FinancialTransactionMockData.transactions
      ..clear()
      ..addAll(transactions);

    CategoryMockData.categories
      ..clear()
      ..addAll(categories);

    AppSettingsMockData.updateSettings(settings);
  }
}
