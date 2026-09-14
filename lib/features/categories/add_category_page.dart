import 'package:flutter/material.dart';

import '../../core/constants/category_colors.dart';
import '../../core/constants/category_icons.dart';
import '../../shared/models/category_model.dart';

class AddCategoryPage extends StatefulWidget {
  final List<CategoryModel> existingCategories;

  const AddCategoryPage({super.key, this.existingCategories = const []});

  @override
  State<AddCategoryPage> createState() => _AddCategoryPageState();
}

class _AddCategoryPageState extends State<AddCategoryPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  CategoryType _selectedType = CategoryType.transaction;
  CategoryDirection _selectedDirection = CategoryDirection.expense;

  bool _showInDashboard = true;
  String? _parentId;

  String _selectedIconName = 'other';
  int _selectedColorValue = CategoryColors.colors.first.toARGB32();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _saveCategory() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final newCategory = CategoryModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      type: _selectedType,
      direction: _selectedDirection,
      parentId: _parentId,
      isActive: true,
      showInDashboard: _showInDashboard,
      iconName: _selectedIconName,
      colorValue: _selectedColorValue,
      createdAt: DateTime.now(),
    );

    Navigator.pop(context, newCategory);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Category'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Category Name',
                hintText: 'Example: Food, Salary, Leo',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a category name';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),


            DropdownButtonFormField<String?>(
              value: _parentId,
              decoration: const InputDecoration(
                labelText: 'Unterkategorie von (optional)',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('Keine – Hauptkategorie')),
                ...widget.existingCategories
                    .where((c) => c.isActive && c.parentId == null && c.type == CategoryType.transaction)
                    .map((c) => DropdownMenuItem<String?>(value: c.id, child: Text(c.name))),
              ],
              onChanged: (value) => setState(() => _parentId = value),
            ),

            const SizedBox(height: 16),
            DropdownButtonFormField<CategoryType>(
              initialValue: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Category Type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: CategoryType.transaction,
                  child: Text('Monthly Transaction'),
                ),
                DropdownMenuItem(
                  value: CategoryType.balance,
                  child: Text('Balance Account'),
                ),
                DropdownMenuItem(
                  value: CategoryType.debt,
                  child: Text('Debt / Receivable'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  _selectedType = value;

                  if (_selectedType == CategoryType.balance ||
                      _selectedType == CategoryType.debt) {
                    _selectedDirection = CategoryDirection.both;
                  }
                });
              },
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<CategoryDirection>(
              initialValue: _selectedDirection,
              decoration: const InputDecoration(
                labelText: 'Used For',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: CategoryDirection.income,
                  child: Text('Income'),
                ),
                DropdownMenuItem(
                  value: CategoryDirection.expense,
                  child: Text('Expense'),
                ),
                DropdownMenuItem(
                  value: CategoryDirection.both,
                  child: Text('Both'),
                ),
              ],
              onChanged: _selectedType == CategoryType.transaction
                  ? (value) {
                      if (value == null) return;

                      setState(() {
                        _selectedDirection = value;
                      });
                    }
                  : null,
            ),

            const SizedBox(height: 24),

            const Text(
              'Icon',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: CategoryIcons.icons.entries.map((entry) {
                final isSelected = entry.key == _selectedIconName;

                return ChoiceChip(
                  selected: isSelected,
                  avatar: Icon(entry.value, size: 18),
                  label: Text(entry.key),
                  onSelected: (_) {
                    setState(() {
                      _selectedIconName = entry.key;
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            const Text(
              'Color',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Wrap(
              spacing: 10,
              children: CategoryColors.colors.map((color) {
                final isSelected = color.toARGB32() == _selectedColorValue;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedColorValue = color.toARGB32();
                    });
                  },
                  child: CircleAvatar(
                    radius: isSelected ? 18 : 15,
                    backgroundColor: color,
                    child: isSelected
                        ? const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 18,
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            SwitchListTile(
              value: _showInDashboard,
              title: const Text('Show in Dashboard'),
              subtitle: const Text(
                'This category will stay visible every month until you turn it off.',
              ),
              onChanged: (value) {
                setState(() {
                  _showInDashboard = value;
                });
              },
            ),

            const SizedBox(height: 24),

            FilledButton.icon(
              onPressed: _saveCategory,
              icon: const Icon(Icons.save),
              label: const Text('Save Category'),
            ),
          ],
        ),
      ),
    );
  }
}