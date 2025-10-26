// lib/login_screen.dart

import 'dart:convert';
import 'dart:ui' show ImageFilter;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'session_manager.dart';
import 'main_screen_ui.dart';
import 'signup_screen.dart';
import 'services/profile_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierCtl = TextEditingController();
  final _passwordCtl = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _identifierCtl.dispose();
    _passwordCtl.dispose();
    super.dispose();
  }

  Map<String, String> _buildLoginPayload(String id, String pw) {
    final emailRx = RegExp(r'^[\w.+-]+@\w+\.\w+$');
    final phoneRx = RegExp(r'^\d{10,}$');
    if (emailRx.hasMatch(id)) return {'email': id, 'password': pw};
    if (phoneRx.hasMatch(id)) return {'phone_number': id, 'password': pw};
    return {'username': id, 'password': pw};
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final identifier = _identifierCtl.text.trim();
    final password = _passwordCtl.text;
    final payload = _buildLoginPayload(identifier, password);

    try {
      final uri = Uri.parse('${Config.serverBaseUrl}/api/user/login');
      final resp = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      Map<String, dynamic> body = {};
      try {
        body = jsonDecode(resp.body) as Map<String, dynamic>;
      } catch (_) {
        // ignore malformed JSON
      }

      if (resp.statusCode == 200 || resp.statusCode == 202) {
        final accessToken = body['access_token'] as String?;
        final userId = body['user_id'] as String?;
        final username = body['username'] as String?;

        if (accessToken == null || userId == null || username == null) {
          setState(() {
            _error = 'Unexpected server response';
          });
          return;
        }

        // update session (persists internally)
        await SessionManager.instance.update(
          userId: userId,
          jwt: accessToken,
          username: username,
        );

        // persist profile basics (name / email / phone) by fetching full profile
        try {
          final prefs = await SharedPreferences.getInstance();
          final profileRaw =
              await ProfileService(http.Client()).getProfileRaw();
          if (profileRaw.containsKey('name')) {
            await prefs.setString('name', profileRaw['name'] as String);
          }
          if (profileRaw.containsKey('email')) {
            await prefs.setString('email', profileRaw['email'] as String);
          }
          if (profileRaw.containsKey('phone_number')) {
            await prefs.setString(
                'phone_number', profileRaw['phone_number'] as String);
          }
        } catch (e) {
          debugPrint('Failed to fetch profile after login: $e');
          // Not fatal; ProfileScreen will show cached values / banner.
        }

        debugPrint(
            '🗂 Stored session: jwt_token=$accessToken user_id=$userId username=$username');

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MapScreen()),
        );
      } else {
        String msg = 'Login failed (${resp.statusCode})';
        if (body.containsKey('error') &&
            (body['error'] as String).isNotEmpty) {
          msg = body['error'] as String;
        } else if (body.containsKey('message') &&
            (body['message'] as String).isNotEmpty) {
          msg = body['message'] as String;
        }
        setState(() {
          _error = msg;
        });
      }
    } on TimeoutException {
      setState(() => _error = 'Connection timed out. Please try again.');
    } catch (e) {
      setState(() => _error = 'Network error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(color: Colors.white),
        child: Stack(children: [
          // background blobs…
          Positioned(
            left: -229,
            top: -163,
            child: Container(
              width: 582,
              height: 582,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF13D4D4).withOpacity(0.8),
              ),
            ),
          ),
          Positioned(
            left: 27,
            top: 419,
            child: Container(
              width: 934,
              height: 934,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFB49EF4).withOpacity(0.8),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 375),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.8)),
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            const Text('Login',
                                style: TextStyle(
                                    fontSize: 32, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 12),
                            const Text(
                              'Enter your email/username and password to log in',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xFF6C7278)),
                            ),
                            const SizedBox(height: 24),
                            TextFormField(
                              controller: _identifierCtl,
                              decoration: InputDecoration(
                                hintText: 'username / email / phone',
                                prefixIcon: const Icon(Icons.person_outline),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              validator: (v) =>
                                  (v?.isEmpty ?? true) ? 'Required' : null,
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _passwordCtl,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                hintText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility),
                                  onPressed: () => setState(
                                      () => _obscurePassword = !_obscurePassword),
                                ),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              validator: (v) => (v?.isEmpty ?? true)
                                  ? 'Enter your password'
                                  : null,
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              Text(_error!,
                                  style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.error)),
                            ],
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _submit,
                                child: _loading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white),
                                      )
                                    : const Text('Log In'),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text("Don't have an account?"),
                                TextButton(
                                  onPressed: _loading
                                      ? null
                                      : () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) =>
                                                    const SignupScreen()),
                                          ),
                                  child: const Text('Sign up'),
                                ),
                              ],
                            ),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
