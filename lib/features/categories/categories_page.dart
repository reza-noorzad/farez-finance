import 'package:flutter/material.dart';

import '../../core/constants/category_colors.dart';
import '../../core/constants/category_icons.dart';
import '../../core/localization/app_strings.dart';
import '../../shared/models/category_model.dart';
import '../../shared/widgets/help_text_card.dart';
import 'add_category_page.dart';
import 'category_mock_data.dart';
import 'category_repository.dart';
import 'edit_category_page.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  final CategoryRepository _categoryRepository = CategoryRepository();

  List<CategoryModel> _categories = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final categories = await _categoryRepository.fetchCategories();

      CategoryMockData.categories
        ..clear()
        ..addAll(categories);

      if (!mounted) {
        return;
      }

      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Fehler beim Laden der Kategorien: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _openAddCategoryPage() async {
    final result = await Navigator.push<CategoryModel>(
      context,
      MaterialPageRoute(
        builder: (context) => AddCategoryPage(existingCategories: _categories),
      ),
    );

    if (result == null) {
      return;
    }

    try {
      await _categoryRepository.createCategory(result);
      await _loadCategories();
    } catch (e) {
      _showError('Kategorie konnte nicht gespeichert werden: $e');
    }
  }

  Future<void> _openEditCategoryPage(CategoryModel category) async {
    final result = await Navigator.push<CategoryModel>(
      context,
      MaterialPageRoute(
        builder: (context) => EditCategoryPage(category: category, existingCategories: _categories),
      ),
    );

    if (result == null) {
      return;
    }

    try {
      await _categoryRepository.updateCategory(result);
      await _loadCategories();
    } catch (e) {
      _showError('Kategorie konnte nicht bearbeitet werden: $e');
    }
  }

  Future<void> _deleteCategory(CategoryModel category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Kategorie löschen'),
          content: Text(
            'Möchtest du "${category.name}" wirklich löschen?\n\n'
            'Wenn diese Kategorie schon benutzt wurde, kann Supabase das Löschen blockieren. '
            'Dann wird sie später nur deaktiviert.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Löschen'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _categoryRepository.deleteCategory(category.id);
      await _loadCategories();
    } catch (_) {
      try {
        await _categoryRepository.archiveCategory(category.id);
        await _loadCategories();
      } catch (e) {
        _showError('Kategorie konnte nicht gelöscht werden: $e');
      }
    }
  }

  String _categoryTypeLabel(CategoryType type) {
    switch (type) {
      case CategoryType.transaction:
        return 'Einnahmen / Ausgaben';
      case CategoryType.balance:
        return 'Konto / Sparziel';
      case CategoryType.debt:
        return 'Schulden / Forderungen';
    }
  }

  String _categoryDirectionLabel(CategoryDirection direction) {
    switch (direction) {
      case CategoryDirection.income:
        return AppStrings.income;
      case CategoryDirection.expense:
        return AppStrings.expenses;
      case CategoryDirection.both:
        return 'Beides';
    }
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _refresh() async {
    await _loadCategories();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(AppStrings.categories),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(AppStrings.categories),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Erneut versuchen'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final activeCategories = _categories.where((category) {
      return category.isActive;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.categories),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            HelpTextCard(
              title: 'Kategorien helfen dir beim Ordnen',
              message:
                  'Erstelle eigene Kategorien wie Lebensmittel, Miete, Gehalt oder Freizeit. '
                  'Diese Kategorien werden jetzt in Supabase gespeichert.',
              buttonText: 'Kategorie hinzufügen',
              onButtonPressed: _openAddCategoryPage,
            ),
            const SizedBox(height: 16),
            if (activeCategories.isEmpty)
              const HelpTextCard(
                title: 'Noch keine Kategorien vorhanden',
                message:
                    'Du hast noch keine Kategorien erstellt. Tippe auf Kategorie hinzufügen, um deine erste Kategorie zu erstellen.',
                icon: Icons.category_outlined,
              )
            else
              for (final category in activeCategories)
                _CategoryCard(
                  category: category,
                  typeLabel: _categoryTypeLabel(category.type),
                  directionLabel: _categoryDirectionLabel(category.direction),
                  onEdit: () => _openEditCategoryPage(category),
                  onDelete: () => _deleteCategory(category),
                ),
            const SizedBox(height: 90),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddCategoryPage,
        icon: const Icon(Icons.add),
        label: const Text('Kategorie'),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final CategoryModel category;
  final String typeLabel;
  final String directionLabel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CategoryCard({
    required this.category,
    required this.typeLabel,
    required this.directionLabel,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final icon = CategoryIcons.getIcon(category.iconName);
    final color = CategoryColors.getColor(category.colorValue);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Icon(
            icon,
            color: color,
          ),
        ),
        title: Text(category.name),
        subtitle: Text('$typeLabel • $directionLabel'),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              onEdit();
            }

            if (value == 'delete') {
              onDelete();
            }
          },
          itemBuilder: (context) {
            return [
              PopupMenuItem(
                value: 'edit',
                child: Text(AppStrings.edit),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text(AppStrings.delete),
              ),
            ];
          },
        ),
      ),
    );
  }
}