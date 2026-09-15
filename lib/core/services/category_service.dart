import '../../models/category_model.dart';

abstract class CategoryService {
  Future<List<CategoryModel>> getCategories({String? search});
  Future<CategoryModel> getCategory(int id);
  Future<CategoryModel> createCategory(String name);
  Future<CategoryModel> updateCategory(dynamic id, String newName);
  Future<bool> deleteCategory(dynamic id);
}
