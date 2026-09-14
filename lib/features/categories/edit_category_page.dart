import 'package:flutter/material.dart';

import '../../core/constants/category_colors.dart';
import '../../core/constants/category_icons.dart';
import '../../shared/models/category_model.dart';

class EditCategoryPage extends StatefulWidget {
  final CategoryModel category;
  final List<CategoryModel> existingCategories;

  const EditCategoryPage({
    super.key,
    required this.category,
    this.existingCategories = const [],
  });

  @override
  State<EditCategoryPage> createState() => _EditCategoryPageState();
}

class _EditCategoryPageState extends State<EditCategoryPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late CategoryType _selectedType;
  late CategoryDirection _selectedDirection;
  late bool _showInDashboard;
  String? _parentId;
  late bool _isActive;
  late String _selectedIconName;
  late int _selectedColorValue;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.category.name);
    _selectedType = widget.category.type;
    _selectedDirection = widget.category.direction;
    _showInDashboard = widget.category.showInDashboard;
    _parentId = widget.category.parentId;
    _isActive = widget.category.isActive;
    _selectedIconName = widget.category.iconName;
    _selectedColorValue = widget.category.colorValue;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _saveCategory() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final updatedCategory = CategoryModel(
      id: widget.category.id,
      name: _nameController.text.trim(),
      type: _selectedType,
      direction: _selectedDirection,
      parentId: _parentId,
      isActive: _isActive,
      showInDashboard: _showInDashboard,
      iconName: _selectedIconName,
      colorValue: _selectedColorValue,
      createdAt: widget.category.createdAt,
    );

    Navigator.pop(context, updatedCategory);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Category'),
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
                    .where((c) => c.id != widget.category.id && c.isActive && c.parentId == null && c.type == CategoryType.transaction)
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
                'Visible every month until you turn it off.',
              ),
              onChanged: (value) {
                setState(() {
                  _showInDashboard = value;
                });
              },
            ),

            SwitchListTile(
              value: _isActive,
              title: const Text('Active'),
              subtitle: const Text(
                'Inactive categories stay saved but are hidden from future selection.',
              ),
              onChanged: (value) {
                setState(() {
                  _isActive = value;
                });
              },
            ),

            const SizedBox(height: 24),

            FilledButton.icon(
              onPressed: _saveCategory,
              icon: const Icon(Icons.save),
              label: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}