import '../../core/supabase/family_context_service.dart';
import '../../core/supabase/supabase_client.dart';
import '../../shared/models/debt_model.dart';
import '../../shared/models/debt_payment_model.dart';
import '../../shared/models/financial_transaction_model.dart';
import '../savings/financial_transactions_repository.dart';

class DebtDbData {
  final List<DebtModel> debts;
  final List<DebtPaymentModel> payments;
  final Map<String, FinancialTransactionModel> mainTransactionByDebtId;
  final Map<String, FinancialTransactionModel> paymentTransactionByPaymentId;

  const DebtDbData({
    required this.debts,
    required this.payments,
    required this.mainTransactionByDebtId,
    required this.paymentTransactionByPaymentId,
  });
}

class DebtRepository {
  final FinancialTransactionsRepository _transactionsRepository =
      FinancialTransactionsRepository();

  Future<DebtDbData> fetchDebtData() async {
    final familyId = await FamilyContextService.getCurrentFamilyId();

    final debtRows = await AppSupabase.client
        .from('debts')
        .select()
        .eq('family_id', familyId)
        .order('debt_date', ascending: false)
        .order('created_at', ascending: false);

    final paymentRows = await AppSupabase.client
        .from('debt_payments')
        .select()
        .eq('family_id', familyId)
        .order('payment_date', ascending: false)
        .order('created_at', ascending: false);

    final transactionRows = await AppSupabase.client
        .from('financial_transactions')
        .select()
        .eq('family_id', familyId);

    final debts = debtRows.map<DebtModel>((row) {
      return _debtFromRow(row);
    }).toList();

    final payments = paymentRows.map<DebtPaymentModel>((row) {
      return _paymentFromRow(row);
    }).toList();

    final transactionsById = <String, FinancialTransactionModel>{};

    for (final row in transactionRows) {
      final transaction = _transactionFromRow(row);
      transactionsById[transaction.id] = transaction;
    }

    final mainTransactionByDebtId = <String, FinancialTransactionModel>{};

    for (final row in debtRows) {
      final debtId = row['id'] as String;
      final transactionId = row['transaction_id'] as String?;

      if (transactionId != null && transactionsById[transactionId] != null) {
        mainTransactionByDebtId[debtId] = transactionsById[transactionId]!;
      }
    }

    final paymentTransactionByPaymentId =
        <String, FinancialTransactionModel>{};

    for (final row in paymentRows) {
      final paymentId = row['id'] as String;
      final transactionId = row['transaction_id'] as String?;

      if (transactionId != null && transactionsById[transactionId] != null) {
        paymentTransactionByPaymentId[paymentId] =
            transactionsById[transactionId]!;
      }
    }

    return DebtDbData(
      debts: debts,
      payments: payments,
      mainTransactionByDebtId: mainTransactionByDebtId,
      paymentTransactionByPaymentId: paymentTransactionByPaymentId,
    );
  }


  Future<void> createOpeningDebt(DebtModel debt) async {
    final familyId = await FamilyContextService.getCurrentFamilyId();
    final userId = AppSupabase.currentUserId;

    if (userId == null) {
      throw Exception('No logged in user.');
    }

    await AppSupabase.client.from('debts').insert({
      'family_id': familyId,
      'person_name': debt.personName,
      'kind': debt.kind.name,
      'original_amount': debt.originalAmount,
      'debt_date': _dateOnly(debt.debtDate),
      'due_date': _dateOnlyOrNull(debt.dueDate),
      'account_id': _validUuidOrNull(debt.accountId),
      'note': debt.note,
      'is_active': true,
      'is_opening_balance': true,
      'created_by': userId,
    });
  }

  Future<void> updateOpeningDebt(DebtModel debt) async {
    await AppSupabase.client
        .from('debts')
        .update({
          'person_name': debt.personName,
          'kind': debt.kind.name,
          'original_amount': debt.originalAmount,
          'debt_date': _dateOnly(debt.debtDate),
          'due_date': _dateOnlyOrNull(debt.dueDate),
          'account_id': null,
          'note': debt.note,
          'is_active': true,
          'is_opening_balance': true,
        })
        .eq('id', debt.id);
  }

  Future<void> deleteOpeningDebt(String debtId) async {
    await deleteDebtWithTransactions(debtId);
  }

  Future<void> createDebtWithTransaction({
    required DebtModel debt,
    required FinancialTransactionModel transaction,
  }) async {
    final familyId = await FamilyContextService.getCurrentFamilyId();
    final userId = AppSupabase.currentUserId;

    if (userId == null) {
      throw Exception('No logged in user.');
    }

    final debtRow = await AppSupabase.client
        .from('debts')
        .insert({
          'family_id': familyId,
          'person_name': debt.personName,
          'kind': debt.kind.name,
          'original_amount': debt.originalAmount,
          'debt_date': _dateOnly(debt.debtDate),
          'due_date': _dateOnlyOrNull(debt.dueDate),
          'account_id': _validUuidOrNull(debt.accountId),
          'note': debt.note,
          'is_active': debt.isActive,
          'is_opening_balance': debt.isOpeningBalance,
          'created_by': userId,
        })
        .select()
        .single();

    final savedDebt = _debtFromRow(debtRow);

    final savedTransaction = await _transactionsRepository.createTransaction(
      transaction.copyWith(
        type: savedDebt.kind == DebtKind.moneyLent
            ? FinancialTransactionType.debtGiven
            : FinancialTransactionType.debtBorrowed,
        amount: savedDebt.originalAmount,
        transactionDate: savedDebt.debtDate,
        title: savedDebt.kind == DebtKind.moneyLent
            ? 'Geld verliehen: ${savedDebt.personName}'
            : 'Geld geliehen: ${savedDebt.personName}',
        fromAccountId:
            savedDebt.kind == DebtKind.moneyLent ? savedDebt.accountId : null,
        toAccountId: savedDebt.kind == DebtKind.moneyBorrowed
            ? savedDebt.accountId
            : null,
        debtId: savedDebt.id,
        note: savedDebt.note,
      ),
    );

    await AppSupabase.client
        .from('debts')
        .update({
          'transaction_id': savedTransaction.id,
        })
        .eq('id', savedDebt.id);
  }

  Future<void> updateDebtWithTransaction({
    required DebtModel debt,
    required FinancialTransactionModel transaction,
  }) async {
    await AppSupabase.client
        .from('debts')
        .update({
          'person_name': debt.personName,
          'kind': debt.kind.name,
          'original_amount': debt.originalAmount,
          'debt_date': _dateOnly(debt.debtDate),
          'due_date': _dateOnlyOrNull(debt.dueDate),
          'account_id': _validUuidOrNull(debt.accountId),
          'note': debt.note,
          'is_active': debt.isActive,
          'is_opening_balance': debt.isOpeningBalance,
        })
        .eq('id', debt.id);

    await _transactionsRepository.updateTransaction(
      transaction.copyWith(
        type: debt.kind == DebtKind.moneyLent
            ? FinancialTransactionType.debtGiven
            : FinancialTransactionType.debtBorrowed,
        amount: debt.originalAmount,
        transactionDate: debt.debtDate,
        title: debt.kind == DebtKind.moneyLent
            ? 'Geld verliehen: ${debt.personName}'
            : 'Geld geliehen: ${debt.personName}',
        fromAccountId: debt.kind == DebtKind.moneyLent ? debt.accountId : null,
        toAccountId: debt.kind == DebtKind.moneyBorrowed ? debt.accountId : null,
        debtId: debt.id,
        note: debt.note,
      ),
    );
  }

  Future<void> deleteDebtWithTransactions(String debtId) async {
    final transactionRows = await AppSupabase.client
        .from('financial_transactions')
        .select('id')
        .eq('debt_id', debtId);

    await AppSupabase.client.from('debts').delete().eq('id', debtId);

    for (final row in transactionRows) {
      final transactionId = row['id'] as String?;
      if (transactionId != null) {
        await _transactionsRepository.deleteTransaction(transactionId);
      }
    }
  }

  Future<void> createPaymentWithTransaction({
    required DebtModel debt,
    required DebtPaymentModel payment,
    required FinancialTransactionModel transaction,
  }) async {
    final familyId = await FamilyContextService.getCurrentFamilyId();
    final userId = AppSupabase.currentUserId;

    if (userId == null) {
      throw Exception('No logged in user.');
    }

    final paymentRow = await AppSupabase.client
        .from('debt_payments')
        .insert({
          'family_id': familyId,
          'debt_id': debt.id,
          'amount': payment.amount,
          'payment_date': _dateOnly(payment.paymentDate),
          'account_id': _validUuidOrNull(payment.accountId),
          'note': payment.note,
          'affects_balance': payment.affectsBalance,
          'created_by': userId,
        })
        .select()
        .single();

    final savedPayment = _paymentFromRow(paymentRow);

    final savedTransaction = await _transactionsRepository.createTransaction(
      transaction.copyWith(
        type: debt.kind == DebtKind.moneyLent
            ? FinancialTransactionType.debtReturned
            : FinancialTransactionType.debtPaidBack,
        amount: savedPayment.amount,
        transactionDate: savedPayment.paymentDate,
        title: debt.kind == DebtKind.moneyLent
            ? 'Rückzahlung erhalten: ${debt.personName}'
            : 'Schuld zurückgezahlt: ${debt.personName}',
        fromAccountId:
            debt.kind == DebtKind.moneyBorrowed ? savedPayment.accountId : null,
        toAccountId:
            debt.kind == DebtKind.moneyLent ? savedPayment.accountId : null,
        debtId: debt.id,
        note: savedPayment.note,
        affectsBalance: savedPayment.affectsBalance,
      ),
    );

    await AppSupabase.client
        .from('debt_payments')
        .update({
          'transaction_id': savedTransaction.id,
        })
        .eq('id', savedPayment.id);
  }

  Future<void> updatePaymentWithTransaction({
    required DebtModel debt,
    required DebtPaymentModel payment,
    required FinancialTransactionModel transaction,
  }) async {
    await AppSupabase.client
        .from('debt_payments')
        .update({
          'amount': payment.amount,
          'payment_date': _dateOnly(payment.paymentDate),
          'account_id': _validUuidOrNull(payment.accountId),
          'note': payment.note,
          'affects_balance': payment.affectsBalance,
        })
        .eq('id', payment.id);

    await _transactionsRepository.updateTransaction(
      transaction.copyWith(
        type: debt.kind == DebtKind.moneyLent
            ? FinancialTransactionType.debtReturned
            : FinancialTransactionType.debtPaidBack,
        amount: payment.amount,
        transactionDate: payment.paymentDate,
        title: debt.kind == DebtKind.moneyLent
            ? 'Rückzahlung erhalten: ${debt.personName}'
            : 'Schuld zurückgezahlt: ${debt.personName}',
        fromAccountId:
            debt.kind == DebtKind.moneyBorrowed ? payment.accountId : null,
        toAccountId: debt.kind == DebtKind.moneyLent ? payment.accountId : null,
        debtId: debt.id,
        note: payment.note,
        affectsBalance: payment.affectsBalance,
      ),
    );
  }

  Future<void> deletePaymentWithTransaction({
    required String paymentId,
    required String transactionId,
  }) async {
    await AppSupabase.client
        .from('debt_payments')
        .delete()
        .eq('id', paymentId);

    await _transactionsRepository.deleteTransaction(transactionId);
  }

  DebtModel _debtFromRow(Map<String, dynamic> row) {
    return DebtModel(
      id: row['id'] as String,
      personName: row['person_name'] as String? ?? '',
      kind: _debtKindFromString(row['kind'] as String?),
      originalAmount: _toDouble(row['original_amount']),
      debtDate: _toDateTime(row['debt_date']) ?? DateTime.now(),
      createdAt: _toDateTime(row['created_at']) ?? DateTime.now(),
      dueDate: _toDateTime(row['due_date']),
      accountId: row['account_id'] as String? ?? '',
      note: row['note'] as String?,
      isActive: row['is_active'] as bool? ?? true,
      isOpeningBalance: row['is_opening_balance'] as bool? ?? false,
    );
  }

  DebtPaymentModel _paymentFromRow(Map<String, dynamic> row) {
    return DebtPaymentModel(
      id: row['id'] as String,
      debtId: row['debt_id'] as String,
      amount: _toDouble(row['amount']),
      paymentDate: _toDateTime(row['payment_date']) ?? DateTime.now(),
      createdAt: _toDateTime(row['created_at']) ?? DateTime.now(),
      accountId: row['account_id'] as String? ?? '',
      note: row['note'] as String?,
      affectsBalance: row['affects_balance'] as bool? ?? true,
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

  DebtKind _debtKindFromString(String? value) {
    switch (value) {
      case 'moneyBorrowed':
        return DebtKind.moneyBorrowed;
      case 'moneyLent':
      default:
        return DebtKind.moneyLent;
    }
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

  String? _dateOnlyOrNull(DateTime? date) {
    if (date == null) {
      return null;
    }

    return _dateOnly(date);
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
