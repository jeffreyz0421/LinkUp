import 'dart:async';
import 'dart:io'; // For Platform detection
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Screens
import 'login_screen.dart';
import 'main_screen.dart';
import 'signup_screen.dart';

// Configuration
import 'config.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await _initializeApp();
    runApp(const LinkUpApp());
  }, (error, stackTrace) {
    debugPrint('Uncaught error: $error\n$stackTrace');
  });
}

Future<void> _initializeApp() async {
  try {
    // Load environment variables
    await dotenv.load(fileName: '.env');

    // Set orientation only for non-iPad devices
    if (!Platform.isIOS || !(Platform.isMacOS && WidgetsBinding.instance.window.physicalSize.shortestSide > 600)) {
      await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }

    // Initialize services
    Config.validate();
    MapboxOptions.setAccessToken(dotenv.get('MAPBOX_ACCESS_TOKEN'));

    if (kDebugMode) {
      debugPrint('🚀 App initialized');
      debugPrint('🌐 Server: ${Config.serverBaseUrl}');
      debugPrint('🗺️ Mapbox token: ${dotenv.get('MAPBOX_ACCESS_TOKEN').substring(0, 6)}...');
    }
  } catch (e, stack) {
    debugPrint('Initialization error: $e\n$stack');
    if (Config.isProduction) rethrow;
  }
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
        visualDensity: VisualDensity.adaptivePlatformDensity,
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
                    context, 
                    '/', 
                    (route) => false
                  ),
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
      return prefs.getString('jwt_token')?.isNotEmpty ?? false;
    } catch (e) {
      debugPrint('Auth check error: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _authCheckFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Authentication service unavailable'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() => _authCheckFuture = _checkAuthStatus()),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        return snapshot.data == true ? const MapScreen() : const LoginScreen();
      },
    );
  }
}