import 'package:flutter/material.dart';

import '../../shared/models/account_model.dart';

class AccountMockData {
  static final List<AccountModel> accounts = [
    AccountModel(
      id: 'bank',
      name: 'Bank Account',
      kind: AccountKind.account,
      balance: 0.0,
      iconName: 'account_balance',
      colorValue: Colors.blue.toARGB32(),
      isActive: true,
      showInDashboard: true,
      createdAt: DateTime(2026, 1, 1),
    ),
    AccountModel(
      id: 'cash',
      name: 'Cash Wallet',
      kind: AccountKind.account,
      balance: 0.0,
      iconName: 'payments',
      colorValue: Colors.green.toARGB32(),
      isActive: true,
      showInDashboard: true,
      createdAt: DateTime(2026, 1, 1),
    ),
  ];

  static List<AccountModel> get activeAccounts {
    return accounts.where((account) => account.isActive).toList();
  }

  static List<AccountModel> get normalAccounts {
    return activeAccounts.where((account) {
      return account.kind == AccountKind.account;
    }).toList();
  }

  static List<AccountModel> get funds {
    return activeAccounts.where((account) {
      return account.kind == AccountKind.fund;
    }).toList();
  }
}