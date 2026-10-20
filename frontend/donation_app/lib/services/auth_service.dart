import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class AuthException implements Exception {
  const AuthException(
    this.message, {
    this.verificationRequired = false,
    this.statusCode,
  });
  final String message;
  final bool verificationRequired;
  final int? statusCode;
}

class AuthSession {
  const AuthSession({
    required this.token,
    required this.name,
    required this.email,
  });
  final String token;
  final String name;
  final String email;
}

class AuthService {
  AuthService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      baseUrl = baseUrl ?? _defaultBaseUrl;

  static String get _defaultBaseUrl {
    const configured = String.fromEnvironment('API_URL');
    if (configured.isNotEmpty) return configured;
    return 'https://donation-backend-bkms.onrender.com';
  }

  final http.Client _client;
  final String baseUrl;
  AuthSession? currentSession;

  Future<AuthSession> login({
    required String email,
    required String password,
  }) => _authenticate('login', {'email': email.trim(), 'password': password});

  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
  }) => _authenticate('register', {
    'name': name.trim(),
    'email': email.trim(),
    'password': password,
  });

  Future<AuthSession> verifyEmail({
    required String email,
    required String code,
  }) => _authenticate('verify-email', {
    'email': email.trim(),
    'code': code.trim(),
  });

  Future<void> resendVerification({
    required String email,
    required String password,
  }) async {
    final response = await _post(
      '/auth/resend-verification',
      body: {'email': email.trim(), 'password': password},
    );
    try {
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (response.statusCode != 200) {
        throw AuthException(
          data['message'] as String? ?? 'Код илгээж чадсангүй.',
        );
      }
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException('Серверийн хариуг уншиж чадсангүй.');
    }
  }

  Future<AuthSession> _authenticate(
    String action,
    Map<String, String> body,
  ) async {
    final response = await _post('/auth/$action', body: body);
    try {
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (data['verification_required'] == true) {
        throw AuthException(
          data['message'] as String? ?? 'Имэйлээ баталгаажуулна уу.',
          verificationRequired: true,
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AuthException(
          data['message'] as String? ?? 'Алдаа гарлаа. Дахин оролдоно уу.',
        );
      }
      final user = data['user'] as Map<String, dynamic>;
      final session = AuthSession(
        token: data['token'] as String,
        name: user['name'] as String,
        email: user['email'] as String,
      );
      currentSession = session;
      return session;
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException(
        'Серверийн хариуг уншиж чадсангүй. Дахин оролдоно уу.',
      );
    }
  }

  Future<void> logout(String token) async {
    final response = await _post('/auth/logout', token: token);
    if (response.statusCode != 200) {
      throw const AuthException('Гарч чадсангүй. Дахин оролдоно уу.');
    }
    currentSession = null;
  }

  Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? body,
    bool post = false,
  }) async {
    final response = await _send(
      path,
      body: body,
      token: currentSession?.token,
      post: post,
    );
    try {
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (response.statusCode == 401) currentSession = null;
        final errors = data['errors'];
        final details = errors is Map
            ? errors.values
                  .expand((value) => value is List ? value : [value])
                  .join('\n')
            : '';
        throw AuthException(
          details.isNotEmpty
              ? details
              : data['message'] as String? ?? 'Алдаа гарлаа.',
          statusCode: response.statusCode,
        );
      }
      return data;
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException(
        'Серверийн хариуг уншиж чадсангүй. Дахин оролдоно уу.',
      );
    }
  }

  Future<http.Response> _post(
    String path, {
    Map<String, String>? body,
    String? token,
  }) => _send(path, body: body, token: token, post: true);

  Future<http.Response> _send(
    String path, {
    Map<String, dynamic>? body,
    String? token,
    bool post = false,
  }) async {
    try {
      final uri = Uri.parse('${baseUrl.replaceAll(RegExp(r'/$'), '')}$path');
      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
      return await (post
              ? _client.post(
                  uri,
                  headers: headers,
                  body: jsonEncode(body ?? {}),
                )
              : _client.get(uri, headers: headers))
          .timeout(const Duration(seconds: 90));
    } on TimeoutException {
      throw const AuthException(
        'Холболтын хугацаа дууслаа. Дахин оролдоно уу.',
      );
    } catch (_) {
      throw const AuthException(
        'Сервертэй холбогдож чадсангүй. Дахин оролдоно уу.',
      );
    }
  }

  void close() => _client.close();
}
