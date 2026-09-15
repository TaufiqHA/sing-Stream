import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_model.dart';

class StorageService {
  static const String _keyToken = 'auth_token';
  static const String _keyUser = 'user_data';
  static const String _keyIsLoggedIn = 'is_logged_in';

  static StorageService? _instance;
  static SharedPreferences? _prefs;

  StorageService();

  static Future<StorageService> getInstance() async {
    _instance ??= StorageService();
    _prefs ??= await SharedPreferences.getInstance();
    return _instance!;
  }

  Future<bool> saveAuthSession({
    required String token,
    required UserModel user,
  }) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
    await prefs.setString(_keyUser, jsonEncode(user.toJson()));
    await prefs.setBool(_keyIsLoggedIn, true);
    return true;
  }

  Future<bool> saveUser(UserModel user) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setString(_keyUser, jsonEncode(user.toJson()));
    return true;
  }

  Future<String?> getToken() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  Future<bool> saveToken(String token) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    return await prefs.setString(_keyToken, token);
  }

  Future<bool> deleteToken() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    return await prefs.remove(_keyToken);
  }

  Future<UserModel?> getUser() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final userJson = prefs.getString(_keyUser);
    if (userJson == null || userJson.isEmpty) return null;
    try {
      final Map<String, dynamic> map = jsonDecode(userJson) as Map<String, dynamic>;
      return UserModel.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<bool> isLoggedIn() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final isLogged = prefs.getBool(_keyIsLoggedIn) ?? false;
    final token = prefs.getString(_keyToken);
    return isLogged && token != null && token.isNotEmpty;
  }

  Future<bool> clearSession() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUser);
    await prefs.remove(_keyIsLoggedIn);
    return true;
  }
}
