/// Konfigurasi terpusat untuk Base URL API backend.
/// Cukup ubah konfigurasi di file ini untuk mengubah endpoint seluruh aplikasi.
class ApiConfig {
  /// Protokol default untuk backend ('http' atau 'https')
  static const String defaultProtocol = 'http';

  /// Host/Domain default untuk backend
  static const String defaultHost = 'tomsikaraoke.xyz';

  /// Path prefix API
  static const String apiPrefix = '/api';

  /// Base URL custom opsional yang dapat diubah saat runtime (misal dari menu pengaturan).
  /// Jika bernilai tidak null/tidak kosong, nilai ini akan diprioritaskan.
  static String? customBaseUrl;

  /// Mendapatkan base URL backend.
  static String get baseUrl {
    final custom = customBaseUrl;
    if (custom != null && custom.isNotEmpty) {
      return custom;
    }
    return '$defaultProtocol://$defaultHost$apiPrefix';
  }
}
