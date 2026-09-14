import '../../core/supabase/family_context_service.dart';
import '../../core/supabase/supabase_client.dart';
import '../../shared/models/travel_contribution_model.dart';
import '../../shared/models/travel_plan_model.dart';

class TravelDbData {
  final List<TravelPlanModel> travelPlans;
  final List<TravelContributionModel> contributions;

  const TravelDbData({
    required this.travelPlans,
    required this.contributions,
  });
}

class TravelRepository {
  Future<TravelDbData> fetchTravelData() async {
    final familyId = await FamilyContextService.getCurrentFamilyId();

    final planRows = await AppSupabase.client
        .from('travel_plans')
        .select()
        .eq('family_id', familyId)
        .order('travel_date', ascending: true)
        .order('created_at', ascending: true);

    final contributionRows = await AppSupabase.client
        .from('travel_contributions')
        .select()
        .eq('family_id', familyId)
        .order('contribution_date', ascending: false)
        .order('created_at', ascending: false);

    final travelPlans = planRows.map<TravelPlanModel>((row) {
      return _travelPlanFromRow(row);
    }).toList();

    final contributions = contributionRows.map<TravelContributionModel>((row) {
      return _contributionFromRow(row);
    }).toList();

    return TravelDbData(
      travelPlans: travelPlans,
      contributions: contributions,
    );
  }

  Future<TravelPlanModel> createTravelPlan(TravelPlanModel travelPlan) async {
    final familyId = await FamilyContextService.getCurrentFamilyId();
    final userId = AppSupabase.currentUserId;

    if (userId == null) {
      throw Exception('No logged in user.');
    }

    final row = await AppSupabase.client
        .from('travel_plans')
        .insert({
          'family_id': familyId,
          'destination': travelPlan.destination,
          'target_budget': travelPlan.targetBudget,
          'travel_date': _dateOnly(travelPlan.travelDate),
          'status': travelPlan.status.name,
          'note': travelPlan.note,
          'created_by': userId,
        })
        .select()
        .single();

    return _travelPlanFromRow(row);
  }

  Future<TravelPlanModel> updateTravelPlan(TravelPlanModel travelPlan) async {
    final row = await AppSupabase.client
        .from('travel_plans')
        .update({
          'destination': travelPlan.destination,
          'target_budget': travelPlan.targetBudget,
          'travel_date': _dateOnly(travelPlan.travelDate),
          'status': travelPlan.status.name,
          'note': travelPlan.note,
        })
        .eq('id', travelPlan.id)
        .select()
        .single();

    return _travelPlanFromRow(row);
  }

  Future<void> deleteTravelPlan(String travelPlanId) async {
    await AppSupabase.client
        .from('travel_plans')
        .delete()
        .eq('id', travelPlanId);
  }

  Future<TravelContributionModel> createContribution({
    required TravelContributionModel contribution,
  }) async {
    final familyId = await FamilyContextService.getCurrentFamilyId();
    final userId = AppSupabase.currentUserId;

    if (userId == null) {
      throw Exception('No logged in user.');
    }

    final row = await AppSupabase.client
        .from('travel_contributions')
        .insert({
          'family_id': familyId,
          'travel_plan_id': contribution.travelPlanId,
          'source_account_id': contribution.sourceAccountId,
          'amount': contribution.amount,
          'contribution_date': _dateOnly(contribution.date),
          'note': contribution.note,
          'created_by': userId,
        })
        .select()
        .single();

    return _contributionFromRow(row);
  }

  Future<TravelContributionModel> releaseContribution({
    required String travelPlanId,
    required String destinationAccountId,
    required double amount,
    required DateTime date,
    String? note,
  }) async {
    if (amount <= 0) throw Exception('Amount must be greater than zero.');
    return createContribution(
      contribution: TravelContributionModel(
        id: '',
        travelPlanId: travelPlanId,
        sourceAccountId: destinationAccountId,
        amount: -amount,
        date: date,
        createdAt: DateTime.now(),
        note: note ?? 'Reservierung freigegeben',
      ),
    );
  }

  TravelPlanModel _travelPlanFromRow(Map<String, dynamic> row) {
    return TravelPlanModel(
      id: row['id'] as String,
      destination: row['destination'] as String? ?? '',
      targetBudget: _toDouble(row['target_budget']),
      travelDate: _toDateTime(row['travel_date']) ?? DateTime.now(),
      status: _statusFromString(row['status'] as String?),
      createdAt: _toDateTime(row['created_at']) ?? DateTime.now(),
      note: row['note'] as String?,
    );
  }

  TravelContributionModel _contributionFromRow(Map<String, dynamic> row) {
    return TravelContributionModel(
      id: row['id'] as String,
      travelPlanId: row['travel_plan_id'] as String,
      sourceAccountId: row['source_account_id'] as String?,
      amount: _toDouble(row['amount']),
      date: _toDateTime(row['contribution_date']) ?? DateTime.now(),
      createdAt: _toDateTime(row['created_at']) ?? DateTime.now(),
      note: row['note'] as String?,
    );
  }

  TravelPlanStatus _statusFromString(String? value) {
    switch (value) {
      case 'completed':
        return TravelPlanStatus.completed;
      case 'active':
      default:
        return TravelPlanStatus.active;
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
}
