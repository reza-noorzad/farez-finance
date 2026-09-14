import 'package:flutter/material.dart';

import '../../shared/models/travel_plan_model.dart';

class AddTravelPlanPage extends StatefulWidget {
  const AddTravelPlanPage({super.key});

  @override
  State<AddTravelPlanPage> createState() => _AddTravelPlanPageState();
}

class _AddTravelPlanPageState extends State<AddTravelPlanPage> {
  final _formKey = GlobalKey<FormState>();

  final _destinationController = TextEditingController();
  final _budgetController = TextEditingController();
  final _noteController = TextEditingController();

  DateTime _travelDate = DateTime.now();

  @override
  void dispose() {
    // Controller werden geschlossen, damit kein Speicher unnötig belegt wird.
    _destinationController.dispose();
    _budgetController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    // Dieses Format zeigt das Reisedatum benutzerfreundlich an.
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day.$month.$year';
  }

  Future<void> _pickTravelDate() async {
    // Der Benutzer kann das geplante Reisedatum auswählen.
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _travelDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (pickedDate == null) return;

    setState(() {
      _travelDate = pickedDate;
    });
  }

  void _saveTrip() {
    // Das Formular wird geprüft, bevor ein neuer Reiseplan erstellt wird.
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final targetBudget = double.parse(
      _budgetController.text.trim().replaceAll(',', '.'),
    );

    final newTrip = TravelPlanModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      destination: _destinationController.text.trim(),
      targetBudget: targetBudget,
      travelDate: _travelDate,
      status: TravelPlanStatus.active,
      createdAt: DateTime.now(),
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
    );

    // Der neue Reiseplan wird zurück an die TravelPlansPage gegeben.
    Navigator.pop(context, newTrip);
  }

  @override
  Widget build(BuildContext context) {
    // Diese Seite erstellt einen neuen Reiseplan.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Trip'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _destinationController,
              decoration: const InputDecoration(
                labelText: 'Destination',
                hintText: 'Example: Rome, Iran, Croatia',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a destination';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _budgetController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Target Budget',
                hintText: 'Example: 1500',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a target budget';
                }

                final amount = double.tryParse(value.replaceAll(',', '.'));

                if (amount == null || amount <= 0) {
                  return 'Please enter a valid budget';
                }

                return null;
              },
            ),

            const SizedBox(height: 16),

            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_month_outlined),
                title: const Text('Travel Date'),
                subtitle: Text(_formatDate(_travelDate)),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: _pickTravelDate,
              ),
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Note',
                hintText: 'Optional note',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 24),

            FilledButton.icon(
              onPressed: _saveTrip,
              icon: const Icon(Icons.save),
              label: const Text('Save Trip'),
            ),
          ],
        ),
      ),
    );
  }
}