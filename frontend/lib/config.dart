import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Config {
  // --- Environment Detection ---
  static bool get isProduction => kReleaseMode;
  static bool get isDevelopment => !kReleaseMode;
  static bool get isDebug => kDebugMode;

  // --- API Configuration ---
  static String get mapboxAccessToken => _getRequired('MAPBOX_ACCESS_TOKEN');
  static String get serverBaseUrl => _getServerUrl();
  static int get apiTimeout => isProduction ? 15000 : 30000; // ms

  // --- Paths/Endpoints ---
  static String universityPicturesEndpoint(String folder) =>
      '$serverBaseUrl/university_pictures/$folder';

  // --- Validation ---
  static void validate() {
    mapboxAccessToken; // Will throw if missing
    serverBaseUrl;     // Will throw if missing/invalid in production
  }

  // --- Development Tools ---
  static void printConfig() {
    if (isProduction) return;
    debugPrint('⚙️ Application Configuration:');
    debugPrint('• Environment: ${isProduction ? 'Production' : 'Development'}');
    debugPrint('• Server URL: $serverBaseUrl');
    debugPrint('• API Timeout: ${apiTimeout}ms');
    debugPrint('• Mapbox Token: ${mapboxAccessToken.substring(0, 6)}...');
  }

  // --- Private Helpers ---
  static String _getRequired(String key) {
    final value = dotenv.get(key);
    if (value.isEmpty) {
      throw Exception('Required config "$key" not found in .env');
    }
    return value;
  }

  static String _getServerUrl() {
    // first look for a GO_SERVER_HTTP override in .env
    final raw = dotenv.get('GO_SERVER_HTTP', fallback: '').trim();
    String url;

    if (raw.isEmpty) {
      // no override: pick a sensible default
      if (Platform.isAndroid) {
        url = 'http://10.0.2.2:8080';
      } else {
        if (isProduction) {
          throw Exception('Server URL not configured in production');
        }
        debugPrint('⚠️ Using default localhost URL');
        url = 'http://localhost:8080';
      }
    } else {
      // user supplied a URL: if it contains "localhost" on Android, swap it
      if (Platform.isAndroid && raw.contains('localhost')) {
        url = raw.replaceFirst('localhost', '10.0.2.2');
      } else {
        url = raw;
      }
    }

    // enforce HTTPS in prod
    if (isProduction && url.startsWith('http://')) {
      throw Exception('Production requires HTTPS URLs');
    }
    // warn in dev
    if (isDevelopment && url.startsWith('http://')) {
      debugPrint('⚠️ Development using HTTP — switch to HTTPS for testing');
    }
    return url;
  }
}
