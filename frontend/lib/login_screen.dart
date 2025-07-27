// lib/login_screen.dart

import 'dart:convert';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'session_manager.dart';
import 'main_screen_ui.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey         = GlobalKey<FormState>();
  final _usernameCtl     = TextEditingController();
  final _passwordCtl     = TextEditingController();
  bool  _loading         = false;
  bool  _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _usernameCtl.dispose();
    _passwordCtl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    final payload = _buildLoginPayload(
      _usernameCtl.text.trim(),
      _passwordCtl.text,
    );

    try {
      final resp = await http
          .post(
            Uri.parse('${Config.serverBaseUrl}/userlogin'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(resp.body) as Map<String, dynamic>;

      // success if 200/202 and no error
      if ((resp.statusCode == 200 || resp.statusCode == 202)
          && (body['error'] as String).isEmpty) {
        // 1️⃣ persist to prefs
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', body['access_token'] as String);
        await prefs.setString('user_id',    body['user_id']    as String);
        await prefs.setString('username',   body['username']   as String);

        // 2️⃣ update in‑memory session
        await SessionManager.instance.update(
          userId: body['user_id'] as String,
          jwt:    body['access_token'] as String,
        );

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MapScreen()),
        );
      } else {
        setState(() {
          _error = (body['error'] as String).isNotEmpty
              ? body['error'] as String
              : 'Login failed (${resp.statusCode})';
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

  Map<String, String> _buildLoginPayload(String id, String pw) {
    final emailRx = RegExp(r'^[\w.+-]+@\w+\.\w+$');
    final phoneRx = RegExp(r'^\d{10,}$');
    if (emailRx.hasMatch(id))   return {'email': id,        'password': pw};
    if (phoneRx.hasMatch(id))   return {'phone_number': id, 'password': pw};
    return {'username': id,      'password': pw};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity, height: double.infinity,
        decoration: const BoxDecoration(color: Colors.white),
        child: Stack(children: [
          // background blobs…
          Positioned(
            left: -229, top: -163,
            child: Container(width: 582, height: 582, decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF13D4D4).withOpacity(0.8),
            )),
          ),
          Positioned(
            left: 27, top: 419,
            child: Container(width: 934, height: 934, decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFB49EF4).withOpacity(0.8),
            )),
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
                          border: Border.all(color: Colors.white.withOpacity(0.8)),
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            // your logo painter + title…
                            const Text('Login', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 12),
                            const Text(
                              'Enter your email/username and password to log in',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: Color(0xFF6C7278)),
                            ),
                            const SizedBox(height: 24),
                            TextFormField(
                              controller: _usernameCtl,
                              decoration: InputDecoration(
                                hintText: 'you@domain.com',
                                prefixIcon: const Icon(Icons.person_outline),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
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
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              validator: (v) => (v?.isEmpty ?? true) ? 'Enter your password' : null,
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                            ],
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity, height: 48,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _submit,
                                child: _loading
                                    ? const SizedBox(
                                        width: 20, height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Text('Log In'),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              const Text("Don't have an account?"),
                              TextButton(
                                onPressed: _loading
                                    ? null
                                    : () => Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => const SignupScreen()),
                                        ),
                                child: const Text('Sign up'),
                              ),
                            ]),
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
