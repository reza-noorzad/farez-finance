enum CategoryType {
  transaction,
  balance,
  debt,
}

enum CategoryDirection {
  income,
  expense,
  both,
}

class CategoryModel {
  final String id;
  final String name;
  final CategoryType type;
  final CategoryDirection direction;
  final String? parentId;
  final bool isActive;
  final bool showInDashboard;
  final String iconName;
  final int colorValue;
  final DateTime createdAt;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.type,
    required this.direction,
    this.parentId,
    required this.isActive,
    required this.showInDashboard,
    required this.iconName,
    required this.colorValue,
    required this.createdAt,
  });

  CategoryModel copyWith({
    String? id,
    String? name,
    CategoryType? type,
    CategoryDirection? direction,
    String? parentId,
    bool? isActive,
    bool? showInDashboard,
    String? iconName,
    int? colorValue,
    DateTime? createdAt,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      direction: direction ?? this.direction,
      parentId: parentId ?? this.parentId,
      isActive: isActive ?? this.isActive,
      showInDashboard: showInDashboard ?? this.showInDashboard,
      iconName: iconName ?? this.iconName,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] as String,
      name: map['name'] as String,
      type: CategoryType.values.firstWhere(
        (type) => type.name == map['type'],
      ),
      direction: CategoryDirection.values.firstWhere(
        (direction) => direction.name == map['direction'],
      ),
      parentId: map['parent_id'] as String?,
      isActive: map['is_active'] as bool,
      showInDashboard: map['show_in_dashboard'] as bool,
      iconName: map['icon_name'] as String,
      colorValue: map['color_value'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'direction': direction.name,
      'parent_id': parentId,
      'is_active': isActive,
      'show_in_dashboard': showInDashboard,
      'icon_name': iconName,
      'color_value': colorValue,
      'created_at': createdAt.toIso8601String(),
    };
  }
}