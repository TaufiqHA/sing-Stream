import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../../models/nada_model.dart';
import 'nada_service.dart';
import 'storage_service.dart';

class ApiNadaService implements NadaService {
  final http.Client _client;
  final StorageService? storageService;
  final String? _customBaseUrl;

  ApiNadaService({
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

  Map<String, dynamic> _parseResponseBody(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {'data': decoded};
    } catch (_) {
      return {};
    }
  }

  @override
  Future<List<NadaModel>> getNadas({String? search}) async {
    final query = (search != null && search.trim().isNotEmpty)
        ? '?search=${Uri.encodeComponent(search.trim())}'
        : '';
    final url = Uri.parse('$baseUrl/admin/nadas$query');

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
              .map((item) => NadaModel.fromJson(item as Map<String, dynamic>))
              .toList();
        }
        return [];
      } else {
        throw Exception('Gagal memuat nada (${response.statusCode}).');
      }
    } on TimeoutException {
      throw Exception('Waktu koneksi habis saat memuat nada.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Gagal menghubungi server.');
    }
  }

  @override
  Future<NadaModel> getNada(int id) async {
    final url = Uri.parse('$baseUrl/admin/nadas/$id');
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
        return NadaModel.fromJson(data['data'] as Map<String, dynamic>);
      } else if (response.statusCode == 404) {
        throw Exception('Nada tidak ditemukan.');
      } else {
        throw Exception('Gagal memuat data nada (${response.statusCode}).');
      }
    } on TimeoutException {
      throw Exception('Waktu koneksi habis saat memuat data nada.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Gagal menghubungi server.');
    }
  }

  @override
  Future<NadaModel> createNada(String nada) async {
    final url = Uri.parse('$baseUrl/admin/nadas');
    try {
      final token = await _getToken();
      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final body = jsonEncode({'nada': nada.trim()});

      final response = await _client
          .post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 201 || response.statusCode == 200) {
        final Map<String, dynamic> data = _parseResponseBody(response.body);
        return NadaModel.fromJson(data['data'] as Map<String, dynamic>);
      } else if (response.statusCode == 422) {
        final Map<String, dynamic> data = _parseResponseBody(response.body);
        String msg = data['message'] ?? 'Data tidak valid.';
        if (data['errors'] is Map && (data['errors'] as Map)['nada'] is List) {
          msg = ((data['errors'] as Map)['nada'] as List).join(', ');
        }
        throw Exception(msg);
      } else {
        throw Exception('Gagal menambahkan nada (${response.statusCode}).');
      }
    } on TimeoutException {
      throw Exception('Waktu koneksi habis saat menambahkan nada.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Gagal menghubungi server.');
    }
  }

  @override
  Future<NadaModel> updateNada(int id, String newNada) async {
    final url = Uri.parse('$baseUrl/admin/nadas/$id');
    try {
      final token = await _getToken();
      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final body = jsonEncode({'nada': newNada.trim()});

      final response = await _client
          .put(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = _parseResponseBody(response.body);
        return NadaModel.fromJson(data['data'] as Map<String, dynamic>);
      } else if (response.statusCode == 422) {
        final Map<String, dynamic> data = _parseResponseBody(response.body);
        String msg = data['message'] ?? 'Data tidak valid.';
        if (data['errors'] is Map && (data['errors'] as Map)['nada'] is List) {
          msg = ((data['errors'] as Map)['nada'] as List).join(', ');
        }
        throw Exception(msg);
      } else if (response.statusCode == 404) {
        throw Exception('Nada tidak ditemukan.');
      } else {
        throw Exception('Gagal memperbarui nada (${response.statusCode}).');
      }
    } on TimeoutException {
      throw Exception('Waktu koneksi habis saat memperbarui nada.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Gagal menghubungi server.');
    }
  }

  @override
  Future<bool> deleteNada(int id) async {
    final url = Uri.parse('$baseUrl/admin/nadas/$id');
    try {
      final token = await _getToken();
      final headers = {
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final response = await _client
          .delete(url, headers: headers)
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      } else if (response.statusCode == 422) {
        final Map<String, dynamic> data = _parseResponseBody(response.body);
        throw Exception(data['message'] ?? 'Nada tidak dapat dihapus karena masih digunakan.');
      } else if (response.statusCode == 404) {
        throw Exception('Nada tidak ditemukan.');
      } else {
        throw Exception('Gagal menghapus nada (${response.statusCode}).');
      }
    } on TimeoutException {
      throw Exception('Waktu koneksi habis saat menghapus nada.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Gagal menghubungi server.');
    }
  }
}
