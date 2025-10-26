// lib/main.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'session_manager.dart';

// Screens
import 'login_screen.dart';
import 'signup_screen.dart';
import 'main_screen_ui.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await dotenv.load(fileName: '.env');
    Config.validate();
    MapboxOptions.setAccessToken(dotenv.get('MAPBOX_ACCESS_TOKEN'));

    runApp(const LinkUpApp());
  }, (error, stack) {
    debugPrint('⚠️ Uncaught error: $error\n$stack');
  });
}

class LinkUpApp extends StatelessWidget {
  const LinkUpApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LinkUp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.deepPurple, useMaterial3: true),
      darkTheme: ThemeData(
          colorSchemeSeed: Colors.deepPurple,
          useMaterial3: true,
          brightness: Brightness.dark),
      initialRoute: '/',
      routes: {
        '/': (_) => const LaunchGate(),
        '/login': (_) => const LoginScreen(),
        '/signup': (_) => const SignupScreen(),
        '/map': (_) => const MapScreen(),
      },
      builder: (ctx, child) {
        ErrorWidget.builder = (details) => Scaffold(
              body: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    Config.isProduction
                        ? 'Something went wrong'
                        : details.exception.toString(),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () =>
                        Navigator.pushNamedAndRemoveUntil(ctx, '/', (_) => false),
                    child: const Text('Restart App'),
                  ),
                ]),
              ),
            );
        return child!;
      },
    );
  }
}

/// Checks for a stored JWT; if present and not expired, goes to MapScreen.
/// Otherwise clears session and shows LoginScreen.
class LaunchGate extends StatefulWidget {
  const LaunchGate({super.key});
  @override
  State<LaunchGate> createState() => _LaunchGateState();
}

class _LaunchGateState extends State<LaunchGate> {
  late Future<bool> _authCheck;

  @override
  void initState() {
    super.initState();
    _authCheck = _loadAndValidateSession();
  }

  Future<bool> _loadAndValidateSession() async {
    await SessionManager.instance.loadFromPrefs();
    final token = await SessionManager.instance.jwt ?? '';
    final userId = await SessionManager.instance.userId ?? '';
    final storedUsername = await SessionManager.instance.username ?? '';

    debugPrint(
        '🗂 Stored session: jwt_token=$token user_id=$userId username=$storedUsername');

    final valid = token.isNotEmpty && _isTokenValid(token);
    if (!valid) {
      debugPrint('🛑 JWT invalid/expired or missing, clearing session.');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('jwt');
      await prefs.remove('user_id');
      await prefs.remove('username');
      await prefs.remove('name');
      await SessionManager.instance.update(userId: '', jwt: '', username: '');
      return false;
    }

    // update in-memory session so downstream can rely on it (includes username)
    await SessionManager.instance
        .update(userId: userId, jwt: token, username: storedUsername);
    return true;
  }

  bool _isTokenValid(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      String payload = parts[1];

      // base64url decode with padding
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final Map<String, dynamic> jsonPayload = jsonDecode(decoded);

      final expVal = jsonPayload['exp'];
      if (expVal == null) return false;
      int exp;
      if (expVal is int) {
        exp = expVal;
      } else if (expVal is String) {
        exp = int.tryParse(expVal) ?? 0;
      } else if (expVal is double) {
        exp = expVal.toInt();
      } else {
        return false;
      }

      final nowSeconds = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      if (exp <= nowSeconds) return false; // expired

      if (jsonPayload.containsKey('nbf')) {
        final nbfVal = jsonPayload['nbf'];
        int nbf;
        if (nbfVal is int) {
          nbf = nbfVal;
        } else if (nbfVal is String) {
          nbf = int.tryParse(nbfVal) ?? 0;
        } else if (nbfVal is double) {
          nbf = nbfVal.toInt();
        } else {
          nbf = 0;
        }
        if (nbf > nowSeconds) return false; // not yet valid
      }

      return true;
    } catch (e) {
      debugPrint('Error validating JWT: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _authCheck,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError || !(snap.data ?? false)) {
          return const LoginScreen();
        }
        return const MapScreen();
      },
    );
  }
}
