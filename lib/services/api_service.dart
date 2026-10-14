import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';
import 'storage_service.dart';

class ApiException implements Exception {
  const ApiException(this.message, [this.statusCode, this.retryAfterSeconds]);
  final String message;
  final int? statusCode;
  final int? retryAfterSeconds;
  bool get isRateLimit =>
      statusCode == 429 ||
      message.toLowerCase().contains('too many attempts') ||
      message.toLowerCase().contains('too many requests') ||
      message.toLowerCase().contains('rate limit');
  @override
  String toString() => message;
}

class ApiService {
  ApiService(this._storage, {http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? AppConstants.apiBaseUrl;
  final StorageService _storage;
  final http.Client _client;
  final String _baseUrl;
  Future<Map<String, dynamic>> get(String path) => _request('GET', path);
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) => _request('POST', path, body: body);
  Future<Map<String, dynamic>> put(String path, {Map<String, dynamic>? body}) =>
      _request('PUT', path, body: body);
  Future<Map<String, dynamic>> delete(String path) => _request('DELETE', path);
  Future<Map<String, dynamic>> putBytes(String path, Uint8List bytes) async {
    final token = await _storage.readToken();
    final uri = Uri.parse('${_baseUrl.replaceFirst(RegExp(r'/+$'), '')}$path');
    final response = await _client
        .put(
          uri,
          headers: {
            'Content-Type': 'application/pdf',
            if (uri.host.toLowerCase().contains('ngrok'))
              'ngrok-skip-browser-warning': 'true',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: bytes,
        )
        .timeout(AppConstants.requestTimeout);
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300)
      throw ApiException(
        decoded is Map && decoded['message'] is String
            ? decoded['message'] as String
            : 'Upload failed (${response.statusCode}).',
        response.statusCode,
      );
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  }

  Future<Uint8List> getBytes(String path) async {
    final token = await _storage.readToken();
    final uri = Uri.parse('${_baseUrl.replaceFirst(RegExp(r'/+$'), '')}$path');
    final response = await _client
        .get(
          uri,
          headers: {
            if (uri.host.toLowerCase().contains('ngrok'))
              'ngrok-skip-browser-warning': 'true',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        )
        .timeout(AppConstants.requestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300)
      throw ApiException(
        'Download failed (${response.statusCode}).',
        response.statusCode,
      );
    return response.bodyBytes;
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final token = await _storage.readToken();
    final baseUrl = _baseUrl.replaceFirst(RegExp(r'/+$'), '');
    final route = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$baseUrl$route');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (uri.host.toLowerCase().contains('ngrok'))
        'ngrok-skip-browser-warning': 'true',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    if (kDebugMode) {
      debugPrint('$method ${uri.scheme}://${uri.host}:${uri.port}${uri.path}');
    }
    try {
      final response = await switch (method) {
        'GET' => _client.get(uri, headers: headers),
        'POST' => _client.post(
          uri,
          headers: headers,
          body: jsonEncode(body ?? {}),
        ),
        'PUT' => _client.put(
          uri,
          headers: headers,
          body: jsonEncode(body ?? {}),
        ),
        _ => _client.delete(uri, headers: headers),
      }.timeout(AppConstants.requestTimeout);
      if (kDebugMode) debugPrint('Status: ${response.statusCode}');
      final responseText = response.body.toLowerCase();
      if (responseText.contains('you are about to visit') &&
          responseText.contains('ngrok')) {
        throw ApiException(
          'ngrok returned its browser-warning page. Check that the API request includes the ngrok skip header and that the tunnel URL is current.',
          response.statusCode,
        );
      }
      Map<String, dynamic> data;
      try {
        final decoded = response.body.isEmpty
            ? <String, dynamic>{}
            : jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Expected a JSON object');
        }
        data = decoded;
      } on FormatException {
        throw ApiException(
          response.statusCode >= 200 && response.statusCode < 300
              ? 'The server returned an unreadable response.'
              : 'The server returned an error (${response.statusCode}).',
          response.statusCode,
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final serverMessage = data['message'];
        final message =
            serverMessage is String && serverMessage.trim().isNotEmpty
            ? serverMessage
            : 'The server returned HTTP ${response.statusCode} for ${uri.path}.';
        throw ApiException(
          message,
          response.statusCode,
          _retryAfterSeconds(response.headers['retry-after']),
        );
      }
      return data;
    } on SocketException catch (error) {
      final reason = error.osError?.message ?? error.message;
      if (kDebugMode) {
        debugPrint(
          'SocketException for ${uri.host}:${uri.port}${uri.path} '
          '(OS ${error.osError?.errorCode ?? 'unknown'}): $reason',
        );
      }
      throw ApiException(
        'Could not connect to ${uri.host}:${uri.port} for ${uri.path}: $reason',
      );
    } on http.ClientException catch (error) {
      if (kDebugMode) {
        debugPrint('HTTP client failed for ${uri.path}: ${error.message}');
      }
      throw ApiException(
        'HTTP request to ${uri.host}:${uri.port}${uri.path} failed: ${error.message}',
      );
    } on TimeoutException catch (error) {
      final detail = error.message?.trim();
      if (kDebugMode) {
        debugPrint('Request timed out for ${uri.path}: ${detail ?? 'timeout'}');
      }
      throw ApiException(
        'Request to ${uri.host}:${uri.port}${uri.path} timed out after ${AppConstants.requestTimeout.inSeconds} seconds${detail == null || detail.isEmpty ? '.' : ': $detail'}',
      );
    }
  }

  int? _retryAfterSeconds(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final seconds = int.tryParse(value.trim());
    if (seconds != null) return seconds > 0 ? seconds : null;
    try {
      final retryAt = HttpDate.parse(value);
      final remaining = retryAt.difference(DateTime.now()).inSeconds;
      return remaining > 0 ? remaining + 1 : null;
    } on FormatException {
      return null;
    }
  }
}
