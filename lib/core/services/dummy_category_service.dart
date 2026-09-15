import 'dart:async';
import '../../models/category_model.dart';
import 'category_service.dart';

class DummyCategoryService implements CategoryService {
  late final List<CategoryModel> _categories;

  final List<CategoryModel> _defaultCategories = [
    CategoryModel(
      songcategoryid: 1,
      songcategoryname: 'Pop Indonesia',
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    ),
    CategoryModel(
      songcategoryid: 2,
      songcategoryname: 'Dangdut & Koplo',
      createdAt: DateTime.now().subtract(const Duration(days: 25)),
    ),
    CategoryModel(
      songcategoryid: 3,
      songcategoryname: 'Rock & Metal',
      createdAt: DateTime.now().subtract(const Duration(days: 20)),
    ),
    CategoryModel(
      songcategoryid: 4,
      songcategoryname: 'Barat / International',
      createdAt: DateTime.now().subtract(const Duration(days: 15)),
    ),
    CategoryModel(
      songcategoryid: 5,
      songcategoryname: 'K-Pop',
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
    ),
    CategoryModel(
      songcategoryid: 6,
      songcategoryname: 'Anime & J-Pop',
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
  ];

  DummyCategoryService([List<CategoryModel>? initialCategories]) {
    _categories = initialCategories != null
        ? List.from(initialCategories)
        : List.from(_defaultCategories);
  }

  @override
  Future<List<CategoryModel>> getCategories({String? search}) async {
    List<CategoryModel> list = List.from(_categories);

    if (search != null && search.trim().isNotEmpty) {
      final query = search.trim().toLowerCase();
      list = list.where((c) => c.name.toLowerCase().contains(query)).toList();
    }

    return list;
  }

  @override
  Future<CategoryModel> getCategory(int id) async {
    return _categories.firstWhere(
      (c) => c.songcategoryid == id || c.id == id.toString(),
      orElse: () => throw Exception('Kategori tidak ditemukan'),
    );
  }

  @override
  Future<CategoryModel> createCategory(String name) async {
    final newId = DateTime.now().millisecondsSinceEpoch % 100000;
    final newCategory = CategoryModel(
      songcategoryid: newId,
      songcategoryname: name.trim(),
      createdAt: DateTime.now(),
    );

    _categories.insert(0, newCategory);
    return newCategory;
  }

  @override
  Future<CategoryModel> updateCategory(dynamic id, String newName) async {
    final strId = id.toString();
    final index = _categories.indexWhere((c) => c.id == strId || c.songcategoryid.toString() == strId);

    if (index == -1) {
      throw Exception('Kategori tidak ditemukan');
    }

    final updated = _categories[index].copyWith(name: newName.trim());
    _categories[index] = updated;
    return updated;
  }

  @override
  Future<bool> deleteCategory(dynamic id) async {
    final strId = id.toString();
    final initialLength = _categories.length;
    _categories.removeWhere((c) => c.id == strId || c.songcategoryid.toString() == strId);
    return _categories.length < initialLength;
  }
}
