// lib/signup_screen.dart

import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'session_manager.dart';
import 'main_screen_ui.dart';
import 'services/profile_service.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController     = TextEditingController();
  final _phoneController    = TextEditingController();

  bool   _loading         = false;
  bool   _obscurePassword = true;
  String? _error;

  static final _usernameRx = RegExp(r'^[\w_]{3,20}$');
  static final _emailRx = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
  static final _phoneRx = RegExp(r'^\d{10,15}$');

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _persistProfileOverrides({
    required String userId,
    required String accessToken,
    required String username,
    required bool preferServerValues,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Save the bare session info first
    await prefs.setString('jwt', accessToken);
    await prefs.setString('user_id', userId);
    await prefs.setString('username', username);

    // Try fetching canonical profile from server
    if (preferServerValues) {
      try {
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
        debugPrint('Could not refresh profile after signup/login fallback: $e');
        // fallback to using provided values below
      }
    }

    // If we don't have name/email/phone from server, fall back to what user typed
    if (!(await _hasPersistedField('name'))) {
      await prefs.setString('name', _nameController.text.trim());
    }
    if (!(await _hasPersistedField('email'))) {
      await prefs.setString('email', _emailController.text.trim());
    }
    if (!(await _hasPersistedField('phone_number'))) {
      await prefs.setString('phone_number', _phoneController.text.trim());
    }

    // Finally update in-memory session (username is non-null)
    await SessionManager.instance.update(
      userId: userId,
      jwt: accessToken,
      username: username,
    );
  }

  Future<bool> _hasPersistedField(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString(key);
    return val != null && val.isNotEmpty;
  }

  Future<void> _submitSignup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    final payload = {
      'username':     username,
      'email':        email,
      'password':     password,
      'name':         name,
      'phone_number': phone,
    };

    try {
      final signupUri = Uri.parse('${Config.serverBaseUrl}/api/users/signup');
      final resp = await http
          .post(
            signupUri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(Duration(milliseconds: Config.apiTimeout));

      Map<String, dynamic> body = {};
      try {
        body = jsonDecode(resp.body) as Map<String, dynamic>;
      } catch (_) {}

      if (resp.statusCode == 201) {
        final accessToken = body['access_token'] as String?;
        final userId = body['user_id'] as String?;
        final returnedUsername = body['username'] as String?;

        if (accessToken == null || userId == null || returnedUsername == null) {
          setState(() {
            _error = 'Unexpected server response';
          });
          return;
        }

        // Persist session + profile: prefer user-entered values (fresh signup)
        await _persistProfileOverrides(
          userId: userId,
          accessToken: accessToken,
          username: returnedUsername,
          preferServerValues: false,
        );

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MapScreen()),
        );
        return;
      } else if (resp.statusCode == 409) {
        // Duplicate: try login instead
        final loginUri = Uri.parse('${Config.serverBaseUrl}/api/users/login');
        final loginResp = await http
            .post(
              loginUri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'username': username,
                'password': password,
              }),
            )
            .timeout(Duration(milliseconds: Config.apiTimeout));

        Map<String, dynamic> loginBody = {};
        try {
          loginBody = jsonDecode(loginResp.body) as Map<String, dynamic>;
        } catch (_) {}

        if (loginResp.statusCode == 200 || loginResp.statusCode == 202) {
          final accessToken = loginBody['access_token'] as String?;
          final userId = loginBody['user_id'] as String?;
          final returnedUsername = loginBody['username'] as String?;

          if (accessToken == null || userId == null || returnedUsername == null) {
            setState(() {
              _error = 'Unexpected server response during login fallback';
            });
            return;
          }

          // Persist session + profile: prefer server values on fallback login
          await _persistProfileOverrides(
            userId: userId,
            accessToken: accessToken,
            username: returnedUsername,
            preferServerValues: true,
          );

          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MapScreen()),
          );
          return;
        } else {
          String msg =
              'Account exists, but login failed (${loginResp.statusCode})';
          if (loginBody.containsKey('error') &&
              (loginBody['error'] as String).isNotEmpty) {
            msg = loginBody['error'] as String;
          }
          setState(() => _error = msg);
          return;
        }
      } else {
        String message = 'Signup failed (${resp.statusCode})';
        if (body.containsKey('error') && (body['error'] as String).isNotEmpty) {
          message = body['error'] as String;
        }
        setState(() => _error = message);
        return;
      }
    } on TimeoutException {
      setState(() => _error = 'Connection timed out. Try again.');
    } catch (e) {
      setState(() => _error = 'Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _continueAsGuest() async {
    setState(() => _loading = true);
    await SessionManager.instance.update(userId: '', jwt: '', username: '');
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MapScreen()),
    );
  }

  String? _validateUsername(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    if (!_usernameRx.hasMatch(v.trim())) return '3–20 letters/numbers/_';
    return null;
  }

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    if (!_emailRx.hasMatch(v.trim())) return 'Invalid email';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Required';
    if (v.length < 8) return 'Min. 8 chars';
    return null;
  }

  String? _validateName(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    if (v.trim().split(' ').length < 2) return 'First & last name';
    return null;
  }

  String? _validatePhone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    if (!_phoneRx.hasMatch(v.trim())) return 'Invalid phone';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Pink background blobs
          Positioned(
            left: -229,
            top: -163,
            child: Container(
              width: 582,
              height: 582,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFFA6C9).withOpacity(0.8),
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
                color: const Color(0xFFFFCCE0).withOpacity(0.8),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                16,
                60,
                16,
                16 + MediaQuery.of(context).viewInsets.bottom,
              ),
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
                          border: Border.all(
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Sign Up',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Create an account to continue!',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6C7278),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Username
                              TextFormField(
                                controller: _usernameController,
                                decoration: InputDecoration(
                                  hintText: 'Username',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                validator: _validateUsername,
                              ),
                              const SizedBox(height: 8),

                              // Email
                              TextFormField(
                                controller: _emailController,
                                decoration: InputDecoration(
                                  hintText: 'example@umich.edu',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                keyboardType: TextInputType.emailAddress,
                                validator: _validateEmail,
                              ),
                              const SizedBox(height: 8),

                              // Password
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                decoration: InputDecoration(
                                  hintText: 'Password',
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscurePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility),
                                    onPressed: () => setState(
                                        () => _obscurePassword = !_obscurePassword),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                validator: _validatePassword,
                              ),
                              const SizedBox(height: 8),

                              // Full Name
                              TextFormField(
                                controller: _nameController,
                                decoration: InputDecoration(
                                  hintText: 'Full Name',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                validator: _validateName,
                              ),
                              const SizedBox(height: 8),

                              // Phone Number
                              TextFormField(
                                controller: _phoneController,
                                decoration: InputDecoration(
                                  hintText: 'Phone Number',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                keyboardType: TextInputType.phone,
                                validator: _validatePhone,
                              ),

                              if (_error != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  _error!,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 24),

                              // Register button
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: _loading ? null : _submitSignup,
                                  child: _loading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text('Register'),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Login link
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text("Already have an account?"),
                                  TextButton(
                                    onPressed: _loading
                                        ? null
                                        : () => Navigator.pushReplacement(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (_) =>
                                                      const LoginScreen()),
                                            ),
                                    child: const Text('Login'),
                                  ),
                                ],
                              ),

                              // Guest option
                              TextButton(
                                onPressed: _loading ? null : _continueAsGuest,
                                child: const Text('Continue as Guest'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
