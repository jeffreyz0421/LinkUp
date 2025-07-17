import 'dart:convert';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';
import 'main_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtl = TextEditingController();
  final _passwordCtl = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _usernameCtl.dispose();
    _passwordCtl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await http.post(
        Uri.parse('${Config.serverBaseUrl}/userlogin'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(_buildLoginPayload(
          _usernameCtl.text.trim(),
          _passwordCtl.text,
        )),
      ).timeout(const Duration(seconds: 15));

      final json = jsonDecode(response.body);

      if (response.statusCode == 200 && json['success'] == true) {
        await _saveUserData(json);
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MapScreen()),
        );
      } else {
        setState(() => _error = json['error'] ?? 'Login failed (${response.statusCode})');
      }
    } on TimeoutException {
      setState(() => _error = 'Connection timeout. Please try again.');
    } catch (e) {
      setState(() => _error = 'Network error. Please check your connection.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveUserData(Map<String, dynamic> json) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', json['access_token'] ?? '');
    await prefs.setString('user_id', json['user_id']?.toString() ?? '');
    await prefs.setString('username', json['username'] ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.white,
        ),
        child: Stack(
          children: [
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
                padding: const EdgeInsets.all(16.0),
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
                              width: 1,
                            ),
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  margin: const EdgeInsets.only(bottom: 24),
                                  child: CustomPaint(painter: BrandLogoPainter()),
                                ),
                                const Text(
                                  'Login',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Enter your email and password to log in',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF6C7278),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                _buildInputField(_usernameCtl, 'example@umich.edu', Icons.person_outline),
                                const SizedBox(height: 8),
                                _buildPasswordField(),
                                if (_error != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: Text(
                                      _error!,
                                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                                    ),
                                  ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed: _loading ? null : _submit,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1D61E7),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: _loading
                                        ? const CircularProgressIndicator(color: Colors.white)
                                        : const Text('Log In', style: TextStyle(color: Colors.white)),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text("Don't have an account?"),
                                    TextButton(
                                      onPressed: _loading ? null : () => Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const SignupScreen()),
                                      ),
                                      child: const Text('Sign up'),
                                    ),
                                  ],
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
      ),
    );
  }

  Widget _buildInputField(TextEditingController controller, String hint, IconData icon) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      validator: (v) => v?.isEmpty ?? true ? 'Required field' : null,
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordCtl,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        hintText: 'Password',
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      validator: (v) => v?.isEmpty ?? true ? 'Enter your password' : null,
    );
  }
}

class BrandLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF6E8AFC), Color(0xFF375DFB)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final Path path = Path();
    path.addOval(Rect.fromLTWH(0, 0, size.width, size.height));
    path.addOval(Rect.fromCircle(center: Offset(size.width / 2, size.height / 2), radius: size.width / 4));
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Map<String, String> _buildLoginPayload(String id, String pw) {
  final emailRegex = RegExp(r'^[\w.+-]+@\w+\.\w+\$');
  final phoneRegex = RegExp(r'^\d{10,}\$');

  if (emailRegex.hasMatch(id)) return {'email': id, 'password': pw};
  if (phoneRegex.hasMatch(id)) return {'phone_number': id, 'password': pw};
  return {'username': id, 'password': pw};
}
