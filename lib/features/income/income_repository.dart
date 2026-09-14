import '../../core/supabase/family_context_service.dart';
import '../../core/supabase/supabase_client.dart';
import '../../shared/models/financial_transaction_model.dart';
import '../../shared/models/income_model.dart';
import '../savings/financial_transactions_repository.dart';

class IncomeDbRecord {
  final IncomeModel income;
  final FinancialTransactionModel transaction;

  const IncomeDbRecord({
    required this.income,
    required this.transaction,
  });
}

class IncomeRepository {
  final FinancialTransactionsRepository _transactionsRepository =
      FinancialTransactionsRepository();

  Future<List<IncomeDbRecord>> fetchIncomesWithTransactions() async {
    final familyId = await FamilyContextService.getCurrentFamilyId();

    final rows = await AppSupabase.client
        .from('incomes')
        .select('*, financial_transactions(*)')
        .eq('family_id', familyId)
        .order('transaction_date', ascending: false);

    return rows.map<IncomeDbRecord>((row) {
      final income = _incomeFromRow(row);
      final transactionRow = row['financial_transactions'];

      final transaction = transactionRow == null
          ? _fallbackTransactionForIncome(income)
          : _transactionFromRow(transactionRow as Map<String, dynamic>);

      return IncomeDbRecord(
        income: income,
        transaction: transaction,
      );
    }).toList();
  }

  Future<IncomeDbRecord> createIncomeWithTransaction({
    required IncomeModel income,
    required FinancialTransactionModel transaction,
  }) async {
    final familyId = await FamilyContextService.getCurrentFamilyId();
    final userId = AppSupabase.currentUserId;

    if (userId == null) {
      throw Exception('No logged in user.');
    }

    final savedTransaction = await _transactionsRepository.createTransaction(
      transaction.copyWith(
        type: FinancialTransactionType.income,
        amount: income.amount,
        transactionDate: income.transactionDate,
        title: income.title,
        fromAccountId: null,
        categoryId: _validUuidOrNull(income.categoryId),
        note: income.note,
      ),
    );

    final row = await AppSupabase.client
        .from('incomes')
        .insert({
          'family_id': familyId,
          'transaction_id': savedTransaction.id,
          'title': income.title,
          'category_id': _validUuidOrNull(income.categoryId),
          'amount': income.amount,
          'transaction_date': _dateOnly(income.transactionDate),
          'note': income.note,
          'is_recurring': income.isRecurring,
          'created_by': userId,
        })
        .select()
        .single();

    return IncomeDbRecord(
      income: _incomeFromRow(row),
      transaction: savedTransaction,
    );
  }

  Future<IncomeDbRecord> updateIncomeWithTransaction({
    required IncomeModel income,
    required FinancialTransactionModel transaction,
  }) async {
    final updatedTransaction = await _transactionsRepository.updateTransaction(
      transaction.copyWith(
        type: FinancialTransactionType.income,
        amount: income.amount,
        transactionDate: income.transactionDate,
        title: income.title,
        fromAccountId: null,
        categoryId: _validUuidOrNull(income.categoryId),
        note: income.note,
      ),
    );

    final row = await AppSupabase.client
        .from('incomes')
        .update({
          'title': income.title,
          'category_id': _validUuidOrNull(income.categoryId),
          'amount': income.amount,
          'transaction_date': _dateOnly(income.transactionDate),
          'note': income.note,
          'is_recurring': income.isRecurring,
        })
        .eq('id', income.id)
        .select()
        .single();

    return IncomeDbRecord(
      income: _incomeFromRow(row),
      transaction: updatedTransaction,
    );
  }

  Future<void> deleteIncomeWithTransaction({
    required String incomeId,
    required String transactionId,
  }) async {
    await AppSupabase.client.from('incomes').delete().eq('id', incomeId);

    await _transactionsRepository.deleteTransaction(transactionId);
  }

  IncomeModel _incomeFromRow(Map<String, dynamic> row) {
    return IncomeModel(
      id: row['id'] as String,
      title: row['title'] as String? ?? '',
      categoryId: row['category_id'] as String? ?? '',
      amount: _toDouble(row['amount']),
      transactionDate: _toDateTime(row['transaction_date']) ?? DateTime.now(),
      createdAt: _toDateTime(row['created_at']) ?? DateTime.now(),
      note: row['note'] as String?,
      isRecurring: row['is_recurring'] as bool? ?? false,
    );
  }

  FinancialTransactionModel _transactionFromRow(Map<String, dynamic> row) {
    return FinancialTransactionModel(
      id: row['id'] as String,
      type: _transactionTypeFromString(row['type'] as String?),
      amount: _toDouble(row['amount']),
      transactionDate: _toDateTime(row['transaction_date']) ?? DateTime.now(),
      createdAt: _toDateTime(row['created_at']) ?? DateTime.now(),
      title: row['title'] as String? ?? '',
      fromAccountId: row['from_account_id'] as String?,
      toAccountId: row['to_account_id'] as String?,
      categoryId: row['category_id'] as String?,
      travelPlanId: row['travel_plan_id'] as String?,
      debtId: row['debt_id'] as String?,
      note: row['note'] as String?,
      affectsBalance: row['affects_balance'] as bool? ?? true,
    );
  }

  FinancialTransactionModel _fallbackTransactionForIncome(IncomeModel income) {
    final now = DateTime.now();

    return FinancialTransactionModel(
      id: '',
      type: FinancialTransactionType.income,
      amount: income.amount,
      transactionDate: income.transactionDate,
      createdAt: now,
      title: income.title,
      categoryId: _validUuidOrNull(income.categoryId),
      note: income.note,
    );
  }

  FinancialTransactionType _transactionTypeFromString(String? value) {
    switch (value) {
      case 'income':
        return FinancialTransactionType.income;
      case 'expense':
        return FinancialTransactionType.expense;
      case 'transfer':
        return FinancialTransactionType.transfer;
      case 'debtGiven':
        return FinancialTransactionType.debtGiven;
      case 'debtReturned':
        return FinancialTransactionType.debtReturned;
      case 'debtBorrowed':
        return FinancialTransactionType.debtBorrowed;
      case 'debtPaidBack':
        return FinancialTransactionType.debtPaidBack;
      case 'travelSaving':
        return FinancialTransactionType.travelSaving;
      case 'travelWithdrawal':
        return FinancialTransactionType.travelWithdrawal;
      default:
        return FinancialTransactionType.income;
    }
  }

  String _dateOnly(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;

    if (value is DateTime) {
      return value;
    }

    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;

    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }

    return 0.0;
  }

  String? _validUuidOrNull(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );

    if (!uuidRegex.hasMatch(value)) {
      return null;
    }

    return value;
  }
}
