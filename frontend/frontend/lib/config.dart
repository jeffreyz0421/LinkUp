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
      '${serverBaseUrl}/university_pictures/$folder';

  // --- Validation ---
  static void validate() {
    mapboxAccessToken;
    serverBaseUrl;
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
    final url = dotenv.get('GO_SERVER_HTTP', fallback: '').trim();
    
    if (url.isEmpty) {
      if (isProduction) {
        throw Exception('Server URL not configured');
      }
      debugPrint('⚠️ Using default localhost URL');
      return 'http://localhost:8080';
    }

    if (isProduction && url.startsWith('http://')) {
      throw Exception('Production requires HTTPS');
    }

    if (isDevelopment && url.startsWith('http://')) {
      debugPrint('⚠️ Development using HTTP - switch to HTTPS for testing');
    }

    return url;
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
}