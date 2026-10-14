import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'api_service.dart';
import 'storage_service.dart';

class AuthService extends ChangeNotifier {
  AuthService(this._storage, {ApiService? api})
    : _api = api ?? ApiService(_storage);
  final StorageService _storage;
  final ApiService _api;
  ApiService get api => _api;
  User? _user;
  User? get user => _user;
  bool get isAuthenticated => _user != null;
  Future<void> restoreSession() async {
    final token = await _storage.readToken();
    if (token != null) {
      try {
        final result = await _api.get('/auth/me');
        final data = result['data'] as Map<String, dynamic>;
        _user = User.fromJson(data['user'] as Map<String, dynamic>);
        await _storage.saveSession(token, jsonEncode(_user!.toJson()));
      } catch (error) {
        if (error is ApiException && error.statusCode == 401) {
          await _storage.clearSession();
        }
        _user = null;
      }
    }
    notifyListeners();
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String? phone,
  }) async {
    final result = await _api.post(
      '/auth/register',
      body: {
        'name': name,
        'email': email.trim().toLowerCase(),
        'password': password,
        'phone': phone,
        'role': role.apiValue,
      },
    );
    await _acceptSession(result);
  }

  Future<void> login(String email, String password) async {
    final result = await _api.post(
      '/auth/login',
      body: {'email': email.trim().toLowerCase(), 'password': password},
    );
    await _acceptSession(result);
  }

  Future<void> _acceptSession(Map<String, dynamic> result) async {
    final data = result['data'];
    if (data is! Map<String, dynamic> ||
        data['token'] is! String ||
        data['user'] is! Map<String, dynamic>) {
      throw const ApiException(
        'The server returned an invalid sign-in response.',
      );
    }
    _user = User.fromJson(data['user'] as Map<String, dynamic>);
    await _storage.saveSession(
      data['token'] as String,
      jsonEncode(_user!.toJson()),
    );
    notifyListeners();
  }

  Future<void> logout() async {
    await _storage.clearSession();
    _user = null;
    notifyListeners();
  }
}
