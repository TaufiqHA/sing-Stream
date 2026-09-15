import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:karaoke_app/core/services/api_user_service.dart';
import 'package:karaoke_app/core/services/storage_service.dart';
import 'package:karaoke_app/models/user_account_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storageService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'auth_token': 'dummy_jwt_token',
    });
    storageService = await StorageService.getInstance();
  });

  group('ApiUserService getUsers Tests', () {
    test('getUsers succeeds with 200 and parses list of users', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/admin/users');
        expect(request.method, 'GET');
        expect(request.headers['Authorization'], 'Bearer dummy_jwt_token');

        return http.Response(
          jsonEncode({
            'data': [
              {
                'id': 1,
                'name': 'Administrator',
                'username': 'admin',
                'email': 'admin@example.com',
                'role': 'admin',
                'created_at': '2026-08-31T00:00:00.000000Z',
              },
              {
                'id': 2,
                'name': 'John Doe',
                'username': 'johndoe',
                'email': 'john@example.com',
                'role': 'user',
                'created_at': '2026-08-31T01:00:00.000000Z',
              },
            ]
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ApiUserService(
        client: mockClient,
        storageService: storageService,
        baseUrl: 'http://127.0.0.1:8000/api',
      );

      final list = await service.getUsers();
      expect(list.length, 2);
      expect(list[0].userid, 1);
      expect(list[0].username, 'admin');
      expect(list[0].name, 'Administrator');
      expect(list[0].isAdmin, isTrue);

      expect(list[1].userid, 2);
      expect(list[1].username, 'johndoe');
      expect(list[1].role, 'user');
      expect(list[1].isAdmin, isFalse);
    });

    test('getUsers appends search and role query parameters', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/admin/users');
        expect(request.url.queryParameters['search'], 'john');
        expect(request.url.queryParameters['role'], 'user');

        return http.Response(
          jsonEncode({
            'data': [
              {
                'id': 2,
                'name': 'John Doe',
                'username': 'johndoe',
                'email': 'john@example.com',
                'role': 'user',
              },
            ]
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ApiUserService(
        client: mockClient,
        storageService: storageService,
        baseUrl: 'http://127.0.0.1:8000/api',
      );

      final list = await service.getUsers(search: 'john', role: 'user');
      expect(list.length, 1);
      expect(list.first.username, 'johndoe');
    });

    test('getUsers throws 403 Forbidden when user is not admin', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'Forbidden. Admin access required.'}),
          403,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ApiUserService(
        client: mockClient,
        storageService: storageService,
        baseUrl: 'http://127.0.0.1:8000/api',
      );

      expect(
        () => service.getUsers(),
        throwsA(predicate((e) => e.toString().contains('Akses ditolak'))),
      );
    });
  });

  group('ApiUserService createUser Tests', () {
    test('createUser succeeds with 201 Created', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/admin/users');
        expect(request.method, 'POST');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['username'], 'operator1');
        expect(body['role'], 'user');
        expect(body['name'], 'Operator Baru');

        return http.Response(
          jsonEncode({
            'message': 'User created successfully',
            'data': {
              'id': 3,
              'name': 'Operator Baru',
              'username': 'operator1',
              'email': 'operator1@example.com',
              'role': 'user',
            }
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ApiUserService(
        client: mockClient,
        storageService: storageService,
        baseUrl: 'http://127.0.0.1:8000/api',
      );

      final result = await service.createUser(
        username: 'operator1',
        password: 'password123',
        role: 'user',
        name: 'Operator Baru',
        email: 'operator1@example.com',
      );

      expect(result.userid, 3);
      expect(result.username, 'operator1');
      expect(result.name, 'Operator Baru');
    });

    test('createUser throws 422 when username already taken', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'message': 'The username has already been taken.',
            'errors': {
              'username': ['The username has already been taken.']
            }
          }),
          422,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ApiUserService(
        client: mockClient,
        storageService: storageService,
        baseUrl: 'http://127.0.0.1:8000/api',
      );

      expect(
        () => service.createUser(
          username: 'admin',
          password: 'password123',
          role: 'admin',
        ),
        throwsA(predicate((e) => e.toString().contains('already been taken'))),
      );
    });
  });

  group('ApiUserService updateUser Tests', () {
    test('updateUser succeeds with 200 OK', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/admin/users/2');
        expect(request.method, 'PUT');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['name'], 'John Doe Updated');
        expect(body['role'], 'admin');

        return http.Response(
          jsonEncode({
            'message': 'User updated successfully',
            'data': {
              'id': 2,
              'name': 'John Doe Updated',
              'username': 'johndoe',
              'email': 'john@example.com',
              'role': 'admin',
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ApiUserService(
        client: mockClient,
        storageService: storageService,
        baseUrl: 'http://127.0.0.1:8000/api',
      );

      final updated = await service.updateUser(
        const UserAccountModel(
          userid: 2,
          username: 'johndoe',
          name: 'John Doe Updated',
          email: 'john@example.com',
          password: '',
          role: 'admin',
        ),
      );

      expect(updated.userid, 2);
      expect(updated.name, 'John Doe Updated');
      expect(updated.role, 'admin');
    });
  });

  group('ApiUserService deleteUser Tests', () {
    test('deleteUser succeeds with 200 OK', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/admin/users/5');
        expect(request.method, 'DELETE');

        return http.Response(
          jsonEncode({'message': 'User deleted successfully'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ApiUserService(
        client: mockClient,
        storageService: storageService,
        baseUrl: 'http://127.0.0.1:8000/api',
      );

      await expectLater(service.deleteUser(5), completes);
    });

    test('deleteUser throws 403 on self-deletion attempt', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/admin/users/1');
        return http.Response(
          jsonEncode({'message': 'You cannot delete your own account'}),
          403,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ApiUserService(
        client: mockClient,
        storageService: storageService,
        baseUrl: 'http://127.0.0.1:8000/api',
      );

      expect(
        () => service.deleteUser(1),
        throwsA(predicate((e) => e.toString().contains('You cannot delete your own account'))),
      );
    });
  });
}
