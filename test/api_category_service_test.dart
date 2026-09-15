import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:karaoke_app/core/services/api_category_service.dart';
import 'package:karaoke_app/core/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storageService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storageService = await StorageService.getInstance();
  });

  group('ApiCategoryService getCategories Tests', () {
    test('getCategories succeeds with 200 without search', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/categories');
        expect(request.method, 'GET');

        return http.Response(
          jsonEncode({
            'data': [
              {
                'songcategoryid': 1,
                'songcategoryname': 'Pop Indonesia',
                'created_at': '2026-08-30T07:28:55.000000Z',
                'updated_at': '2026-08-30T07:28:55.000000Z',
              },
              {
                'songcategoryid': 2,
                'songcategoryname': 'Dangdut & Koplo',
                'created_at': '2026-08-30T07:28:55.000000Z',
                'updated_at': '2026-08-30T07:28:55.000000Z',
              },
            ]
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ApiCategoryService(
        client: mockClient,
        storageService: storageService,
        baseUrl: 'http://127.0.0.1:8000/api',
      );

      final list = await service.getCategories();
      expect(list.length, 2);
      expect(list[0].songcategoryid, 1);
      expect(list[0].name, 'Pop Indonesia');
      expect(list[1].songcategoryid, 2);
      expect(list[1].name, 'Dangdut & Koplo');
    });

    test('getCategories appends search query parameter', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/categories');
        expect(request.url.queryParameters['search'], 'Rock');

        return http.Response(
          jsonEncode({
            'data': [
              {
                'songcategoryid': 3,
                'songcategoryname': 'Rock & Metal',
              },
            ]
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ApiCategoryService(
        client: mockClient,
        storageService: storageService,
        baseUrl: 'http://127.0.0.1:8000/api',
      );

      final list = await service.getCategories(search: 'Rock');
      expect(list.length, 1);
      expect(list.first.name, 'Rock & Metal');
    });
  });

  group('ApiCategoryService getCategory (Detail) Tests', () {
    test('getCategory succeeds with 200', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/categories/5');
        expect(request.method, 'GET');

        return http.Response(
          jsonEncode({
            'data': {
              'songcategoryid': 5,
              'songcategoryname': 'K-Pop',
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ApiCategoryService(
        client: mockClient,
        storageService: storageService,
        baseUrl: 'http://127.0.0.1:8000/api',
      );

      final cat = await service.getCategory(5);
      expect(cat.songcategoryid, 5);
      expect(cat.name, 'K-Pop');
    });
  });

  group('ApiCategoryService createCategory Tests', () {
    test('createCategory sends POST with Bearer token and returns created category', () async {
      await storageService.saveToken('admin_token_xyz');

      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/categories');
        expect(request.method, 'POST');
        expect(request.headers['Authorization'], 'Bearer admin_token_xyz');

        final body = jsonDecode(request.body);
        expect(body['songcategoryname'], 'Jazz & Blues');

        return http.Response(
          jsonEncode({
            'message': 'Category created successfully',
            'data': {
              'songcategoryid': 10,
              'songcategoryname': 'Jazz & Blues',
            }
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ApiCategoryService(
        client: mockClient,
        storageService: storageService,
        baseUrl: 'http://127.0.0.1:8000/api',
      );

      final created = await service.createCategory('Jazz & Blues');
      expect(created.songcategoryid, 10);
      expect(created.name, 'Jazz & Blues');
    });

    test('createCategory throws on 422 duplicate validation', () async {
      await storageService.saveToken('admin_token_xyz');

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'message': 'The songcategoryname has already been taken.',
            'errors': {
              'songcategoryname': ['The songcategoryname has already been taken.']
            }
          }),
          422,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ApiCategoryService(
        client: mockClient,
        storageService: storageService,
        baseUrl: 'http://127.0.0.1:8000/api',
      );

      expect(
        () => service.createCategory('Pop Indonesia'),
        throwsA(predicate((e) => e.toString().contains('The songcategoryname has already been taken'))),
      );
    });
  });

  group('ApiCategoryService updateCategory Tests', () {
    test('updateCategory sends PUT with Bearer token and returns updated category', () async {
      await storageService.saveToken('admin_token_xyz');

      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/categories/10');
        expect(request.method, 'PUT');
        expect(request.headers['Authorization'], 'Bearer admin_token_xyz');

        final body = jsonDecode(request.body);
        expect(body['songcategoryname'], 'Smooth Jazz');

        return http.Response(
          jsonEncode({
            'message': 'Category updated successfully',
            'data': {
              'songcategoryid': 10,
              'songcategoryname': 'Smooth Jazz',
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ApiCategoryService(
        client: mockClient,
        storageService: storageService,
        baseUrl: 'http://127.0.0.1:8000/api',
      );

      final updated = await service.updateCategory(10, 'Smooth Jazz');
      expect(updated.songcategoryid, 10);
      expect(updated.name, 'Smooth Jazz');
    });

    test('updateCategory throws on 404 not found', () async {
      await storageService.saveToken('admin_token_xyz');

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'Not Found'}),
          404,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ApiCategoryService(
        client: mockClient,
        storageService: storageService,
        baseUrl: 'http://127.0.0.1:8000/api',
      );

      expect(
        () => service.updateCategory(999, 'Non Existent'),
        throwsA(predicate((e) => e.toString().contains('Kategori tidak ditemukan'))),
      );
    });
  });

  group('ApiCategoryService deleteCategory Tests', () {
    test('deleteCategory sends DELETE with Bearer token and returns true', () async {
      await storageService.saveToken('admin_token_xyz');

      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/categories/10');
        expect(request.method, 'DELETE');
        expect(request.headers['Authorization'], 'Bearer admin_token_xyz');

        return http.Response(
          jsonEncode({'message': 'Category deleted successfully'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ApiCategoryService(
        client: mockClient,
        storageService: storageService,
        baseUrl: 'http://127.0.0.1:8000/api',
      );

      final result = await service.deleteCategory(10);
      expect(result, isTrue);
    });

    test('deleteCategory throws on 404 not found', () async {
      await storageService.saveToken('admin_token_xyz');

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'Not Found'}),
          404,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ApiCategoryService(
        client: mockClient,
        storageService: storageService,
        baseUrl: 'http://127.0.0.1:8000/api',
      );

      expect(
        () => service.deleteCategory(999),
        throwsA(predicate((e) => e.toString().contains('Kategori tidak ditemukan'))),
      );
    });
  });
}
