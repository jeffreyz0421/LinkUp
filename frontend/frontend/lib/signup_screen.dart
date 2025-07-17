import 'dart:convert';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  String? _errorMessage;
  bool _loading = false;
  bool _obscurePassword = true;

  static final _usernameRegex = RegExp(r'^[a-zA-Z0-9_]{3,20}$');
  static final _emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
  static final _phoneRegex = RegExp(r'^[0-9]{10,15}$');

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

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final payload = {
      "username": _usernameController.text.trim(),
      "email": _emailController.text.trim(),
      "password": _passwordController.text,
      "name": _nameController.text.trim(),
      "phone_number": _phoneController.text.trim(),
    };

    try {
      final response = await http.post(
        Uri.parse('${Config.serverBaseUrl}/usersignup'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        await _handleSuccessfulSignup(data, payload);
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/map');
      } else {
        _handleSignupError(data, response.statusCode);
      }
    } on TimeoutException {
      setState(() => _errorMessage = 'Request timed out. Please check your connection and try again.');
    } catch (e) {
      setState(() => _errorMessage = 'An unexpected error occurred: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleSuccessfulSignup(Map<String, dynamic> data, Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', data['token'] ?? '');
    await prefs.setString('user_id', data['user_id']?.toString() ?? '');
    await prefs.setString('username', data['username'] ?? payload['username']);
    await prefs.setString('name', data['name'] ?? payload['name']);
    await prefs.setString('email', data['email'] ?? payload['email']);
    await prefs.setString('phone_number', data['phone_number'] ?? payload['phone_number']);
  }

  void _handleSignupError(Map<String, dynamic> data, int statusCode) {
    final errorMessage = data['message'] as String? ??
        data['error'] as String? ??
        (statusCode == 400
            ? 'Invalid input data'
            : statusCode == 409
                ? 'Username or email already exists'
                : 'Server error ($statusCode)');

    setState(() => _errorMessage = errorMessage);
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      height: 46,
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEDF1F3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE4E5E7).withOpacity(0.24),
            offset: const Offset(0, 1),
            blurRadius: 2,
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Color(0xFF6C7278), fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
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
                          border: Border.all(color: Colors.white.withOpacity(0.8), width: 1),
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Sign Up',
                                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                              const SizedBox(height: 12),
                              const Text('Create an account to continue!',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF6C7278))),
                              const SizedBox(height: 24),
                              _buildInputField(
                                controller: _usernameController,
                                hintText: 'Username',
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Required';
                                  if (!_usernameRegex.hasMatch(v.trim())) return '3-20 chars (letters, numbers, _)';
                                  return null;
                                },
                              ),
                              _buildInputField(
                                controller: _emailController,
                                hintText: 'example@umich.edu',
                                keyboardType: TextInputType.emailAddress,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Required';
                                  if (!_emailRegex.hasMatch(v.trim())) return 'Invalid email';
                                  return null;
                                },
                              ),
                              _buildInputField(
                                controller: _passwordController,
                                hintText: 'Password',
                                obscureText: _obscurePassword,
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Required';
                                  if (v.length < 8) return 'Minimum 8 characters';
                                  return null;
                                },
                                suffixIcon: IconButton(
                                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility,
                                      color: const Color(0xFFACB5BB), size: 16),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              _buildInputField(
                                controller: _nameController,
                                hintText: 'Full Name',
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Required';
                                  if (v.trim().split(' ').length < 2) return 'First and last name';
                                  return null;
                                },
                              ),
                              _buildInputField(
                                controller: _phoneController,
                                hintText: 'Phone Number',
                                keyboardType: TextInputType.phone,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Required';
                                  if (!_phoneRegex.hasMatch(v.trim())) return 'Invalid phone';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              if (_errorMessage != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Text(_errorMessage!,
                                      style: TextStyle(color: Theme.of(context).colorScheme.error)),
                                ),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: _loading ? null : _submitSignup,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1D61E7),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: _loading
                                      ? const CircularProgressIndicator(color: Colors.white)
                                      : const Text('Register', style: TextStyle(color: Colors.white)),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextButton(
                                onPressed: _loading ? null : () => Navigator.of(context).pushReplacementNamed('/map'),
                                child: const Text('Continue as Guest'),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text("Already have an account?"),
                                  TextButton(
                                    onPressed: _loading ? null : () => Navigator.pop(context),
                                    child: const Text('Login'),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
