class AccountModel {
  final String id;
  final String name;
  final AccountKind kind;
  final double balance;
  final String iconName;
  final int colorValue;
  final bool isActive;
  final bool showInDashboard;
  final DateTime createdAt;

  // Optionales Sparziel.
  // Nur für Funds / Spartöpfe wichtig.
  final double? targetAmount;
  final DateTime? startDate;
  final DateTime? targetDate;

  const AccountModel({
    required this.id,
    required this.name,
    required this.kind,
    required this.balance,
    required this.iconName,
    required this.colorValue,
    required this.isActive,
    required this.showInDashboard,
    required this.createdAt,
    this.targetAmount,
    this.startDate,
    this.targetDate,
  });

  AccountModel copyWith({
    String? id,
    String? name,
    AccountKind? kind,
    double? balance,
    String? iconName,
    int? colorValue,
    bool? isActive,
    bool? showInDashboard,
    DateTime? createdAt,
    double? targetAmount,
    DateTime? startDate,
    DateTime? targetDate,
  }) {
    // Diese Methode erstellt eine Kopie mit geänderten Werten.
    return AccountModel(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      balance: balance ?? this.balance,
      iconName: iconName ?? this.iconName,
      colorValue: colorValue ?? this.colorValue,
      isActive: isActive ?? this.isActive,
      showInDashboard: showInDashboard ?? this.showInDashboard,
      createdAt: createdAt ?? this.createdAt,
      targetAmount: targetAmount ?? this.targetAmount,
      startDate: startDate ?? this.startDate,
      targetDate: targetDate ?? this.targetDate,
    );
  }
}

enum AccountKind {
  // Normales Geldkonto für laufendes Geld.
  // Beispiel: Bank Account, Cash Wallet
  account,

  // Zweckgebundener Geldtopf.
  // Beispiel: Emergency Fund, Travel Fund
  fund,
}