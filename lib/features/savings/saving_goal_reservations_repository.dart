import '../../core/supabase/family_context_service.dart';
import '../../core/supabase/supabase_client.dart';
import '../../shared/models/saving_goal_reservation_model.dart';

class SavingGoalReservationsRepository {
  Future<List<SavingGoalReservationModel>> fetchReservations() async {
    final familyId = await FamilyContextService.getCurrentFamilyId();

    final response = await AppSupabase.client
        .from('saving_goal_reservations')
        .select()
        .eq('family_id', familyId)
        .order('reservation_date', ascending: false)
        .order('created_at', ascending: false);

    return response.map<SavingGoalReservationModel>((row) {
      return _reservationFromRow(row);
    }).toList();
  }

  Future<SavingGoalReservationModel> createReservation(
    SavingGoalReservationModel reservation,
  ) async {
    final familyId = await FamilyContextService.getCurrentFamilyId();
    final userId = AppSupabase.currentUserId;

    if (userId == null) {
      throw Exception('No logged in user.');
    }

    final row = await AppSupabase.client
        .from('saving_goal_reservations')
        .insert({
          'family_id': familyId,
          'fund_id': reservation.fundId,
          'source_account_id': reservation.sourceAccountId,
          'amount': reservation.amount,
          'reservation_date': _dateOnly(reservation.date),
          'note': reservation.note,
          'created_by': userId,
        })
        .select()
        .single();

    return _reservationFromRow(row);
  }

  Future<SavingGoalReservationModel> releaseReservation({
    required String fundId,
    required String destinationAccountId,
    required double amount,
    required DateTime date,
    String? note,
  }) async {
    if (amount <= 0) throw Exception('Amount must be greater than zero.');
    return createReservation(SavingGoalReservationModel(
      id: '',
      fundId: fundId,
      sourceAccountId: destinationAccountId,
      amount: -amount,
      date: date,
      createdAt: DateTime.now(),
      note: note ?? 'Reservierung freigegeben',
    ));
  }

  Future<void> deleteReservationsByFundId(String fundId) async {
    await AppSupabase.client
        .from('saving_goal_reservations')
        .delete()
        .eq('fund_id', fundId);
  }

  SavingGoalReservationModel _reservationFromRow(Map<String, dynamic> row) {
    return SavingGoalReservationModel(
      id: row['id'] as String,
      fundId: row['fund_id'] as String,
      sourceAccountId: row['source_account_id'] as String?,
      amount: _toDouble(row['amount']),
      date: _toDateTime(row['reservation_date']) ?? DateTime.now(),
      createdAt: _toDateTime(row['created_at']) ?? DateTime.now(),
      note: row['note'] as String?,
    );
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
