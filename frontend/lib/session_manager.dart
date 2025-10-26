// lib/session_manager.dart

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  /* ---------- singleton ---------- */
  SessionManager._();
  static final SessionManager instance = SessionManager._();

  /* ---------- in-memory state ---------- */
  String? _userId; // null / guest
  String? _jwt;
  String? _username;
  String? _primaryCommunityId; // null until chosen

  /* ---------- convenience ---------- */
  bool get isGuest => _userId == null || _userId!.isEmpty;
  String? get primaryCommunityIdSync => _primaryCommunityId;

  /// Public accessors
  Future<String?> get userId async {
    if (_userId != null) return _userId;
    final sp = await SharedPreferences.getInstance();
    _userId = sp.getString('user_id');
    return _userId;
  }

  Future<String?> get jwt async {
    if (_jwt != null) return _jwt;
    final sp = await SharedPreferences.getInstance();
    _jwt = sp.getString('jwt');
    return _jwt;
  }

  Future<String?> get username async {
    if (_username != null) return _username;
    final sp = await SharedPreferences.getInstance();
    _username = sp.getString('username');
    return _username;
  }

  Future<String?> get primaryCommunityId async {
    if (_primaryCommunityId != null) return _primaryCommunityId;
    final sp = await SharedPreferences.getInstance();
    _primaryCommunityId = sp.getString('primary_community');
    return _primaryCommunityId;
  }

  /// Load everything from prefs into memory.
  Future<void> loadFromPrefs() async {
    final sp = await SharedPreferences.getInstance();
    _jwt = sp.getString('jwt');
    _userId = sp.getString('user_id');
    _username = sp.getString('username');
    _primaryCommunityId = sp.getString('primary_community');
    if (_jwt != null && kDebugMode) {
      debugPrint('🛠️ [SessionManager] Loaded JWT from prefs: $_jwt');
    }
  }

  /// Update session state (e.g., after login/signup). All three required.
  Future<void> update({
    required String? userId,
    required String? jwt,
    required String? username,
    String? primaryCommunity,
  }) async {
    _userId = userId;
    _jwt = jwt;
    _username = username;
    if (primaryCommunity != null) {
      _primaryCommunityId = primaryCommunity;
    }

    final sp = await SharedPreferences.getInstance();
    if (isGuest) {
      await sp.clear();
      if (kDebugMode) {
        debugPrint('🛠️ [SessionManager] Cleared session (guest).');
      }
      return;
    }

    await sp.setString('user_id', userId!);
    await sp.setString('jwt', jwt!);
    await sp.setString('username', username!);
    if (primaryCommunity != null) {
      await sp.setString('primary_community', primaryCommunity);
    }

    // Print for debugging
    if (kDebugMode) {
      debugPrint('🛠️ [SessionManager] Saved session:');
      debugPrint('    • userId: $userId');
      debugPrint('    • username: $username');
      debugPrint('    • jwt: $jwt');
      if (primaryCommunity != null) {
        debugPrint('    • primaryCommunity: $primaryCommunity');
      }
    }
  }
}
