import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  /* ---------- singleton ---------- */
  SessionManager._();
  static final SessionManager instance = SessionManager._();

  /* ---------- in‑memory state ---------- */
  String? _userId;                 // null / guest
  String? _jwt;
  String? _primaryCommunityId;     // null until a community is chosen

  /* ---------- convenience ---------- */
  bool get isGuest => _userId == null || _userId!.isEmpty;

  /// Synchronous getter – used by UI layers that just need the cached value.
  String? get primaryCommunityIdSync => _primaryCommunityId;

  /* ---------- update (call after login / join community) ---------- */
  ///
  /// Pass `primaryCommunityId` *only* when it changes (e.g. user just joined
  /// or switched). Leave it `null` to keep the previous value.
  ///
  Future<void> update({
    required String? userId,
    required String? jwt,
    String? primaryCommunityId,
  }) async {
    _userId             = userId;
    _jwt                = jwt;
    _primaryCommunityId = primaryCommunityId ?? _primaryCommunityId;

    final sp = await SharedPreferences.getInstance();
    if (isGuest) {
      await sp.clear();                       // wipe everything for guests
      return;
    }

    await sp.setString('user_id', userId!);
    await sp.setString('jwt', jwt!);
    if (_primaryCommunityId != null) {
      await sp.setString('primary_community', _primaryCommunityId!);
    }
  }

  /* ---------- lazy async getters ---------- */
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

  Future<String?> get primaryCommunityId async {
    if (_primaryCommunityId != null) return _primaryCommunityId;
    final sp = await SharedPreferences.getInstance();
    _primaryCommunityId = sp.getString('primary_community');
    return _primaryCommunityId;
  }
}




//## 1  Minimal “session” helper – store token / user ID once after login
//Where to call update()?
//When you receive the AuthResponse after /userlogin
//simply run
//SessionManager().update(token: resp.accessToken, userId: resp.userId);