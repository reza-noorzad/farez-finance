import 'package:flutter/material.dart';

import '../../core/supabase/family_context_service.dart';
import '../../core/supabase/supabase_client.dart';
import '../../shared/models/account_model.dart';

class AccountsRepository {
  Future<List<AccountModel>> fetchAccounts() async {
    final familyId = await FamilyContextService.getCurrentFamilyId();

    final response = await AppSupabase.client
        .from('accounts')
        .select()
        .eq('family_id', familyId)
        .order('created_at', ascending: true);

    return response
        .map<AccountModel>((row) => _accountFromRow(row))
        .toList();
  }

  Future<List<AccountModel>> fetchActiveAccounts() async {
    final accounts = await fetchAccounts();
    return accounts.where((account) => account.isActive).toList();
  }

  Future<AccountModel> createAccount(AccountModel account) async {
    final familyId = await FamilyContextService.getCurrentFamilyId();
    final userId = AppSupabase.currentUserId;

    if (userId == null) {
      throw Exception('No logged in user.');
    }

    final row = await AppSupabase.client
        .from('accounts')
        .insert({
          'family_id': familyId,
          'name': account.name,
          'kind': account.kind.name,
          'balance': account.balance,
          'icon_name': account.iconName,
          'color_value': account.colorValue,
          'is_active': account.isActive,
          'show_in_dashboard': account.showInDashboard,
          'target_amount': account.targetAmount,
          'start_date': _dateOnly(account.startDate),
          'target_date': _dateOnly(account.targetDate),
          'created_by': userId,
        })
        .select()
        .single();

    return _accountFromRow(row);
  }

  Future<AccountModel> updateAccount(AccountModel account) async {
    final row = await AppSupabase.client
        .from('accounts')
        .update({
          'name': account.name,
          'kind': account.kind.name,
          'balance': account.balance,
          'icon_name': account.iconName,
          'color_value': account.colorValue,
          'is_active': account.isActive,
          'show_in_dashboard': account.showInDashboard,
          'target_amount': account.targetAmount,
          'start_date': _dateOnly(account.startDate),
          'target_date': _dateOnly(account.targetDate),
        })
        .eq('id', account.id)
        .select()
        .single();

    return _accountFromRow(row);
  }

  Future<void> deleteAccount(String accountId) async {
    await AppSupabase.client.from('accounts').delete().eq('id', accountId);
  }

  Future<void> archiveAccount(String accountId) async {
    await AppSupabase.client
        .from('accounts')
        .update({
          'is_active': false,
          'show_in_dashboard': false,
        })
        .eq('id', accountId);
  }

  AccountModel _accountFromRow(Map<String, dynamic> row) {
    return AccountModel(
      id: row['id'] as String,
      name: row['name'] as String,
      kind: _accountKindFromString(row['kind'] as String?),
      balance: _toDouble(row['balance']),
      iconName: row['icon_name'] as String? ?? 'account_balance',
      colorValue: _toInt(row['color_value']) ?? Colors.blue.toARGB32(),
      isActive: row['is_active'] as bool? ?? true,
      showInDashboard: row['show_in_dashboard'] as bool? ?? true,
      createdAt: _toDateTime(row['created_at']) ?? DateTime.now(),
      targetAmount: _toNullableDouble(row['target_amount']),
      startDate: _toDateTime(row['start_date']),
      targetDate: _toDateTime(row['target_date']),
    );
  }

  AccountKind _accountKindFromString(String? value) {
    switch (value) {
      case 'fund':
        return AccountKind.fund;
      case 'account':
      default:
        return AccountKind.account;
    }
  }

  String? _dateOnly(DateTime? date) {
    if (date == null) return null;

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
    return _toNullableDouble(value) ?? 0.0;
  }

  double? _toNullableDouble(dynamic value) {
    if (value == null) return null;

    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value);
    }

    return null;
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value);
    }

    return null;
  }
}
