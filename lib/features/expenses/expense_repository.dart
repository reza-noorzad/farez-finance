import '../../core/supabase/family_context_service.dart';
import '../../core/supabase/supabase_client.dart';
import '../../shared/models/expense_item_model.dart';
import '../../shared/models/expense_model.dart';
import '../../shared/models/financial_transaction_model.dart';
import '../savings/financial_transactions_repository.dart';

class ExpenseDbRecord {
  final ExpenseModel expense;
  final FinancialTransactionModel transaction;

  const ExpenseDbRecord({
    required this.expense,
    required this.transaction,
  });
}

class ExpenseRepository {
  final FinancialTransactionsRepository _transactionsRepository =
      FinancialTransactionsRepository();

  Future<List<ExpenseDbRecord>> fetchExpensesWithTransactions() async {
    final familyId = await FamilyContextService.getCurrentFamilyId();

    final rows = await AppSupabase.client
        .from('expenses')
        .select('*, financial_transactions(*), expense_items(*)')
        .eq('family_id', familyId)
        .order('transaction_date', ascending: false);

    return rows.map<ExpenseDbRecord>((row) {
      final expense = _expenseFromRow(row);
      final transactionRow = row['financial_transactions'];

      final transaction = transactionRow == null
          ? _fallbackTransactionForExpense(expense)
          : _transactionFromRow(transactionRow as Map<String, dynamic>);

      return ExpenseDbRecord(
        expense: expense,
        transaction: transaction,
      );
    }).toList();
  }

  Future<ExpenseDbRecord> createExpenseWithTransaction({
    required ExpenseModel expense,
    required FinancialTransactionModel transaction,
  }) async {
    final familyId = await FamilyContextService.getCurrentFamilyId();
    final userId = AppSupabase.currentUserId;

    if (userId == null) {
      throw Exception('No logged in user.');
    }

    final savedTransaction = await _transactionsRepository.createTransaction(
      transaction.copyWith(
        type: FinancialTransactionType.expense,
        amount: expense.amount,
        transactionDate: expense.transactionDate,
        title: expense.title,
        toAccountId: null,
        categoryId: _validUuidOrNull(expense.categoryId),
        note: expense.note,
      ),
    );

    final expenseRow = await AppSupabase.client
        .from('expenses')
        .insert({
          'family_id': familyId,
          'transaction_id': savedTransaction.id,
          'title': expense.title,
          'category_id': _validUuidOrNull(expense.categoryId),
          'amount': expense.amount,
          'transaction_date': _dateOnly(expense.transactionDate),
          'store_name': expense.storeName,
          'note': expense.note,
          'is_recurring': expense.isRecurring,
          'created_by': userId,
        })
        .select()
        .single();

    final savedExpenseId = expenseRow['id'] as String;

    await _replaceExpenseItems(
      familyId: familyId,
      userId: userId,
      expenseId: savedExpenseId,
      items: expense.items,
    );

    final savedExpense = await _fetchExpenseById(savedExpenseId);

    return ExpenseDbRecord(
      expense: savedExpense,
      transaction: savedTransaction,
    );
  }

  Future<ExpenseDbRecord> updateExpenseWithTransaction({
    required ExpenseModel expense,
    required FinancialTransactionModel transaction,
  }) async {
    final familyId = await FamilyContextService.getCurrentFamilyId();
    final userId = AppSupabase.currentUserId;

    if (userId == null) {
      throw Exception('No logged in user.');
    }

    final updatedTransaction = await _transactionsRepository.updateTransaction(
      transaction.copyWith(
        type: FinancialTransactionType.expense,
        amount: expense.amount,
        transactionDate: expense.transactionDate,
        title: expense.title,
        toAccountId: null,
        categoryId: _validUuidOrNull(expense.categoryId),
        note: expense.note,
      ),
    );

    await AppSupabase.client
        .from('expenses')
        .update({
          'title': expense.title,
          'category_id': _validUuidOrNull(expense.categoryId),
          'amount': expense.amount,
          'transaction_date': _dateOnly(expense.transactionDate),
          'store_name': expense.storeName,
          'note': expense.note,
          'is_recurring': expense.isRecurring,
        })
        .eq('id', expense.id);

    await _replaceExpenseItems(
      familyId: familyId,
      userId: userId,
      expenseId: expense.id,
      items: expense.items,
    );

    final updatedExpense = await _fetchExpenseById(expense.id);

    return ExpenseDbRecord(
      expense: updatedExpense,
      transaction: updatedTransaction,
    );
  }

  Future<void> deleteExpenseWithTransaction({
    required String expenseId,
    required String transactionId,
  }) async {
    await AppSupabase.client.from('expenses').delete().eq('id', expenseId);

    await _transactionsRepository.deleteTransaction(transactionId);
  }

  Future<ExpenseModel> _fetchExpenseById(String expenseId) async {
    final row = await AppSupabase.client
        .from('expenses')
        .select('*, expense_items(*)')
        .eq('id', expenseId)
        .single();

    return _expenseFromRow(row);
  }

  Future<void> _replaceExpenseItems({
    required String familyId,
    required String userId,
    required String expenseId,
    required List<ExpenseItemModel> items,
  }) async {
    await AppSupabase.client
        .from('expense_items')
        .delete()
        .eq('expense_id', expenseId);

    if (items.isEmpty) {
      return;
    }

    final rows = items.map((item) {
      return {
        'family_id': familyId,
        'expense_id': expenseId,
        'name': item.name,
        'original_name': item.originalName,
        'monthly_name': item.monthlyName,
        'category': item.category,
        'quantity': item.quantity,
        'unit': item.unit,
        'total_price': item.totalPrice,
        'item_date': _dateOnly(item.date),
        'store_name': item.storeName,
        'weight_grams': item.weightGrams,
        'volume_ml': item.volumeMl,
        'count_units': item.countUnits,
        'is_measurement_important': item.isMeasurementImportant,
        'needs_review': item.needsReview,
        'review_reason': item.reviewReason,
        'measurement_status': item.measurementStatus,
        'created_by': userId,
      };
    }).toList();

    await AppSupabase.client.from('expense_items').insert(rows);
  }

  ExpenseModel _expenseFromRow(Map<String, dynamic> row) {
    final rawItems = row['expense_items'];
    final items = <ExpenseItemModel>[];

    if (rawItems is List) {
      for (final rawItem in rawItems) {
        if (rawItem is Map<String, dynamic>) {
          items.add(_expenseItemFromRow(rawItem));
        }
      }
    }

    return ExpenseModel(
      id: row['id'] as String,
      title: row['title'] as String? ?? '',
      categoryId: row['category_id'] as String? ?? '',
      amount: _toDouble(row['amount']),
      transactionDate: _toDateTime(row['transaction_date']) ?? DateTime.now(),
      createdAt: _toDateTime(row['created_at']) ?? DateTime.now(),
      storeName: row['store_name'] as String?,
      note: row['note'] as String?,
      isRecurring: row['is_recurring'] as bool? ?? false,
      items: items,
    );
  }

  ExpenseItemModel _expenseItemFromRow(Map<String, dynamic> row) {
    return ExpenseItemModel(
      id: row['id'] as String,
      expenseId: row['expense_id'] as String,
      name: row['name'] as String? ?? 'Produkt',
      originalName: row['original_name'] as String?,
      monthlyName: row['monthly_name'] as String?,
      category: row['category'] as String? ?? 'Sonstiges',
      quantity: _toDouble(row['quantity']),
      unit: row['unit'] as String? ?? 'Stück',
      totalPrice: _toDouble(row['total_price']),
      date: _toDateTime(row['item_date']) ?? DateTime.now(),
      storeName: row['store_name'] as String?,
      weightGrams: _toNullableDouble(row['weight_grams']),
      volumeMl: _toNullableDouble(row['volume_ml']),
      countUnits: _toNullableDouble(row['count_units']),
      isMeasurementImportant: row['is_measurement_important'] as bool? ?? false,
      needsReview: row['needs_review'] as bool? ?? false,
      reviewReason: row['review_reason'] as String?,
      measurementStatus: row['measurement_status'] as String? ?? 'unknown',
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

  FinancialTransactionModel _fallbackTransactionForExpense(
    ExpenseModel expense,
  ) {
    final now = DateTime.now();

    return FinancialTransactionModel(
      id: '',
      type: FinancialTransactionType.expense,
      amount: expense.amount,
      transactionDate: expense.transactionDate,
      createdAt: now,
      title: expense.title,
      categoryId: _validUuidOrNull(expense.categoryId),
      note: expense.note,
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
        return FinancialTransactionType.expense;
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


  double? _toNullableDouble(dynamic value) {
    if (value == null) return null;

    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value.replaceAll(',', '.'));
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
