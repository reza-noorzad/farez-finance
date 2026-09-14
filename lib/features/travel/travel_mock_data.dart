import '../../shared/models/travel_contribution_model.dart';
import '../../shared/models/travel_plan_model.dart';

class TravelMockData {
  static final List<TravelPlanModel> travelPlans = [
    TravelPlanModel(
      id: '1',
      destination: 'Rome',
      targetBudget: 1500,
      travelDate: DateTime(2026, 9, 20),
      status: TravelPlanStatus.active,
      createdAt: DateTime.now(),
      note: 'Summer trip',
    ),
    TravelPlanModel(
      id: '2',
      destination: 'Croatia 2026',
      targetBudget: 700,
      travelDate: DateTime(2026, 6, 5),
      status: TravelPlanStatus.completed,
      createdAt: DateTime.now(),
      note: 'Completed test trip',
    ),
  ];

  static final List<TravelContributionModel> contributions = [
    TravelContributionModel(
      id: '1',
      travelPlanId: '1',
      amount: 300,
      date: DateTime(2026, 6, 10),
      createdAt: DateTime.now(),
      note: 'Initial saving',
    ),
    TravelContributionModel(
      id: '2',
      travelPlanId: '1',
      amount: 150,
      date: DateTime(2026, 7, 1),
      createdAt: DateTime.now(),
      note: 'Monthly saving',
    ),
    TravelContributionModel(
      id: '3',
      travelPlanId: '2',
      amount: 700,
      date: DateTime(2026, 5, 25),
      createdAt: DateTime.now(),
      note: 'Saved before trip',
    ),
  ];

  static double savedAmountForTrip(String travelPlanId) {
    return contributions
        .where((item) => item.travelPlanId == travelPlanId)
        .fold(0, (sum, item) => sum + item.amount);
  }

  static List<TravelContributionModel> contributionsForTrip(
    String travelPlanId,
  ) {
    return contributions
        .where((item) => item.travelPlanId == travelPlanId)
        .toList();
  }
}