import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:inno/app.dart';
import 'package:inno/core/utils/validators.dart';
import 'package:inno/models/user_model.dart';
import 'package:inno/core/routes/app_routes.dart';
import 'package:inno/screens/auth/auth_screens.dart';
import 'package:inno/services/auth_service.dart';
import 'package:inno/services/api_service.dart';
import 'package:inno/services/storage_service.dart';

void main() {
  group('API request configuration', () {
    test(
      'sends the ngrok skip header on register, login, and authenticated methods',
      () async {
        final client = _CapturingClient();
        final api = ApiService(
          _TestStorage(),
          client: client,
          baseUrl: 'https://ducktail-parsnip-opposing.ngrok-free.dev/api/',
        );
        await api.post('/auth/register', body: {'name': 'Test'});
        await api.post('/auth/login', body: {'email': 'test@example.invalid'});
        await api.get('/profiles/me');
        await api.put('/profiles/me', body: {'name': 'Test'});

        expect(client.requests.map((request) => request.url.path), [
          '/api/auth/register',
          '/api/auth/login',
          '/api/profiles/me',
          '/api/profiles/me',
        ]);
        expect(
          client.requests.first.url.toString(),
          'https://ducktail-parsnip-opposing.ngrok-free.dev/api/auth/register',
        );
        expect(client.requests, hasLength(4));
        for (final request in client.requests) {
          expect(request.headers['ngrok-skip-browser-warning'], 'true');
        }
      },
    );

    test('does not send the ngrok header to a local backend', () async {
      final client = _CapturingClient();
      final api = ApiService(
        _TestStorage(),
        client: client,
        baseUrl: 'http://10.0.2.2:8081/api',
      );
      await api.post('/auth/register', body: {'name': 'Test'});
      expect(
        client.requests.single.headers.containsKey(
          'ngrok-skip-browser-warning',
        ),
        isFalse,
      );
    });

    test('preserves a useful backend error response', () async {
      final client = _CapturingClient(
        statusCode: 500,
        responseBody: '{"message":"Database write failed."}',
      );
      final api = ApiService(
        _TestStorage(),
        client: client,
        baseUrl: 'https://sample.ngrok-free.dev/api',
      );
      await expectLater(
        api.post('/auth/register'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Database write failed.',
          ),
        ),
      );
    });

    test('preserves the 429 retry-after cooldown', () async {
      final client = _CapturingClient(
        statusCode: 429,
        responseBody:
            '{"message":"Too many attempts. Please try again in 15 seconds."}',
        responseHeaders: {'retry-after': '15'},
      );
      final api = ApiService(
        _TestStorage(),
        client: client,
        baseUrl: 'https://sample.ngrok-free.dev/api',
      );

      await expectLater(
        api.post('/auth/login'),
        throwsA(
          isA<ApiException>()
              .having((error) => error.statusCode, 'statusCode', 429)
              .having((error) => error.retryAfterSeconds, 'retryAfter', 15)
              .having((error) => error.isRateLimit, 'isRateLimit', isTrue),
        ),
      );
    });

    test(
      'identifies the ngrok warning HTML instead of reporting invalid JSON',
      () async {
        final client = _CapturingClient(
          responseBody:
              '<html><title>ngrok</title>You are about to visit</html>',
        );
        final api = ApiService(
          _TestStorage(),
          client: client,
          baseUrl: 'https://sample.ngrok-free.dev/api',
        );
        await expectLater(
          api.post('/auth/register'),
          throwsA(
            isA<ApiException>().having(
              (error) => error.message,
              'message',
              contains('ngrok returned its browser-warning page'),
            ),
          ),
        );
      },
    );
  });
  group('authentication retry cooldown', () {
    testWidgets('login locks and unlocks its submit button after 15 seconds', (
      tester,
    ) async {
      final client = _CapturingClient(
        statusCode: 429,
        responseBody:
            '{"message":"Too many attempts. Please try again in 15 seconds."}',
        responseHeaders: {'retry-after': '15'},
      );
      final auth = AuthService(
        _TestStorage(),
        api: ApiService(
          _TestStorage(),
          client: client,
          baseUrl: 'https://sample.ngrok-free.dev/api',
        ),
      );
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        AuthScope(
          notifier: auth,
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'founder@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'Secure123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pump();
      await tester.pump();

      expect(
        find.text('Too many attempts. Please try again in 15 seconds.'),
        findsOneWidget,
      );
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      expect(client.requests, hasLength(1));
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(client.requests, hasLength(1));

      await tester.pump(const Duration(seconds: 1));
      expect(
        find.text('Too many attempts. Please try again in 14 seconds.'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 14));
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNotNull,
      );
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      await tester.pump();
      expect(client.requests, hasLength(2));
    });

    testWidgets('registration locks and unlocks after its retry countdown', (
      tester,
    ) async {
      final client = _CapturingClient(
        statusCode: 429,
        responseBody:
            '{"message":"Too many attempts. Please try again in 15 seconds."}',
        responseHeaders: {'retry-after': '15'},
      );
      final auth = AuthService(
        _TestStorage(),
        api: ApiService(
          _TestStorage(),
          client: client,
          baseUrl: 'https://sample.ngrok-free.dev/api',
        ),
      );
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        AuthScope(
          notifier: auth,
          child: const MaterialApp(home: RegisterScreen()),
        ),
      );
      await tester.enterText(find.byType(TextFormField).at(0), 'Founder');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'founder@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(2), '1234567890');
      await tester.enterText(find.byType(TextFormField).at(3), 'Secure123');
      await tester.ensureVisible(find.text('Create Account'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
      await tester.pump();
      await tester.pump();

      expect(
        find.text('Too many attempts. Please try again in 15 seconds.'),
        findsOneWidget,
      );
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      expect(client.requests, hasLength(1));

      await tester.pump(const Duration(seconds: 15));
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNotNull,
      );
    });
  });
  group('form validation', () {
    test(
      'accepts a valid email',
      () => expect(Validators.email('founder@innovestia.app'), isNull),
    );
    test(
      'rejects an invalid email',
      () => expect(Validators.email('not-an-email'), isNotNull),
    );
    test('requires a strong password', () {
      expect(Validators.password('short'), isNotNull);
      expect(Validators.password('secure123'), isNull);
    });
  });
  test('role serializes using the API contract', () {
    expect(UserRole.investor.apiValue, 'INVESTOR');
    expect(UserRoleX.fromJson('ADMIN'), UserRole.admin);
  });
  test('each authenticated role maps to its existing dashboard', () {
    expect(
      AppRoutes.dashboardForRole(UserRole.startup),
      AppRoutes.startupDashboard,
    );
    expect(
      AppRoutes.dashboardForRole(UserRole.investor),
      AppRoutes.investorDashboard,
    );
    expect(
      AppRoutes.dashboardForRole(UserRole.admin),
      AppRoutes.adminDashboard,
    );
  });
}

class _CapturedRequest {
  _CapturedRequest(this.url, this.headers);
  final Uri url;
  final Map<String, String> headers;
}

class _CapturingClient extends http.BaseClient {
  _CapturingClient({
    this.statusCode = 200,
    this.responseBody = '{}',
    this.responseHeaders = const {'content-type': 'application/json'},
  });
  final int statusCode;
  final String responseBody;
  final Map<String, String> responseHeaders;
  final requests = <_CapturedRequest>[];
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(
      _CapturedRequest(request.url, Map<String, String>.from(request.headers)),
    );
    return http.StreamedResponse(
      Stream.value(utf8.encode(responseBody)),
      statusCode,
      headers: responseHeaders,
    );
  }
}

class _TestStorage extends StorageService {
  @override
  Future<String?> readToken() async => 'test-session-token';
}
