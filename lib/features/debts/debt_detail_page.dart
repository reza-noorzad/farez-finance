import 'package:flutter/material.dart';

import '../../shared/models/account_model.dart';
import '../../shared/models/debt_model.dart';
import '../../shared/models/debt_payment_model.dart';

enum DebtDetailAction {
  editDebt,
  deleteDebt,
  addPayment,
  editPayment,
  deletePayment,
}

class DebtDetailResult {
  final DebtDetailAction action;
  final DebtPaymentModel? payment;

  const DebtDetailResult({
    required this.action,
    this.payment,
  });
}

class DebtDetailPage extends StatelessWidget {
  final DebtModel debt;
  final List<DebtPaymentModel> payments;
  final List<AccountModel> accounts;

  const DebtDetailPage({
    super.key,
    required this.debt,
    required this.payments,
    required this.accounts,
  });

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day.$month.$year';
  }

  String _accountName(String accountId) {
    try {
      return accounts.firstWhere((account) => account.id == accountId).name;
    } catch (_) {
      return 'Unbekanntes Konto';
    }
  }

  @override
  Widget build(BuildContext context) {
    final debtPayments = payments.where((payment) {
      return payment.debtId == debt.id;
    }).toList();

    final paidAmount = debt.paidAmountFrom(payments);
    final remainingAmount = debt.remainingAmountFrom(payments);
    final isClosed = debt.isClosedBy(payments);

    final isMoneyLent = debt.kind == DebtKind.moneyLent;

    return Scaffold(
      appBar: AppBar(
        title: Text(debt.personName),
        actions: [
          PopupMenuButton<DebtDetailAction>(
            onSelected: (action) {
              Navigator.pop(
                context,
                DebtDetailResult(action: action),
              );
            },
            itemBuilder: (context) {
              return const [
                PopupMenuItem(
                  value: DebtDetailAction.editDebt,
                  child: Text('Bearbeiten'),
                ),
                PopupMenuItem(
                  value: DebtDetailAction.deleteDebt,
                  child: Text('Löschen'),
                ),
              ];
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMoneyLent ? 'Ich bekomme Geld' : 'Ich schulde Geld',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _DetailRow(
                    label: 'Person',
                    value: debt.personName,
                  ),
                  _DetailRow(
                    label: 'Ursprünglicher Betrag',
                    value: '€${debt.originalAmount.toStringAsFixed(2)}',
                  ),
                  _DetailRow(
                    label: 'Bereits bezahlt',
                    value: '€${paidAmount.toStringAsFixed(2)}',
                  ),
                  _DetailRow(
                    label: 'Offen',
                    value: '€${remainingAmount.toStringAsFixed(2)}',
                  ),
                  _DetailRow(
                    label: 'Datum',
                    value: _formatDate(debt.debtDate),
                  ),
                  if (debt.dueDate != null)
                    _DetailRow(
                      label: 'Fällig',
                      value: _formatDate(debt.dueDate!),
                    ),
                  _DetailRow(
                    label: isMoneyLent ? 'Gegeben von' : 'Erhalten auf',
                    value: _accountName(debt.accountId),
                  ),
                  if (debt.note != null && debt.note!.trim().isNotEmpty)
                    _DetailRow(
                      label: 'Notiz',
                      value: debt.note!,
                    ),
                  const SizedBox(height: 8),
                  Chip(
                    avatar: Icon(
                      isClosed
                          ? Icons.check_circle_outline
                          : Icons.schedule_outlined,
                      size: 18,
                    ),
                    label: Text(isClosed ? 'Geschlossen' : 'Offen'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          Row(
            children: [
              Text(
                'Zahlungen',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              if (!isClosed)
                IconButton(
                  tooltip: 'Zahlung hinzufügen',
                  onPressed: () {
                    Navigator.pop(
                      context,
                      const DebtDetailResult(
                        action: DebtDetailAction.addPayment,
                      ),
                    );
                  },
                  icon: const Icon(Icons.add),
                ),
            ],
          ),

          const SizedBox(height: 12),

          if (debtPayments.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Noch keine Zahlungen vorhanden.'),
              ),
            )
          else
            for (final payment in debtPayments.reversed)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.payments_outlined),
                  title: Text('€${payment.amount.toStringAsFixed(2)}'),
                  subtitle: Text(
                    '${_formatDate(payment.paymentDate)} · ${_accountName(payment.accountId)}',
                  ),
                  trailing: PopupMenuButton<DebtDetailAction>(
                    onSelected: (action) {
                      Navigator.pop(
                        context,
                        DebtDetailResult(
                          action: action,
                          payment: payment,
                        ),
                      );
                    },
                    itemBuilder: (context) {
                      return const [
                        PopupMenuItem(
                          value: DebtDetailAction.editPayment,
                          child: Text('Bearbeiten'),
                        ),
                        PopupMenuItem(
                          value: DebtDetailAction.deletePayment,
                          child: Text('Löschen'),
                        ),
                      ];
                    },
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
