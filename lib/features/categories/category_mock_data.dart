import '../../shared/models/category_model.dart';

class CategoryMockData {
  // کاربر خودش دسته‌بندی‌ها را می‌سازد.
  static final List<CategoryModel> categories = [];

  static List<CategoryModel> get activeCategories {
    return categories.where((category) => category.isActive).toList();
  }

  static List<CategoryModel> getByType(CategoryType type) {
    return activeCategories.where((category) {
      return category.type == type;
    }).toList();
  }

  static List<CategoryModel> getIncomeCategories() {
    return activeCategories.where((category) {
      return category.direction == CategoryDirection.income ||
          category.direction == CategoryDirection.both;
    }).toList();
  }

  static List<CategoryModel> getExpenseCategories() {
    return activeCategories.where((category) {
      return category.direction == CategoryDirection.expense ||
          category.direction == CategoryDirection.both;
    }).toList();
  }

  static List<CategoryModel> get dashboardCategories {
    return activeCategories.where((category) {
      return category.showInDashboard;
    }).toList();
  }

  static CategoryModel? findById(String id) {
    try {
      return categories.firstWhere((category) => category.id == id);
    } catch (_) {
      return null;
    }
  }

  static CategoryModel? findByName(String name) {
    try {
      return categories.firstWhere((category) {
        return category.name.toLowerCase() == name.toLowerCase();
      });
    } catch (_) {
      return null;
    }
  }
}