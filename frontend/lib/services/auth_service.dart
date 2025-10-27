// lib/services/auth_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => 'AuthException: $message';
}

class AuthResponse {
  final String userId;
  final String username;
  final String accessToken;

  AuthResponse({
    required this.userId,
    required this.username,
    required this.accessToken,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> j) {
    if (j['user_id'] == null || j['username'] == null || j['access_token'] == null) {
      throw AuthException('Malformed auth response: missing fields: $j');
    }
    return AuthResponse(
      userId: j['user_id'] as String,
      username: j['username'] as String,
      accessToken: j['access_token'] as String,
    );
  }
}

class AuthService {
  final String _base = Config.serverBaseUrl;
  static const _timeout = Duration(seconds: 15);

  /// Determines whether the identifier is email / phone / username.
  Map<String, String> _buildLoginPayload(String id, String password) {
    final emailRx = RegExp(r'^[\w.+-]+@\w+\.\w+$');
    final phoneRx = RegExp(r'^\d{10,}$');
    if (emailRx.hasMatch(id)) return {'email': id, 'password': password};
    if (phoneRx.hasMatch(id)) return {'phone_number': id, 'password': password};
    return {'username': id, 'password': password};
  }

  Future<AuthResponse> login({
    required String identifier,
    required String password,
  }) async {
    final trimmed = identifier.trim();
    if (trimmed.isEmpty) {
      throw AuthException('Login identifier is empty');
    }

    final uri = Uri.parse('$_base/api/user/login');
    final payload = _buildLoginPayload(trimmed, password);

    final resp = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(_timeout);

    Map<String, dynamic> body = {};
    try {
      body = jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (_) {
      // ignore parse errors; body may be empty
    }

    if (resp.statusCode == 200 || resp.statusCode == 202) {
      try {
        return AuthResponse.fromJson(body);
      } catch (e) {
        throw AuthException('Failed to parse login response: $e');
      }
    }

    final serverErr = (body['error'] as String?) ?? resp.body;
    throw AuthException('Login failed (${resp.statusCode}): $serverErr');
  }

  Future<AuthResponse> signup({
    required String username,
    required String email,
    required String password,
    required String name,
    required String phoneNumber,
  }) async {
    final uri = Uri.parse('$_base/api/users/signup');
    final payload = {
      'username': username.trim(),
      'email': email.trim(),
      'password': password,
      'name': name.trim(),
      'phone_number': phoneNumber.trim(),
    };

    final resp = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(_timeout);

    Map<String, dynamic> body = {};
    try {
      body = jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (_) {}

    if (resp.statusCode == 201) {
      try {
        return AuthResponse.fromJson(body);
      } catch (e) {
        throw AuthException('Failed to parse signup response: $e');
      }
    }

    if (resp.statusCode == 409) {
      // conflict — attempt login. Try username first, then email as fallback.
      try {
        return await login(identifier: username, password: password);
      } catch (_) {
        // fallback to email if username-login failed
        return await login(identifier: email, password: password);
      }
    }

    final serverErr = (body['error'] as String?) ?? resp.body;
    throw AuthException('Signup failed (${resp.statusCode}): $serverErr');
  }
}
