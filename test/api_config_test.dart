import 'package:flutter_test/flutter_test.dart';
import 'package:karaoke_app/core/config/api_config.dart';
import 'package:karaoke_app/core/services/api_application_service.dart';
import 'package:karaoke_app/core/services/api_auth_service.dart';
import 'package:karaoke_app/core/services/api_category_service.dart';
import 'package:karaoke_app/core/services/api_song_service.dart';
import 'package:karaoke_app/core/services/api_user_service.dart';

void main() {
  setUp(() {
    ApiConfig.customBaseUrl = null;
  });

  tearDown(() {
    ApiConfig.customBaseUrl = null;
  });

  group('ApiConfig Tests', () {
    test('ApiConfig.baseUrl returns valid default URL', () {
      final url = ApiConfig.baseUrl;
      expect(url, contains('http://'));
      expect(url, contains('/api'));
    });

    test('ApiConfig.customBaseUrl overrides default baseUrl', () {
      ApiConfig.customBaseUrl = 'https://api.mykaraoke.com/api';
      expect(ApiConfig.baseUrl, 'https://api.mykaraoke.com/api');
    });

    test('ApiAuthService.defaultCustomBaseUrl delegates to ApiConfig.customBaseUrl', () {
      ApiAuthService.defaultCustomBaseUrl = 'http://192.168.1.99:8000/api';
      expect(ApiConfig.customBaseUrl, 'http://192.168.1.99:8000/api');
      expect(ApiConfig.baseUrl, 'http://192.168.1.99:8000/api');

      ApiConfig.customBaseUrl = 'http://10.0.0.1:8000/api';
      expect(ApiAuthService.defaultCustomBaseUrl, 'http://10.0.0.1:8000/api');
    });

    test('All services adopt ApiConfig.baseUrl by default', () {
      ApiConfig.customBaseUrl = 'http://192.168.1.10:8000/api';

      final authService = ApiAuthService();
      final categoryService = ApiCategoryService();
      final songService = ApiSongService();
      final userService = ApiUserService();
      final appService = ApiApplicationService();

      expect(authService.baseUrl, 'http://192.168.1.10:8000/api');
      expect(categoryService.baseUrl, 'http://192.168.1.10:8000/api');
      expect(songService.baseUrl, 'http://192.168.1.10:8000/api');
      expect(userService.baseUrl, 'http://192.168.1.10:8000/api');
      expect(appService.baseUrl, 'http://192.168.1.10:8000/api');
    });

    test('Individual service custom baseUrl overrides ApiConfig.baseUrl', () {
      ApiConfig.customBaseUrl = 'http://192.168.1.10:8000/api';

      final authService = ApiAuthService(baseUrl: 'http://custom-auth:8000/api');
      final categoryService = ApiCategoryService(baseUrl: 'http://custom-cat:8000/api');
      final songService = ApiSongService(baseUrl: 'http://custom-song:8000/api');
      final userService = ApiUserService(baseUrl: 'http://custom-user:8000/api');
      final appService = ApiApplicationService(baseUrl: 'http://custom-app:8000/api');

      expect(authService.baseUrl, 'http://custom-auth:8000/api');
      expect(categoryService.baseUrl, 'http://custom-cat:8000/api');
      expect(songService.baseUrl, 'http://custom-song:8000/api');
      expect(userService.baseUrl, 'http://custom-user:8000/api');
      expect(appService.baseUrl, 'http://custom-app:8000/api');
    });
  });
}
