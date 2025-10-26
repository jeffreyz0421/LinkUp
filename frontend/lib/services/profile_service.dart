// lib/services/profile_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../session_manager.dart';

class ProfileService {
  ProfileService(this._client);
  final http.Client _client;

  String get _base => Config.serverBaseUrl;

  /// GET full composite profile (includes hobbies, name, username, etc.)
  Future<Map<String, dynamic>> getProfileRaw() async {
    final token = await SessionManager.instance.jwt;
    final uri = Uri.parse('$_base/api/users');

    final resp = await _client.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    ).timeout(Duration(milliseconds: Config.apiTimeout));

    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }

    throw Exception('getProfile failed – HTTP ${resp.statusCode}: ${resp.body}');
  }

  Future<List<String>> getHobbies() async {
    final raw = await getProfileRaw();
    final hobbies = raw['hobbies'];
    if (hobbies is List) {
      return List<String>.from(hobbies);
    }
    return [];
  }

  Future<void> setHobbies(List<String> hobbies) async {
    final token = await SessionManager.instance.jwt;
    final uri = Uri.parse('$_base/api/users');

    final resp = await _client.put(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'hobbies': hobbies}),
    ).timeout(Duration(milliseconds: Config.apiTimeout));

    if (resp.statusCode == 200 || resp.statusCode == 202 || resp.statusCode == 204) {
      return;
    }

    throw Exception('setHobbies failed – HTTP ${resp.statusCode}: ${resp.body}');
  }
}
