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

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

// Screens
import 'login_screen.dart';
import 'signup_screen.dart';
import 'main_screen_ui.dart';

// Session
import 'session_manager.dart';

void main() {
  // If you want zone‐errors to crash immediately, uncomment:
  // BindingBase.debugZoneErrorsAreFatal = true;

  runZonedGuarded(() async {
    /* 1️⃣ */ WidgetsFlutterBinding.ensureInitialized();

    /* 2️⃣ */ await dotenv.load(fileName: '.env');

    /* 3️⃣ */ Config.validate();

    /* 4️⃣ */ MapboxOptions.setAccessToken(dotenv.get('MAPBOX_ACCESS_TOKEN'));

    /* ────────────────────────────────────────────────────────────────
       >>> DEV SEED BEGIN <<<

       This seeds a *fake* signed-in session so you can see Friends /
       Communities / etc. without logging in. Remove or comment out
       this block before you ship or when you’re ready to test real auth.
       ──────────────────────────────────────────────────────────────── */
    const bool kDevSeedSession = true; // DEV-ONLY toggle
    if (kDevSeedSession) {
      await SessionManager.instance.update(
        userId: 'dev-uuid-1234',      // DEV-ONLY fake user id
        jwt   : 'fake-token',         // DEV-ONLY fake token
        primaryCommunity: 'u-mich',   // DEV-ONLY fake primary community
      );
    }
    // <<< DEV SEED END >>>
    /* ──────────────────────────────────────────────────────────────── */

    /* 5️⃣ */ runApp(const LinkUpApp());
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
        // nicer crash UI during dev
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

/* ───────────────── LaunchGate ─────────────────
   Decides whether to show Login or the main Map.

   PRODUCTION: checks stored auth token (jwt) via SessionManager.
   DEV: if you left the DEV SEED block enabled in main(), LaunchGate
        will see the fake token & skip Login automatically.
*/
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
      // ✅ Use SessionManager instead of raw SharedPreferences so dev seeding works.
      final jwt = await SessionManager.instance.jwt;
      return jwt != null && jwt.isNotEmpty;
    } catch (e) {
      debugPrint('Auth check error: $e');
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

        final signedIn = snap.data ?? false;
        return signedIn ? const MapScreen() : const LoginScreen();
      },
    );
  }
}
