import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../session_manager.dart';
// lib/services/friend_service.dart
import '../models/friend.dart';

class FriendService {
  final http.Client _http;
  FriendService(this._http);

  String get _base => Config.serverBaseUrl;

  /// 1) fetch current profile,
  /// 2) grab the `friends` array of IDs,
  /// 3) fetch each friend’s public info in parallel.
  Future<List<Friend>> listFriends() async {
  final token = await SessionManager.instance.jwt;
  final resp = await _http.get(
    Uri.parse('$_base/api/users'),
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
  ).timeout(Duration(milliseconds: Config.apiTimeout));

  // ✅ Accept 200 and 202
  if (resp.statusCode != 200 && resp.statusCode != 202) {
    throw Exception('Failed to load your profile (HTTP ${resp.statusCode})');
  }

  final profile = resp.body.isNotEmpty
      ? jsonDecode(resp.body) as Map<String, dynamic>
      : <String, dynamic>{};
  final rawIds = profile['friends'] as List<dynamic>? ?? [];

  final futures = rawIds.map((fid) async {
    final r2 = await _http.get(
      Uri.parse('$_base/api/users/$fid'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    ).timeout(Duration(milliseconds: Config.apiTimeout));

    if (r2.statusCode != 200 && r2.statusCode != 202) {
      throw Exception('Failed to load friend $fid (HTTP ${r2.statusCode})');
    }

    return Friend.fromJson(jsonDecode(r2.body) as Map<String, dynamic>);
  });

  return Future.wait(futures);
}

  /// Search for users by username prefix.
  /// Assumes your backend exposes:
  ///   GET /api/users/search?username=<query>
  Future<List<Friend>> searchUsers(String query) async {
    final token = await SessionManager.instance.jwt;
    final resp = await _http.get(
      Uri.parse('$_base/api/users/search?username=${Uri.encodeComponent(query)}'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (resp.statusCode != 200 && resp.statusCode != 202) {
    throw Exception('Failed to load friends (${resp.statusCode}): ${resp.body}');
    }
    final List<dynamic> list = jsonDecode(resp.body) as List<dynamic>;
    return list
        .map((j) => Friend.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// send a friend request
  Future<void> sendRequest(String friendId) async {
    final token = await SessionManager.instance.jwt;
    final resp = await _http.post(
      Uri.parse('$_base/api/friends/request'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'friend_id': friendId}),
    );
    if (resp.statusCode != 201) {
      throw Exception('Failed to send friend request');
    }
  }

  /// accept an incoming request
  Future<void> acceptRequest(String friendId) async {
    final token = await SessionManager.instance.jwt;
    final resp = await _http.post(
      Uri.parse('$_base/api/friends/accept'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'friend_id': friendId}),
    );
    if (resp.statusCode != 201) {
      throw Exception('Failed to accept friend request');
    }
  }
}
