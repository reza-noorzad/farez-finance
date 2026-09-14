import '../../core/supabase/family_context_service.dart';
import '../../core/supabase/supabase_client.dart';
import '../../shared/models/monthly_budget_model.dart';

class BudgetRepository {
  Future<List<MonthlyBudgetModel>> fetchBudgetsForMonth(
    DateTime monthDate,
  ) async {
    final familyId = await FamilyContextService.getCurrentFamilyId();
    final monthStart = _monthStart(monthDate);

    final response = await AppSupabase.client
        .from('monthly_budgets')
        .select()
        .eq('family_id', familyId)
        .eq('month_date', _dateOnly(monthStart))
        .order('created_at', ascending: true);

    return response.map<MonthlyBudgetModel>((row) {
      return _budgetFromRow(row);
    }).toList();
  }

  Future<MonthlyBudgetModel> createBudget({
    required String categoryId,
    required DateTime monthDate,
    required double amount,
  }) async {
    final familyId = await FamilyContextService.getCurrentFamilyId();
    final userId = AppSupabase.currentUserId;

    if (userId == null) {
      throw Exception('No logged in user.');
    }

    final row = await AppSupabase.client
        .from('monthly_budgets')
        .insert({
          'family_id': familyId,
          'category_id': categoryId,
          'month_date': _dateOnly(_monthStart(monthDate)),
          'amount': amount,
          'created_by': userId,
        })
        .select()
        .single();

    return _budgetFromRow(row);
  }

  Future<MonthlyBudgetModel> updateBudget({
    required String budgetId,
    required double amount,
  }) async {
    final row = await AppSupabase.client
        .from('monthly_budgets')
        .update({
          'amount': amount,
        })
        .eq('id', budgetId)
        .select()
        .single();

    return _budgetFromRow(row);
  }

  Future<void> deleteBudget(String budgetId) async {
    await AppSupabase.client
        .from('monthly_budgets')
        .delete()
        .eq('id', budgetId);
  }

  MonthlyBudgetModel _budgetFromRow(Map<String, dynamic> row) {
    return MonthlyBudgetModel(
      id: row['id'] as String,
      categoryId: row['category_id'] as String,
      monthDate: _toDateTime(row['month_date']) ?? DateTime.now(),
      amount: _toDouble(row['amount']),
      createdAt: _toDateTime(row['created_at']) ?? DateTime.now(),
    );
  }

  DateTime _monthStart(DateTime date) {
    return DateTime(date.year, date.month, 1);
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
}
