// lib/main.dart

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Screens
import 'login_screen.dart';
import 'signup_screen.dart';
import 'main_screen_ui.dart';

// Configuration
import 'config.dart';

void main() {
  // If you want zone‐errors to crash immediately, uncomment:
  // BindingBase.debugZoneErrorsAreFatal = true;

  runZonedGuarded(() async {
    // 1️⃣ Initialize Flutter
    WidgetsFlutterBinding.ensureInitialized();

    // 2️⃣ Load your .env file
    await dotenv.load(fileName: '.env');

    // 3️⃣ Validate that all required variables are present
    Config.validate();

    // 4️⃣ Set Mapbox token
    MapboxOptions.setAccessToken(dotenv.get('MAPBOX_ACCESS_TOKEN'));

    // 5️⃣ Launch the app
    runApp(const LinkUpApp());
  }, (error, stack) {
    // Catches any uncaught errors in the zone
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
      theme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => const LaunchGate(),
        '/login': (_) => const LoginScreen(),
        '/signup': (_) => const SignupScreen(),
        '/map': (_) => const MapScreen(),
      },
      builder: (context, child) {
        ErrorWidget.builder = (details) => Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
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
                      onPressed: () => Navigator.pushNamedAndRemoveUntil(
                          context, '/', (r) => false),
                      child: const Text('Restart App'),
                    ),
                  ],
                ),
              ),
            );
        return child!;
      },
    );
  }
}

class LaunchGate extends StatefulWidget {
  const LaunchGate({super.key});
  @override
  State<LaunchGate> createState() => _LaunchGateState();
}

class _LaunchGateState extends State<LaunchGate> {
  late Future<bool> _authCheckFuture;

  @override
  void initState() {
    super.initState();
    _authCheckFuture = _checkAuthStatus();
  }

  Future<bool> _checkAuthStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      return token != null && token.isNotEmpty;
    } catch (e) {
      debugPrint('Auth error: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _authCheckFuture,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Authentication service unavailable'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () =>
                        setState(() => _authCheckFuture = _checkAuthStatus()),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        return (snap.data ?? false)
            ? const MapScreen()
            : const LoginScreen();
      },
    );
  }
}
