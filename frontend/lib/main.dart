// ███  main.dart  ███
//
// App bootstrap + top-level routes.
//
// PRODUCTION FLOW
// ─────────────────────────────────────────────────────
// 1. Ensure Flutter bindings
// 2. Load .env
// 3. Validate config
// 4. Set Mapbox token
// 5. Run LinkUpApp() → LaunchGate decides Login vs Map
//
// DEV SEED (temporary helper while building UI)
// ─────────────────────────────────────────────────────
// To work on “signed-in-only” screens without hitting the backend,
// we seed a fake session (jwt + userId) into SessionManager *before*
// running the app. Remove this when shipping.
//
// Search for  >>> DEV SEED BEGIN <<<  to find the block.
//
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
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

    // No dev‑seed: always require real login/signup first.
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
      darkTheme: ThemeData(colorSchemeSeed: Colors.deepPurple, useMaterial3: true, brightness: Brightness.dark),
      initialRoute: '/',
      routes: {
        '/':      (_) => const LaunchGate(),
        '/login': (_) => const LoginScreen(),
        '/signup':(_) => const SignupScreen(),
        '/map':   (_) => const MapScreen(),
      },
      builder: (ctx, child) {
        ErrorWidget.builder = (details) => Scaffold(
          body: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                Config.isProduction ? 'Something went wrong' : details.exception.toString(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(ctx, '/', (_) => false),
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

/// Checks for a stored JWT; if present, goes to MapScreen, else LoginScreen.
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
    _authCheck = SessionManager.instance.jwt
        .then((t) => t != null && t.isNotEmpty)
        .catchError((_) => false);
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
