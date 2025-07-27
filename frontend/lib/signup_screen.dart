// lib/signup_screen.dart

import 'dart:convert';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'session_manager.dart';
import 'main_screen_ui.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey            = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController     = TextEditingController();
  final _phoneController    = TextEditingController();

  bool  _loading         = false;
  bool  _obscurePassword = true;
  String? _error;

  static final _usernameRx = RegExp(r'^[\w_]{3,20}$');
  static final _emailRx    = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
  static final _phoneRx    = RegExp(r'^\d{10,15}$');

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submitSignup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    final payload = {
      'username':     _usernameController.text.trim(),
      'email':        _emailController.text.trim(),
      'password':     _passwordController.text,
      'name':         _nameController.text.trim(),
      'phone_number': _phoneController.text.trim(),
    };

    try {
      final resp = await http
          .post(
            Uri.parse('${Config.serverBaseUrl}/usersignup'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(resp.body) as Map<String, dynamic>;

      if (resp.statusCode == 201 && (body['error'] as String).isEmpty) {
        // persist
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', body['access_token'] as String);
        await prefs.setString('user_id',    body['user_id']      as String);
        await prefs.setString('username',   body['username']     as String);

        // update session
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
              : 'Signup failed (${resp.statusCode})';
        });
      }
    } on TimeoutException {
      setState(() => _error = 'Connection timed out. Try again.');
    } catch (e) {
      setState(() => _error = 'Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        // background bubbles…
        Positioned(
          left: -229, top: -163,
          child: Container(width: 582, height: 582, decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFFA6C9).withOpacity(0.8),
          )),
        ),
        Positioned(
          left: 27, top: 419,
          child: Container(width: 934, height: 934, decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFFCCE0).withOpacity(0.8),
          )),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
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
                          const Text('Sign Up', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 12),
                          const Text('Create an account to continue!', style: TextStyle(fontSize: 12, color: Color(0xFF6C7278))),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _usernameController,
                            decoration: InputDecoration(
                              hintText: 'Username',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Required';
                              if (!_usernameRx.hasMatch(v.trim())) return '3–20 letters/numbers/_';
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              hintText: 'example@umich.edu',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Required';
                              if (!_emailRx.hasMatch(v.trim())) return 'Invalid email';
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              hintText: 'Password',
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Required';
                              if (v.length < 8) return 'Min. 8 chars';
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              hintText: 'Full Name',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Required';
                              if (v.trim().split(' ').length < 2) return 'First & last name';
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _phoneController,
                            decoration: InputDecoration(
                              hintText: 'Phone Number',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            keyboardType: TextInputType.phone,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Required';
                              if (!_phoneRx.hasMatch(v.trim())) return 'Invalid phone';
                              return null;
                            },
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                          ],
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity, height: 48,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _submitSignup,
                              child: _loading
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Text('Register'),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Text("Already have an account?"),
                            TextButton(
                              onPressed: _loading ? null : () => Navigator.pop(context),
                              child: const Text('Login'),
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
    );
  }
}
