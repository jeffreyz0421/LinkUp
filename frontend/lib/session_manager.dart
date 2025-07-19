
// ███  session_manager.dart  ███
//
// Tiny singleton that caches session‑wide values:
//
//   • JWT access‑token           (key: auth_token)
//   • Signed‑in user‑id / uuid   (key: user_id)
//
//   SessionManager.instance           → the singleton
//   instance.token  (Future<String?>)
//   instance.userId (Future<String?>)
//   instance.setSession({required jwt, required userId})
//   instance.clear()                       // log‑out helper
//
// Add more fields the same way (username, avatar, etc.) if needed.
//

import 'package:shared_preferences/shared_preferences.dart';
/// session_manager.dart
class SessionManager {
  /* ---------- singleton ---------- */
  SessionManager._();                    // private ctor
  static final SessionManager instance = SessionManager._();

  /* ---------- runtime state ---------- */
  String? _userId;                       // null / ''  ==> guest
  String? _jwt;
  bool    get isGuest => _userId == null || _userId!.isEmpty;

  Future<void> update({
    required String? userId,
    required String? jwt,
  }) async {
    _userId = userId;
    _jwt    = jwt;
    // Persist only if NOT guest
    final sp = await SharedPreferences.getInstance();
    if (isGuest) {
      await sp.clear();                  // 👈 wipe everything
    } else {
      await sp.setString('user_id', userId!);
      await sp.setString('jwt', jwt!);
    }
  }

  Future<String?> get userId async {                // return nullable
  if (_userId != null) return _userId;            // may already be null
  final sp = await SharedPreferences.getInstance();
  _userId = sp.getString('user_id');              // <- NO default ''
  return _userId;                                 // null => guest
}

  Future<String?> get jwt async {
    if (_jwt != null) return _jwt;
    final sp = await SharedPreferences.getInstance();
    _jwt = sp.getString('jwt');
    return _jwt;
  }
}




//## 1  Minimal “session” helper – store token / user ID once after login
//Where to call update()?
//When you receive the AuthResponse after /userlogin
//simply run
//SessionManager().update(token: resp.accessToken, userId: resp.userId);