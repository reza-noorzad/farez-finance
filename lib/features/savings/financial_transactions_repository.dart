import '../../core/supabase/family_context_service.dart';
import '../../core/supabase/supabase_client.dart';
import '../../shared/models/financial_transaction_model.dart';

class FinancialTransactionsRepository {
  Future<List<FinancialTransactionModel>> fetchTransactions() async {
    final familyId = await FamilyContextService.getCurrentFamilyId();

    final response = await AppSupabase.client
        .from('financial_transactions')
        .select()
        .eq('family_id', familyId)
        .order('transaction_date', ascending: false)
        .order('created_at', ascending: false);

    return response
        .map<FinancialTransactionModel>((row) => _transactionFromRow(row))
        .toList();
  }

  Future<FinancialTransactionModel> createTransaction(
    FinancialTransactionModel transaction,
  ) async {
    final familyId = await FamilyContextService.getCurrentFamilyId();
    final userId = AppSupabase.currentUserId;

    if (userId == null) {
      throw Exception('No logged in user.');
    }

    final row = await AppSupabase.client
        .from('financial_transactions')
        .insert({
          'family_id': familyId,
          'type': transaction.type.name,
          'amount': transaction.amount,
          'transaction_date': _dateOnly(transaction.transactionDate),
          'title': transaction.title,
          'from_account_id': _validUuidOrNull(transaction.fromAccountId),
          'to_account_id': _validUuidOrNull(transaction.toAccountId),
          'category_id': _validUuidOrNull(transaction.categoryId),
          'travel_plan_id': _validUuidOrNull(transaction.travelPlanId),
          'debt_id': _validUuidOrNull(transaction.debtId),
          'note': transaction.note,
          'affects_balance': transaction.affectsBalance,
          'created_by': userId,
        })
        .select()
        .single();

    return _transactionFromRow(row);
  }

  Future<FinancialTransactionModel> updateTransaction(
    FinancialTransactionModel transaction,
  ) async {
    final row = await AppSupabase.client
        .from('financial_transactions')
        .update({
          'type': transaction.type.name,
          'amount': transaction.amount,
          'transaction_date': _dateOnly(transaction.transactionDate),
          'title': transaction.title,
          'from_account_id': _validUuidOrNull(transaction.fromAccountId),
          'to_account_id': _validUuidOrNull(transaction.toAccountId),
          'category_id': _validUuidOrNull(transaction.categoryId),
          'travel_plan_id': _validUuidOrNull(transaction.travelPlanId),
          'debt_id': _validUuidOrNull(transaction.debtId),
          'note': transaction.note,
          'affects_balance': transaction.affectsBalance,
        })
        .eq('id', transaction.id)
        .select()
        .single();

    return _transactionFromRow(row);
  }

  Future<void> deleteTransaction(String transactionId) async {
    await AppSupabase.client
        .from('financial_transactions')
        .delete()
        .eq('id', transactionId);
  }

  Future<void> deleteTransactionsByAccountId(String accountId) async {
    await AppSupabase.client
        .from('financial_transactions')
        .delete()
        .or('from_account_id.eq.$accountId,to_account_id.eq.$accountId');
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
        return FinancialTransactionType.transfer;
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
