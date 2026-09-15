import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:karaoke_app/core/services/api_application_service.dart';
import 'package:karaoke_app/core/services/storage_service.dart';
import 'package:karaoke_app/models/application_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storageService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'auth_token': 'dummy_jwt_token',
    });
    storageService = await StorageService.getInstance();
    await storageService.saveToken('dummy_jwt_token');
  });

  group('ApiApplicationService getApplicationConfig Tests', () {
    test('getApplicationConfig succeeds with 200 and parses settings', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/admin/settings');
        expect(request.method, 'GET');
        expect(request.headers['Authorization'], 'Bearer dummy_jwt_token');

        return http.Response(
          jsonEncode({
            'data': {
              'applicationid': 1,
              'applicationcompany': 'PT Karaoke Digital Nusantara',
              'applicationname': 'Karaoke Family Station',
              'applicationads1': 'https://storage.example.com/ads/banner1.jpg',
              'applicationads2': 'https://storage.example.com/ads/banner2.jpg',
              'applicationadsactive': 'Y',
              'applicationadsbottom': 'https://storage.example.com/ads/banner_bottom.jpg',
              'applicationadsbottomactive': 'Y',
              'created_at': '2026-08-31T17:00:00.000000Z',
              'updated_at': '2026-08-31T17:00:00.000000Z',
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ApiApplicationService(
        client: mockClient,
        storageService: storageService,
        baseUrl: 'http://127.0.0.1:8000/api',
      );

      final config = await service.getApplicationConfig();
      expect(config.applicationid, 1);
      expect(config.applicationcompany, 'PT Karaoke Digital Nusantara');
      expect(config.applicationname, 'Karaoke Family Station');
      expect(config.applicationads1, 'https://storage.example.com/ads/banner1.jpg');
      expect(config.isAdsActive, isTrue);
      expect(config.isAdsBottomActive, isTrue);
    });

    test('getApplicationConfig throws Exception when data is null', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'data': null}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ApiApplicationService(
        client: mockClient,
        storageService: storageService,
        baseUrl: 'http://127.0.0.1:8000/api',
      );

      expect(() => service.getApplicationConfig(), throwsA(isA<Exception>()));
    });

    test('getApplicationConfig uses public /settings if unauthenticated', () async {
      await storageService.deleteToken();

      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/settings');
        expect(request.method, 'GET');
        expect(request.headers.containsKey('Authorization'), isFalse);

        return http.Response(
          jsonEncode({
            'data': {
              'applicationid': 1,
              'applicationcompany': 'Public Company',
              'applicationname': 'Public Karaoke App',
              'applicationadsactive': 'Y',
              'applicationadsbottomactive': 'Y',
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ApiApplicationService(
        client: mockClient,
        storageService: storageService,
        baseUrl: 'http://127.0.0.1:8000/api',
      );

      final config = await service.getApplicationConfig();
      expect(config.applicationcompany, 'Public Company');
      expect(config.applicationname, 'Public Karaoke App');
    });
  });

  group('ApiApplicationService updateApplicationConfig Tests', () {
    test('updateApplicationConfig succeeds with 200 and returns updated config', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/admin/settings');
        expect(request.method, 'POST');
        expect(request.headers['Authorization'], 'Bearer dummy_jwt_token');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['applicationcompany'], 'PT Karaoke Bintang Lima');
        expect(body['applicationname'], 'Karaoke Super App');

        return http.Response(
          jsonEncode({
            'message': 'Settings updated successfully',
            'data': {
              'applicationid': 1,
              'applicationcompany': 'PT Karaoke Bintang Lima',
              'applicationname': 'Karaoke Super App',
              'applicationadsactive': 'N',
              'applicationadsbottomactive': 'Y',
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ApiApplicationService(
        client: mockClient,
        storageService: storageService,
        baseUrl: 'http://127.0.0.1:8000/api',
      );

      const toUpdate = ApplicationModel(
        applicationid: 1,
        applicationcompany: 'PT Karaoke Bintang Lima',
        applicationname: 'Karaoke Super App',
        applicationadsactive: 'N',
        applicationadsbottomactive: 'Y',
      );

      final result = await service.updateApplicationConfig(toUpdate);
      expect(result.applicationcompany, 'PT Karaoke Bintang Lima');
      expect(result.applicationname, 'Karaoke Super App');
      expect(result.isAdsActive, isFalse);
    });

    test('updateApplicationConfig throws Exception on 422 validation error', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'message': 'The applicationcompany field must not be greater than 100 characters.',
            'errors': {
              'applicationcompany': ['The applicationcompany field must not be greater than 100 characters.']
            }
          }),
          422,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ApiApplicationService(
        client: mockClient,
        storageService: storageService,
        baseUrl: 'http://127.0.0.1:8000/api',
      );

      const toUpdate = ApplicationModel(
        applicationid: 1,
        applicationcompany: 'Too Long Company Name...',
        applicationname: 'Karaoke App',
      );

      expect(
        () => service.updateApplicationConfig(toUpdate),
        throwsA(predicate((e) => e.toString().contains('must not be greater than 100 characters'))),
      );
    });

    test('updateApplicationConfig throws Exception on 403 Forbidden', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'Forbidden. Admin access required.'}),
          403,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ApiApplicationService(
        client: mockClient,
        storageService: storageService,
        baseUrl: 'http://127.0.0.1:8000/api',
      );

      const toUpdate = ApplicationModel(
        applicationid: 1,
        applicationcompany: 'PT Karaoke',
        applicationname: 'Karaoke App',
      );

      expect(
        () => service.updateApplicationConfig(toUpdate),
        throwsA(predicate((e) => e.toString().contains('Akses ditolak'))),
      );
    });
  });
}
