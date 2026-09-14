import 'package:flutter/material.dart';

import '../../shared/models/expense_model.dart';

enum ExpenseDetailAction {
  edit,
  delete,
}

class ExpenseDetailPage extends StatelessWidget {
  final ExpenseModel expense;
  final String categoryName;
  final String dateText;
  final String paymentSourceName;

  const ExpenseDetailPage({
    super.key,
    required this.expense,
    required this.categoryName,
    required this.dateText,
    required this.paymentSourceName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(expense.title),
        actions: [
          PopupMenuButton<ExpenseDetailAction>(
            onSelected: (value) {
              Navigator.pop(context, value);
            },
            itemBuilder: (context) {
              return const [
                PopupMenuItem(
                  value: ExpenseDetailAction.edit,
                  child: Text('Bearbeiten'),
                ),
                PopupMenuItem(
                  value: ExpenseDetailAction.delete,
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
                children: [
                  _DetailRow(
                    label: 'Name / Geschäft',
                    value: expense.storeName ?? expense.title,
                  ),
                  _DetailRow(
                    label: 'Kategorie',
                    value: categoryName,
                  ),
                  _DetailRow(
                    label: 'Datum',
                    value: dateText,
                  ),
                  _DetailRow(
                    label: 'Bezahlt mit',
                    value: paymentSourceName,
                  ),
                  _DetailRow(
                    label: 'Betrag',
                    value: '€${expense.amount.toStringAsFixed(2)}',
                  ),
                  if (expense.note != null && expense.note!.trim().isNotEmpty)
                    _DetailRow(
                      label: 'Notiz',
                      value: expense.note!,
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          Text(
            'Einkaufsliste',
            style: Theme.of(context).textTheme.titleLarge,
          ),

          const SizedBox(height: 12),

          if (expense.items.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Für diese Ausgabe wurden keine Produktdetails gespeichert.',
                ),
              ),
            )
          else
            for (final item in expense.items)
              Card(
                child: ListTile(
                  title: Text(item.originalName ?? item.name),
                  subtitle: Text(
                    '${item.measurementLabel} · ${item.category}'
                    '${item.needsReview ? ' · Prüfung empfohlen' : ''}',
                  ),
                  trailing: Text(
                    '€${item.totalPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
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
