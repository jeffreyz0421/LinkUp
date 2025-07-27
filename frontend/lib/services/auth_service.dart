// lib/services/auth_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '/../Config.dart';

class AuthService {
  final String _base = Config.serverBaseUrl;

  Future<Map<String, dynamic>> login({
    String? username,
    String? email,
    required String password,
  }) async {
    final resp = await http.post(
      Uri.parse('$_base/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        if (username != null) 'username': username,
        if (email != null) 'email': email,
        'password': password,
      }),
    );
    if (resp.statusCode == 202) {
      return jsonDecode(resp.body);
    }
    throw Exception('Login failed: ${resp.statusCode}');
  }

  Future<Map<String, dynamic>> signup({
    required String username,
    required String email,
    required String password,
    required String name,
    required String phoneNumber,
  }) async {
    final resp = await http.post(
      Uri.parse('$_base/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
        'name': name,
        'phone_number': phoneNumber,
      }),
    );
    if (resp.statusCode == 201) {
      return jsonDecode(resp.body);
    }
    throw Exception('Signup failed: ${resp.statusCode}');
  }
}
