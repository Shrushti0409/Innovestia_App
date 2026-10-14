import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  Future<void> saveSession(String token, String userJson) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userKey, value: userJson);
  }

  Future<String?> readToken() => _storage.read(key: _tokenKey);
  Future<String?> readUser() => _storage.read(key: _userKey);
  Future<void> clearSession() => _storage.deleteAll();
}
