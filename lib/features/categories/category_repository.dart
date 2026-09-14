import '../../core/supabase/family_context_service.dart';
import '../../core/supabase/supabase_client.dart';
import '../../shared/models/category_model.dart';

class CategoryRepository {
  Future<List<CategoryModel>> fetchCategories() async {
    final familyId = await FamilyContextService.getCurrentFamilyId();

    final response = await AppSupabase.client
        .from('categories')
        .select()
        .eq('family_id', familyId)
        .order('created_at', ascending: true);

    return response.map<CategoryModel>((row) {
      return _categoryFromRow(row);
    }).toList();
  }

  Future<CategoryModel> createCategory(CategoryModel category) async {
    final familyId = await FamilyContextService.getCurrentFamilyId();
    final userId = AppSupabase.currentUserId;

    if (userId == null) {
      throw Exception('No logged in user.');
    }

    final row = await AppSupabase.client
        .from('categories')
        .insert({
          'family_id': familyId,
          'name': category.name,
          'type': category.type.name,
          'direction': category.direction.name,
          'parent_id': _validUuidOrNull(category.parentId),
          'is_active': category.isActive,
          'show_in_dashboard': category.showInDashboard,
          'icon_name': category.iconName,
          'color_value': category.colorValue,
          'created_by': userId,
        })
        .select()
        .single();

    return _categoryFromRow(row);
  }

  Future<CategoryModel> updateCategory(CategoryModel category) async {
    final row = await AppSupabase.client
        .from('categories')
        .update({
          'name': category.name,
          'type': category.type.name,
          'direction': category.direction.name,
          'parent_id': _validUuidOrNull(category.parentId),
          'is_active': category.isActive,
          'show_in_dashboard': category.showInDashboard,
          'icon_name': category.iconName,
          'color_value': category.colorValue,
        })
        .eq('id', category.id)
        .select()
        .single();

    return _categoryFromRow(row);
  }

  Future<void> deleteCategory(String categoryId) async {
    await AppSupabase.client.from('categories').delete().eq('id', categoryId);
  }

  Future<void> archiveCategory(String categoryId) async {
    await AppSupabase.client
        .from('categories')
        .update({
          'is_active': false,
          'show_in_dashboard': false,
        })
        .eq('id', categoryId);
  }

  CategoryModel _categoryFromRow(Map<String, dynamic> row) {
    return CategoryModel(
      id: row['id'] as String,
      name: row['name'] as String? ?? '',
      type: _categoryTypeFromString(row['type'] as String?),
      direction: _categoryDirectionFromString(row['direction'] as String?),
      parentId: row['parent_id'] as String?,
      isActive: row['is_active'] as bool? ?? true,
      showInDashboard: row['show_in_dashboard'] as bool? ?? true,
      iconName: row['icon_name'] as String? ?? 'other',
      colorValue: _toInt(row['color_value']) ?? 4280391411,
      createdAt: _toDateTime(row['created_at']) ?? DateTime.now(),
    );
  }

  CategoryType _categoryTypeFromString(String? value) {
    switch (value) {
      case 'balance':
        return CategoryType.balance;
      case 'debt':
        return CategoryType.debt;
      case 'transaction':
      default:
        return CategoryType.transaction;
    }
  }

  CategoryDirection _categoryDirectionFromString(String? value) {
    switch (value) {
      case 'income':
        return CategoryDirection.income;
      case 'expense':
        return CategoryDirection.expense;
      case 'both':
      default:
        return CategoryDirection.both;
    }
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

  String? _validUuidOrNull(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );

    if (!uuidRegex.hasMatch(value)) {
      return null;
    }

    return value;
  }
}