// lib/services/profile_service.dart

//## 2  Tiny service wrapper around the new hobbies endpoints

// ███  services/profile_service.dart  ███
//
// Thin REST helper used by ProfileScreen to
//   • GET  /api/profile/{id}/hobbies      → [List<String>]
//   • POST /api/profile/{id}/hobbies      ← [List<String>] JSON payload
//
// Depends on:
//   • Config.serverBaseUrl      (your env‐driven base URL)
//   • SessionManager            (provides current JWT)
//

import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../session_manager.dart';

class ProfileService {
  ProfileService(this._client);

  final http.Client _client;
  String get _base => Config.serverBaseUrl;

  /// GET the user’s hobbies.
  /// Returns an empty list if server responds 204 No Content.
  Future<List<String>> getHobbies(String userId) async {
    final token  = await SessionManager.instance.jwt;
    final uri    = Uri.parse('$_base/api/profile/$userId/hobbies');

    final resp = await _client.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type' : 'application/json',
      });

    if (resp.statusCode == 200) {
      final decoded = jsonDecode(resp.body) as List<dynamic>;
      return decoded.cast<String>();
    }
    if (resp.statusCode == 204) return <String>[];

    throw Exception(
      'getHobbies failed – HTTP ${resp.statusCode}: ${resp.body}');
  }

  /// Replace the entire hobby list on the server.
  /// Expects a JSON array of strings.
  Future<void> setHobbies(String userId, List<String> hobbies) async {
    final token = await SessionManager.instance.jwt;
    final uri   = Uri.parse('$_base/api/profile/$userId/hobbies');

    final resp = await _client.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type' : 'application/json',
      },
      body: jsonEncode(hobbies),
    );

    if (resp.statusCode == 200 || resp.statusCode == 204) return;

    throw Exception(
      'setHobbies failed – HTTP ${resp.statusCode}: ${resp.body}');
  }
}
