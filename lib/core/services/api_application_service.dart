import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/application_model.dart';
import '../config/api_config.dart';
import 'application_service.dart';
import 'storage_service.dart';

class ApiApplicationService implements ApplicationService {
  final http.Client _client;
  final StorageService? storageService;
  final String? _customBaseUrl;

  ApiApplicationService({
    http.Client? client,
    this.storageService,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _customBaseUrl = baseUrl;

  String get baseUrl => _customBaseUrl ?? ApiConfig.baseUrl;

  Future<StorageService> _getStorage() async {
    return storageService ?? await StorageService.getInstance();
  }

  Future<String?> _getToken() async {
    final storage = await _getStorage();
    return await storage.getToken();
  }

  @override
  Future<ApplicationModel> getApplicationConfig() async {
    final token = await _getToken();
    final url = Uri.parse(
      token != null && token.isNotEmpty
          ? '$baseUrl/admin/settings'
          : '$baseUrl/settings',
    );

    final headers = {
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    final http.Response response;
    try {
      response = await _client
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 5));
    } on TimeoutException {
      throw Exception('Waktu koneksi habis saat memuat pengaturan aplikasi.');
    } catch (e) {
      throw Exception('Gagal menghubungi server.');
    }

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = _parseResponseBody(response.body);
      final rawData = data['data'];
      if (rawData != null && rawData is Map<String, dynamic>) {
        return ApplicationModel.fromJson(rawData);
      }
      throw Exception('Format respons pengaturan tidak valid.');
    } else if (response.statusCode == 403) {
      throw Exception('Akses ditolak. Diperlukan hak akses administrator.');
    } else if (response.statusCode == 401) {
      throw Exception('Sesi login telah kedaluwarsa.');
    } else {
      throw Exception('Gagal memuat pengaturan aplikasi (Status: ${response.statusCode}).');
    }
  }

  @override
  Future<ApplicationModel> updateApplicationConfig(ApplicationModel config) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesi login tidak ditemukan. Harap login terlebih dahulu.');
    }

    final url = Uri.parse('$baseUrl/admin/settings');
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final body = jsonEncode(config.toJson());

    final http.Response response;
    try {
      response = await _client
          .post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 5));
    } on TimeoutException {
      throw Exception('Waktu koneksi habis saat menyimpan pengaturan aplikasi.');
    } catch (e) {
      throw Exception('Gagal menghubungi server.');
    }

    final Map<String, dynamic> data = _parseResponseBody(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final rawData = data['data'];
      if (rawData != null && rawData is Map<String, dynamic>) {
        return ApplicationModel.fromJson(rawData);
      }
      return config;
    } else if (response.statusCode == 422) {
      final err = _extractErrorMessage(data) ?? 'Validasi gagal.';
      throw Exception(err);
    } else if (response.statusCode == 403) {
      throw Exception('Akses ditolak. Diperlukan hak akses administrator.');
    } else if (response.statusCode == 401) {
      throw Exception('Sesi login telah kedaluwarsa.');
    } else {
      throw Exception('Gagal menyimpan pengaturan aplikasi (Status: ${response.statusCode}).');
    }
  }

  Map<String, dynamic> _parseResponseBody(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  String? _extractErrorMessage(Map<String, dynamic> data) {
    if (data.containsKey('errors') && data['errors'] is Map) {
      final errors = data['errors'] as Map<String, dynamic>;
      for (final key in errors.keys) {
        final val = errors[key];
        if (val is List && val.isNotEmpty) {
          return val.first.toString();
        } else if (val is String) {
          return val;
        }
      }
    }
    if (data.containsKey('message') && data['message'] is String) {
      return data['message'] as String;
    }
    return null;
  }
}
