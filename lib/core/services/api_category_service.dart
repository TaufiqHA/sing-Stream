import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../../models/category_model.dart';
import 'category_service.dart';
import 'storage_service.dart';

class ApiCategoryService implements CategoryService {
  final http.Client _client;
  final StorageService? storageService;
  final String? _customBaseUrl;

  ApiCategoryService({
    http.Client? client,
    this.storageService,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _customBaseUrl = baseUrl;

  String get baseUrl {
    final custom = _customBaseUrl;
    if (custom != null && custom.isNotEmpty) {
      return custom;
    }
    return ApiConfig.baseUrl;
  }

  Future<StorageService> _getStorage() async {
    return storageService ?? await StorageService.getInstance();
  }

  Future<String?> _getToken() async {
    final storage = await _getStorage();
    return await storage.getToken();
  }

  @override
  Future<List<CategoryModel>> getCategories({String? search}) async {
    final query = (search != null && search.trim().isNotEmpty)
        ? '?search=${Uri.encodeComponent(search.trim())}'
        : '';
    final url = Uri.parse('$baseUrl/categories$query');

    try {
      final token = await _getToken();
      final headers = {
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final response = await _client
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = _parseResponseBody(response.body);
        final rawList = data['data'];
        if (rawList is List) {
          return rawList
              .map((item) => CategoryModel.fromJson(item as Map<String, dynamic>))
              .toList();
        }
        return [];
      } else {
        throw Exception('Gagal memuat kategori (${response.statusCode}).');
      }
    } on TimeoutException {
      throw Exception('Waktu koneksi habis saat memuat kategori.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Gagal menghubungi server.');
    }
  }

  @override
  Future<CategoryModel> getCategory(int id) async {
    final url = Uri.parse('$baseUrl/categories/$id');
    try {
      final token = await _getToken();
      final headers = {
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final response = await _client
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = _parseResponseBody(response.body);
        return CategoryModel.fromJson(data['data'] as Map<String, dynamic>);
      } else if (response.statusCode == 404) {
        throw Exception('Kategori tidak ditemukan.');
      } else {
        throw Exception('Gagal memuat kategori (${response.statusCode}).');
      }
    } on TimeoutException {
      throw Exception('Waktu koneksi habis saat memuat kategori.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Gagal menghubungi server.');
    }
  }

  @override
  Future<CategoryModel> createCategory(String name) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesi login tidak ditemukan. Harap login terlebih dahulu.');
    }

    final url = Uri.parse('$baseUrl/categories');
    try {
      final response = await _client
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'songcategoryname': name.trim(),
            }),
          )
          .timeout(const Duration(seconds: 8));

      final Map<String, dynamic> data = _parseResponseBody(response.body);

      if (response.statusCode == 201) {
        return CategoryModel.fromJson(data['data'] as Map<String, dynamic>);
      } else if (response.statusCode == 422) {
        String errorMsg = data['message'] as String? ?? 'Validasi gagal.';
        if (data['errors'] is Map<String, dynamic>) {
          final errors = data['errors'] as Map<String, dynamic>;
          if (errors.isNotEmpty &&
              errors.values.first is List &&
              (errors.values.first as List).isNotEmpty) {
            errorMsg = (errors.values.first as List).first.toString();
          }
        }
        throw Exception(errorMsg);
      } else if (response.statusCode == 401) {
        final storage = await _getStorage();
        await storage.clearSession();
        throw Exception('Sesi login telah kedaluwarsa.');
      } else {
        throw Exception(
          data['message'] as String? ??
              'Gagal menambahkan kategori (${response.statusCode}).',
        );
      }
    } on TimeoutException {
      throw Exception('Waktu koneksi habis saat menambahkan kategori.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Gagal menghubungi server.');
    }
  }

  @override
  Future<CategoryModel> updateCategory(dynamic id, String newName) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesi login tidak ditemukan. Harap login terlebih dahulu.');
    }

    final url = Uri.parse('$baseUrl/categories/$id');
    try {
      final response = await _client
          .put(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'songcategoryname': newName.trim(),
            }),
          )
          .timeout(const Duration(seconds: 8));

      final Map<String, dynamic> data = _parseResponseBody(response.body);

      if (response.statusCode == 200) {
        return CategoryModel.fromJson(data['data'] as Map<String, dynamic>);
      } else if (response.statusCode == 422) {
        String errorMsg = data['message'] as String? ?? 'Validasi gagal.';
        if (data['errors'] is Map<String, dynamic>) {
          final errors = data['errors'] as Map<String, dynamic>;
          if (errors.isNotEmpty &&
              errors.values.first is List &&
              (errors.values.first as List).isNotEmpty) {
            errorMsg = (errors.values.first as List).first.toString();
          }
        }
        throw Exception(errorMsg);
      } else if (response.statusCode == 404) {
        throw Exception('Kategori tidak ditemukan.');
      } else if (response.statusCode == 401) {
        final storage = await _getStorage();
        await storage.clearSession();
        throw Exception('Sesi login telah kedaluwarsa.');
      } else {
        throw Exception(
          data['message'] as String? ??
              'Gagal memperbarui kategori (${response.statusCode}).',
        );
      }
    } on TimeoutException {
      throw Exception('Waktu koneksi habis saat memperbarui kategori.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Gagal menghubungi server.');
    }
  }

  @override
  Future<bool> deleteCategory(dynamic id) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesi login tidak ditemukan. Harap login terlebih dahulu.');
    }

    final url = Uri.parse('$baseUrl/categories/$id');
    try {
      final response = await _client
          .delete(
            url,
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 404) {
        throw Exception('Kategori tidak ditemukan.');
      } else if (response.statusCode == 401) {
        final storage = await _getStorage();
        await storage.clearSession();
        throw Exception('Sesi login telah kedaluwarsa.');
      } else {
        final Map<String, dynamic> data = _parseResponseBody(response.body);
        throw Exception(
          data['message'] as String? ??
              'Gagal menghapus kategori (${response.statusCode}).',
        );
      }
    } on TimeoutException {
      throw Exception('Waktu koneksi habis saat menghapus kategori.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Gagal menghubungi server.');
    }
  }

  Map<String, dynamic> _parseResponseBody(String body) {
    if (body.isEmpty) return {};
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}
    return {};
  }
}
