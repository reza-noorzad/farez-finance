import '../../shared/models/debt_model.dart';
import '../../shared/models/debt_payment_model.dart';

class DebtMockData {
  // برای استفاده واقعی بدون دمو دیتا شروع می‌کنیم.
  static final List<DebtModel> debts = [];

  static final List<DebtPaymentModel> payments = [];

  static List<DebtModel> get activeDebts {
    return debts.where((debt) => debt.isActive).toList();
  }
}
