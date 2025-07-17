// main_screen.dart
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'config.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:permission_handler/permission_handler.dart';
import 'profile_screen.dart';

/* ─────────── project-local model ─────────── */
import 'models.dart'; // contains `Building`

/* ────────────── constants ────────────── */
const _styleUri = 'mapbox://styles/its-aymann/cmccryahv002f01s249cg9lpg';

const _hlSrc = 'campus_hl_src'; // highlight circle source id
const _hlLay = 'campus_hl_fill'; // …and its fill-layer id
const _circleRadiusMeters = 5000;
const _hlLine = 'campus_hl_border'; // border line-layer id
final _borderColor = ui.Color.fromARGB(255, 54, 79, 107); // a calm blue-gray

final _badgeColor = const ui.Color.fromARGB(180, 76, 175, 80); // semi-transparent


// Somewhere near the top of map_screen.dart -- outside any class
class Place {
  final String id;
  final String name;
  final String category;
  final mapbox.Position coord;

  /// NEW – human-readable address (can be empty)
  final String address;

  const Place({
    required this.id,
    required this.name,
    required this.category,
    required this.coord,
    this.address = '',
  });
}

// ──────────────────────────────────────────────────────────────
//  Remote search helper – Mapbox *Search Box* API
// ──────────────────────────────────────────────────────────────
/* ───────────────── MapboxRemoteSearch ───────────────── */
/* ───────────────── MapboxRemoteSearch ───────────────── */
class MapboxRemoteSearch {
  static const _token =
      'pk.eyJ1IjoiaXRzLWF5bWFubiIsImEiOiJjbWNiMGd3OXQwNDN3MmtvZmtteW9wdWloIn0.LNn78rWGpjC2g81fTb3YRw';

  final String _session = const Uuid().v4();

  /* ───────── heuristics ───────── */

  bool _biasByProximity(String q) {
    final words = q.trim().split(RegExp(r'\s+'));
    return words.length == 1 && q.trim().length <= 4;
  }

  /* ───────── /suggest ───────── */

  Future<List<Place>> suggest(String q, {mapbox.Position? proximity}) async {
    if (q.trim().length < 2) return [];

    final url = _sbUrl('suggest', {
      'q': q,
      'types': 'poi,place,address',
      'limit': '10',
      if (proximity != null && _biasByProximity(q))
        'proximity': '${proximity.lng},${proximity.lat}',
    });

    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) return [];

    final raw = (jsonDecode(res.body)['suggestions'] as List);
    var places = raw.map(_rowToPlace).toList();

    /* re-rank by name similarity for longer queries */
    if (q.trim().length > 4) {
      final tokens = q.toLowerCase().split(RegExp(r'\s+'));
      int score(Place p) =>
          tokens.where((t) => p.name.toLowerCase().contains(t)).length;
      places.sort((a, b) => score(b).compareTo(score(a)));
    }

    return places;
  }

  /* ───────── /retrieve ───────── */

  Future<Place?> retrieve(String id) async {
    // correct URL ↴
    final url =
        'https://api.mapbox.com/search/searchbox/v1/retrieve/'
        '$id?session_token=$_session&access_token=$_token';

    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) return null;

    final feature = (jsonDecode(res.body)['features'] as List).first;

    /* 1️⃣  pull lon / lat from geometry or bbox */
    double? lng, lat;

    final geom = feature['geometry'] as Map?;
    if (geom != null) {
      final c = _centroid(geom);
      lng = c['lng']; // may still be null
      lat = c['lat'];
    }

    if ((lng == null || lat == null) && feature['bbox'] is List) {
      final b = (feature['bbox'] as List).map((e) => (e as num).toDouble());
      lng = (b.elementAt(0) + b.elementAt(2)) / 2;
      lat = (b.elementAt(1) + b.elementAt(3)) / 2;
    }

    if (lng == null || lat == null) return null; // truly hopeless

    return Place(
      id: id,
      name: feature['properties']['name'],
      category:
      (feature['properties']['category'] ?? feature['properties']['feature_type'] ?? 'poi')
      .toString()
      .toLowerCase()
      .contains('university')
        ? 'university'
        : feature['properties']['category'] ?? feature['properties']['feature_type'] ?? 'poi',
      address: feature['properties']['full_address'] ??
         feature['properties']['place_formatted'] ??
         feature['properties']['name_context'] ??
         feature['properties']['context']?.toString() ??
         '',
      coord: mapbox.Position(lng, lat),
    );
  }

  /* ───────── helpers ───────── */

  /// quick & dirty centroid for Point / LineString / Polygon / MultiPolygon
  Map<String, double?> _centroid(Map geom) {
    final t = geom['type'];
    final coords = geom['coordinates'];

    List<List> _flatten(dynamic c) {
      if (c is List && c.isNotEmpty && c.first is! num) {
        return c.expand(_flatten).toList();
      }
      return [c as List];
    }

    if (t == 'Point') {
      return {
        'lng': (coords[0] as num).toDouble(),
        'lat': (coords[1] as num).toDouble(),
      };
    }

    if (t == 'LineString' ||
        t == 'MultiLineString' ||
        t == 'Polygon' ||
        t == 'MultiPolygon') {
      final flat = _flatten(coords);
      double sumX = 0, sumY = 0;
      for (final p in flat) {
        sumX += (p[0] as num).toDouble();
        sumY += (p[1] as num).toDouble();
      }
      return {'lng': sumX / flat.length, 'lat': sumY / flat.length};
    }

    return {'lng': null, 'lat': null};
  }

Place _rowToPlace(dynamic s) {
  double lng = 0, lat = 0;
  final centre = s['center'];
  if (centre is List && centre.length == 2) {
    lng = (centre[0] as num).toDouble();
    lat = (centre[1] as num).toDouble();
  }

  final rawCategory = s['feature_type']?.toString().toLowerCase();
  final isUniversity = rawCategory != null && rawCategory.contains('university');

  return Place(
    id: s['mapbox_id'],
    name: s['name'],
    category: isUniversity
        ? 'university'
        : s['feature_type']?.toString() ?? 'poi',
    address: s['full_address'] ??
         s['place_formatted'] ??
         s['name_context'] ??
         s['context']?.toString() ??
         '',
    coord: mapbox.Position(lng, lat),
  );
}


  String _sbUrl(String path, Map<String, String> q) =>
      'https://api.mapbox.com/search/searchbox/v1/$path?'  
      '${q.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}&'
      'session_token=$_session&access_token=$_token';
}

class _PlaceSearchDelegate extends SearchDelegate<Place?> {
  final MapboxRemoteSearch remote;
  final mapbox.Position? proximity; // user location for smarter ranking
  _PlaceSearchDelegate(this.remote, this.proximity);

  @override
  List<Widget>? buildActions(BuildContext ctx) => [
    if (query.isNotEmpty)
      IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];

  @override
  Widget? buildLeading(BuildContext ctx) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(ctx, null),
  );

  @override
  Widget buildSuggestions(BuildContext ctx) {
    // Nothing on an empty query – you asked for this ☺
    if (query.isEmpty) return const SizedBox();

    return FutureBuilder<List<Place>>(
      future: remote.suggest(query, proximity: proximity),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final results = snap.data!;
        if (results.isEmpty) {
          return const Center(child: Text('No matches'));
        }

        return ListView.separated(
          itemCount: results.length,
          separatorBuilder: (_, __) => const Divider(height: 0),
          itemBuilder: (_, i) {
            final p = results[i];
            return ListTile(
              title: Text(p.name),
              subtitle: Text(
                (p.address.isNotEmpty) ? p.address : p.category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () async {
                final full = await remote.retrieve(p.id) ?? p;
                close(ctx, full);
              },
            );
          },
        );
      },
    );
  }

  // Same view for the final “results” screen
  @override
  Widget buildResults(BuildContext ctx) => buildSuggestions(ctx);
}

final mainCampusBadge = Building(
  id: 'campus',
  name: 'University of Michigan',
  lat: 42.2769,
  lng: -83.7412,
  spaces: [],
);

// Any source-layer IDs that should receive a “COMMUNITY” tag.
const Set<String> kCommunityLayers = {
  'all-US-uni',
  'top_us_universities_full-cushtv',
  'all-uni-logos-940kmm', // ← add
};

/* ═══════════════════════════════════ MAP SCREEN ══════════════════════════════════ */
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

// ─── Mapbox Directions access token ───
const _accessToken =
    'pk.eyJ1IjoiaXRzLWF5bWFubiIsImEiOiJjbWNiMGd3OXQwNDN3MmtvZmtteW9wdWloIn0.LNn78rWGpjC2g81fTb3YRw';

// Routing / ETA
Map<String, int> _etaMinutes = {}; //  {"drive": 10, "bike": 22 …}
bool _showAllEtas = false; //  toggled when the pill is tapped
String _activeMode = 'drive'; //  which poly-line is drawn

// current POI tags & flags
bool _isCommunity = false; // ← new flag
List<String> _selectedTags = [];

// Layers whose features should count as “community”.
// Add more IDs here as you bring more datasets online.
const Set<String> _communityLayers = {
  'all-US-uni',
  'top_us_universities_full-cushtv',
  'all-uni-logos-940kmm', // ← add
};

class FullscreenImagePage extends StatelessWidget {
  final String imageUrl;
  const FullscreenImagePage({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Image.network(imageUrl, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

// drop this anywhere in the file (outside a class is fine)
/// A full-screen, pinch-zoomable image viewer.
Future<void> _showPhotoViewer(BuildContext ctx, String url) {
  final size = MediaQuery.of(ctx).size; // screen WxH for constraints

  return Navigator.of(ctx).push(
    PageRouteBuilder(
      opaque: false, // keeps system bar colours
      pageBuilder: (_, __, ___) => Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            /// ----- the picture -----
            Center(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Hero(
                  tag: url,
                  child: SizedBox(
                    // <── impose *tight* constraints
                    width: size.width,
                    height: size.height,
                    child: Image.network(
                      url,
                      fit: BoxFit.contain, // now it can grow to the edges
                      loadingBuilder: (_, img, p) =>
                          p == null ? img : const CircularProgressIndicator(),
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            /// ----- close “×” -----
            Positioned(
              top: MediaQuery.of(ctx).padding.top + 12,
              left: 12,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: Navigator.of(ctx).pop,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MapScreenState extends State<MapScreen> {
  mapbox.Position _camCenter =
      mapbox.Position(mainCampusBadge.lng, mainCampusBadge.lat);
  double         _camZoom   = 4.2;
  /* ---------------- runtime fields ---------------- */
  // ─── at the top of _MapScreenState ───
  bool _mapReady = false;
  mapbox.MapboxMap? _map;
  mapbox.PointAnnotationManager? _annMgr;
  mapbox.PointAnnotation? _userPinAnn;
  mapbox.FeatureCollection? _universities;
  List<String> _selectedPhotos = [];
  bool _panelVisible = false; // NEW
  double get _panelHeight => MediaQuery.of(context).size.height * 0.45;
  String? _name;
  String? _username;
  String? _selectedName;
  String? _selectedAddress;
  String? _selectedCategory;
  mapbox.Position? _selectedPosition; //  <-- ADD THIS
  Map<String, int> _etaMinutes = {}; //  {"drive": 10, "bike": 22 …}
  bool _showAllEtas = false; //  toggled when the pill is tapped
  String _activeMode = 'drive';
  List<String> _selectedTags = [];
  final List<Place> _placeIndex = [];
  final _remote = MapboxRemoteSearch();

// ──────────────────────────────────────────────────────────────
// 1)  _goToPlace  – called from the search FAB
// ──────────────────────────────────────────────────────────────
  Future<void> _goToPlace(Place initial) async {
  // 1️⃣  Pick up the Place (and fix its coords if they’re bogus)
  var p = initial;
  if ((p.coord.lat.abs() < 0.001 || p.coord.lng.abs() < 0.001)) {
    final fixed = await _remote.retrieve(p.id);
    if (fixed != null) p = fixed;
  }

  if (_map == null) {
    debugPrint("❌ Map not ready");
    return;
  }

  // 2️⃣  Clear any old overlays
  await _clearRoute();
  _map!.style.removeStyleLayer(_hlLay).catchError((_) {});
  _map!.style.removeStyleLayer(_hlLine).catchError((_) {});
  _map!.style.removeStyleSource(_hlSrc).catchError((_) {});

  // 3️⃣  Draw your halo if it’s a “community” place
  _isCommunity = p.category.toLowerCase() == 'university';
  if (_isCommunity) {
    await _drawHighlightCircle(p.coord);
  }

  // 4️⃣  Fire off the flyTo call *directly* on the map
  debugPrint("🛫 Flying to ${p.name} @ (${p.coord.lat}, ${p.coord.lng})");
  await _map!.flyTo(
    mapbox.CameraOptions(
      center: mapbox.Point(coordinates: p.coord),
      zoom: 14.0,
      bearing: 0,
      pitch: 0,
      padding: _edgeInsetsForRoute(context),
    ),
    mapbox.MapAnimationOptions(duration: 800),
  );

  // 5️⃣  Once the animation’s done, show your bottom panel
  Future.delayed(const Duration(milliseconds: 850), () {
    if (!mounted) return;
    debugPrint("📦 Showing panel for ${p.name}");
    _handlePlaceSelect(p);
  });
}


Future<void> _handlePlaceSelect(Place place) async {
  _selectedName = place.name;
  _selectedCategory = place.category;
  _selectedAddress = place.address;
  _selectedPosition = place.coord;
  _isCommunity = place.category.toLowerCase() == 'university' ||
               place.name.toLowerCase().contains('university');
  _selectedTags = [
    'UNIVERSITY',
    if (_isCommunity) 'COMMUNITY',
  ];

  if (_isCommunity) {
    await _drawHighlightCircle(place.coord);
  }

  // Load photo URLs
  final slug = place.name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
      .trim()
      .replaceAll(' ', '-');

  final folder = Uri.encodeComponent('PICTURES - ${place.name}');
  final baseUrl = Config.universityPicturesEndpoint(folder);
  final photos = List<String>.generate(5, (i) => '$baseUrl/${i + 1}-$slug.jpg');

  setState(() {
    // _selectedPhotos = photos;       temporarily disabled
    _panelVisible = true;
    _etaMinutes.clear();
    _showAllEtas = false;
  });

  if (_lastPos != null) {
    _fetchEta(
      'drive',
      from: mapbox.Position(_lastPos!.longitude, _lastPos!.latitude),
      to: place.coord,
    );
  }
}




  /// Returns an [MbxEdgeInsets] that leaves enough breathing-room on every
  /// side **and** reserves extra space at the bottom for the sliding panel
  /// so the route isn’t hidden behind it.
  ///
  /// `context` is only there so we can look up MediaQuery for panel-height /
  /// safe-area insets.
  mapbox.MbxEdgeInsets _edgeInsetsForRoute(BuildContext context) {
    final media = MediaQuery.of(context);
    final double panel = _panelHeight; // ≈ 45 % screen-height
    final double bottomPx =
        panel + media.padding.bottom + 24; // 24 → little gap

    return mapbox.MbxEdgeInsets(
      left: 48, // room for call-outs
      top: 48 + media.padding.top,
      right: 48,
      bottom: bottomPx,
    );
  }

  // ------------------------------------------------------------
  //  Returns an *extra* zoom-out delta based on straight-line
  //  distance between the two points.  Short trips → 0,
  //  medium → 0.8, long → 1½ zoom levels.
  // ------------------------------------------------------------
  /* ---------------------------------------------
   Haversine & zoom-heuristic: cast to double
   --------------------------------------------- */
  /* ============================================================
   HELPERS – drop these once, just above _clearRoute()
   ============================================================ */

  /// Great-circle distance (metres) between two WGS-84 points.
  double _haversineMeters(num lat1, num lon1, num lat2, num lon2) {
    const earthRadius = 6_371_000.0; // metres

    final double phi1 = _degToRad(lat1.toDouble());
    final double phi2 = _degToRad(lat2.toDouble());
    final double deltaPhi = _degToRad((lat2 - lat1).toDouble());
    final double deltaLambda = _degToRad((lon2 - lon1).toDouble());

    final a =
        math.sin(deltaPhi / 2) * math.sin(deltaPhi / 2) +
        math.cos(phi1) *
            math.cos(phi2) *
            math.sin(deltaLambda / 2) *
            math.sin(deltaLambda / 2);

    return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  /// How many zoom levels we should *back off* for mid/long trips.
  double _zoomBumpForDistance(mapbox.Position a, mapbox.Position b) {
    final double distance = _haversineMeters(
      a.lat.toDouble(),
      a.lng.toDouble(),
      b.lat.toDouble(),
      b.lng.toDouble(),
    );

    if (distance < 5_000) return 0.0; // city hop   → leave zoom
    if (distance < 30_000) return 0.8; // 5–30 km    → small bump
    return 1.5; // 30 km +    → bigger bump
  }

  /// Nicely formats a duration that’s stored in **minutes**.
  ///
  ///  •  47    →  "47 min"
  ///  •  70    →  "1 h 10 min"
  ///  •  1520  →  "1 d 1 h 20 min"
  String _prettyMinutes(int mins) {
    if (mins >= 1440) {
      // 1 day+
      final d = mins ~/ 1440;
      final h = (mins % 1440) ~/ 60;
      final m = mins % 60;
      return [
        if (d > 0) '$d d,',
        if (h > 0) '$h h,',
        if (m > 0) '$m min',
      ].join(' ');
    }

    if (mins >= 60) {
      // 1 h – 23 h 59 min
      final h = mins ~/ 60;
      final m = mins % 60;
      return m == 0 ? '$h h,' : '$h h, $m min';
    }

    return '$mins min'; // < 1 h
  }

  Future<void> _clearRoute() async {
    if (_map == null) return;
    final style = _map!.style;
    if (await style.styleLayerExists('route_layer')) {
      await style.removeStyleLayer('route_layer');
    }
    if (await style.styleSourceExists('route_src')) {
      await style.removeStyleSource('route_src');
    }
  }

  Future<void> _fetchEta(
    String mode, {
    required mapbox.Position from,
    required mapbox.Position to,
  }) async {
    final profile = switch (mode) {
      'drive' => 'driving-traffic',
      'bike' => 'cycling',
      'walk' => 'walking',
      _ => 'driving-traffic',
    };

    final url =
        'https://api.mapbox.com/directions/v5/mapbox/$profile/'
        '${from.lng},${from.lat};${to.lng},${to.lat}'
        '?overview=false&access_token=$_accessToken';

    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) return; // graceful-fail

    final data = jsonDecode(res.body);
    if ((data['routes'] as List).isEmpty) return;

    final secs = (data['routes'][0]['duration'] as num).toDouble();
    setState(() => _etaMinutes[mode] = (secs / 60).round());
  }

  // ──────────────────────────────────────────────────────────────
  //  Draw the purple route poly-line + zoom the camera so BOTH
  //  the blue-dot (user) and destination pin are visible *above*
  //  the bottom sheet — works for city hops or cross-state drives.
  // ──────────────────────────────────────────────────────────────
  /* ═══════════════════════════════════════════════════════════
   Drop this OVER your current _drawRoute implementation.
════════════════════════════════════════════════════════════ */
  Future<void> _drawRoute(
    String mode, {
    required mapbox.Position from, // blue-dot (lng, lat)
    required mapbox.Position to, // destination (lng, lat)
  }) async {
    /* 1. Call Mapbox Directions ───────────────────────────── */
    final profile = switch (mode) {
      'drive' => 'driving-traffic',
      'bike' => 'cycling',
      'walk' => 'walking',
      _ => 'driving-traffic',
    };

    final url =
        'https://api.mapbox.com/directions/v5/mapbox/$profile/'
        '${from.lng},${from.lat};${to.lng},${to.lat}'
        '?geometries=geojson&overview=full&access_token=$_accessToken';

    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) return; // graceful-fail
    final data = jsonDecode(res.body);
    if ((data['routes'] as List).isEmpty) return;

    final route = data['routes'][0];
    final secs = (route['duration'] as num).toDouble();
    final coords = (route['geometry']['coordinates'] as List)
        .cast<List>()
        .map((c) => mapbox.Position(c[0] as double, c[1] as double))
        .toList();

    /* 2.  ETA for the UI  */
    setState(() => _etaMinutes[mode] = (secs / 60).round());

    /* 3.  Draw (or refresh) the purple poly-line  */
    const srcId = 'route_src';
    const layId = 'route_layer';
    final style = _map!.style;

    if (await style.styleLayerExists(layId))
      await style.removeStyleLayer(layId);
    if (await style.styleSourceExists(srcId))
      await style.removeStyleSource(srcId);

    await style.addSource(
      mapbox.GeoJsonSource(
        id: srcId,
        data: jsonEncode({
          'type': 'Feature',
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              for (final p in coords) [p.lng, p.lat],
            ],
          },
        }),
      ),
    );

    await style.addLayer(
      mapbox.LineLayer(
        id: layId,
        sourceId: srcId,
        lineColor: Colors.deepPurple.value,
        lineWidth: 4,
        lineOpacity: 0.8,
      ),
    );

    /* 4.  Build a *bounding box* around the ENTIRE route  */
    double minLat = double.infinity, maxLat = -double.infinity;
    double minLng = double.infinity, maxLng = -double.infinity;

    for (final p in coords) {
      final double dLat = p.lat.toDouble();
      final double dLng = p.lng.toDouble();

      if (dLat < minLat) minLat = dLat;
      if (dLat > maxLat) maxLat = dLat;
      if (dLng < minLng) minLng = dLng;
      if (dLng > maxLng) maxLng = dLng;
    }

    // include blue-dot & destination pins explicitly
    minLat = math.min(minLat, math.min(from.lat.toDouble(), to.lat.toDouble()));
    maxLat = math.max(maxLat, math.max(from.lat.toDouble(), to.lat.toDouble()));
    minLng = math.min(minLng, math.min(from.lng.toDouble(), to.lng.toDouble()));
    maxLng = math.max(maxLng, math.max(from.lng.toDouble(), to.lng.toDouble()));

    final bounds = mapbox.CoordinateBounds(
      southwest: mapbox.Point(
        //  ◄─ expects Point
        coordinates: mapbox.Position(minLng, minLat),
      ),
      northeast: mapbox.Point(coordinates: mapbox.Position(maxLng, maxLat)),
      infiniteBounds: false,
    );

    /* 5.  Ask Mapbox for a camera that fits those bounds  */
    var cam = await _map!.cameraForCoordinateBounds(
      bounds,
      _edgeInsetsForRoute(context), // leaves room for bottom sheet
      0, // bearing → north-up
      0, // pitch   → 0°
      null,
      null,
    );

    /* 6.  Clamp zoom so we never over-zoom on long trips */
    const kMinZoom = 3.5; // continent-ish
    const kMaxZoom = 17.5; // street level

    if (cam.zoom != null) {
      final clamped = cam.zoom!.clamp(kMinZoom, kMaxZoom);

      cam = mapbox.CameraOptions(
        center: cam.center,
        zoom: clamped,
        bearing: cam.bearing,
        pitch: cam.pitch,
        padding: cam.padding,
      );
    }
  }

  ActionChip _modeChip(String mode, IconData icon) {
    final mins = _etaMinutes[mode];
    final selected = _activeMode == mode;

    return ActionChip(
      avatar: Icon(
        icon,
        size: 18,
        color: selected ? Colors.white : Colors.deepPurple,
      ),
      label: Text(
        mins != null ? _prettyMinutes(mins) : '…',
        style: TextStyle(color: selected ? Colors.white : Colors.deepPurple),
      ),
      backgroundColor: selected ? Colors.deepPurple : Colors.deepPurple.shade50,

      // ── HERE ──
      onPressed: mins == null
          ? null
          : () async {
              _activeMode = mode;

              // 1️⃣ grab the current camera centre (a Point)
              final camState = await _map!.getCameraState();
              final pt = camState.center; // mapbox.Point

              // 2️⃣ convert Point  ➜ Position
              final toPos = mapbox.Position(
                pt.coordinates.lng,
                pt.coordinates.lat,
              );

              // 3️⃣ draw the route
              await _drawRoute(
                mode,
                from: mapbox.Position(_lastPos!.longitude, _lastPos!.latitude),
                to: toPos,
              );

              setState(() {}); // refresh the UI
            },
    );
  }

  /// Draw a simple straight-line “route” from the blue-dot (user) to the
  /// selected POI.  Replace with real Directions API when you’re ready.
  /// Very-simple demo: draw a straight purple line from the blue-dot
  /// (user location) to the currently-selected POI.
  Future<void> _drawRouteToSelection() async {
    if (_map == null || _lastPos == null || _selectedPosition == null) return;

    // ── clear any previous demo line ──
    const srcId = 'temp_route_src';
    const layerId = 'temp_route_layer';
    final style = _map!.style;
    if (await style.styleLayerExists(layerId))
      await style.removeStyleLayer(layerId);
    if (await style.styleSourceExists(srcId))
      await style.removeStyleSource(srcId);

    // ── build the GeoJSON LineString ──
    final geojson = {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              [_lastPos!.longitude, _lastPos!.latitude],
              [_selectedPosition!.lng, _selectedPosition!.lat],
            ],
          },
        },
      ],
    };

    await style.addSource(
      mapbox.GeoJsonSource(id: srcId, data: jsonEncode(geojson)),
    );

    await style.addLayer(
      mapbox.LineLayer(
        id: layerId,
        sourceId: srcId,
        lineColor: Colors.deepPurple.value,
        lineWidth: 4,
        lineOpacity: 0.85,
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Demo route drawn – replace with Directions API later 📍',
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }

  bool _showReturn = false;
  geo.Position? _lastPos;

  /* ═════════════════ widget tree ═════════════════ */
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      children: [
        mapbox.MapWidget(
          styleUri: _styleUri,
          cameraOptions: mapbox.CameraOptions(
            center: mapbox.Point(coordinates: _camCenter),
            zoom: _camZoom,
          ),
          onMapCreated: _onMapCreated,
          onStyleLoadedListener: (_) {
            setState(() => _mapReady = true);
          },
          onCameraChangeListener: (evt) {
            final newZoom   = evt.cameraState.zoom;
            final newCenter = evt.cameraState.center.coordinates;
            // only rebuild if *either* changed
            if (newZoom != _camZoom || newCenter != _camCenter) {
              setState(() {
                _camZoom   = newZoom;
                _camCenter = newCenter;
              });
              _scaleUserPin();
            }
          },
          onTapListener: (c) => _handleMapTap(c.point),
        ),

        // ───────── floating info card ─────────
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          left: 0,
          right: 0,
          bottom: _panelVisible ? 0 : -_panelHeight, // slide up / down
          height: _panelHeight,
          child: _buildDetailCard(),
        ),

        /* Explore-mode pill — always visible */
        Positioned(
          top:
              MediaQuery.of(context).padding.top +
              8, // keeps it clear of the notch
          left: 12,
          child: ElevatedButton(
            onPressed: _resetView,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(.92),
              foregroundColor: Colors.deepPurple,
              elevation: 0,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            ),
            child: const Text(
              'Explore Mode',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        /* ───── 🔍  NEW  search FAB (top-right) ───── */
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          right: 12,
          child: FloatingActionButton.small(
            heroTag: 'search_btn',
            backgroundColor: Colors.white,
            foregroundColor: Colors.deepPurple,
            onPressed: () async {
              final picked = await showSearch<Place?>(
                context: context,
                delegate: _PlaceSearchDelegate(
                  _remote,
                  _lastPos != null
                      ? mapbox.Position(_lastPos!.longitude, _lastPos!.latitude)
                      : null,
                ),
              );
              if (picked != null) {
                if (_mapReady) {
                  _goToPlace(picked);
                } else {
                  debugPrint("⏳ Map not ready — retrying shortly...");
                  Future.delayed(const Duration(milliseconds: 300), () {
                    if (_mapReady) _goToPlace(picked);
                    else debugPrint("❌ Map still not ready — flyTo skipped.");
                  });
                }
              }
            },
            child: const Icon(Icons.search),
          ),
        ),
        /* profile FAB */
        Positioned(
          right: 20,
          bottom: 80, // just above the locate-me button
          child: FloatingActionButton.small(
            heroTag: 'profile_btn',
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
            },
            child: const Icon(Icons.person),
          ),
        ),

        /* locate-me FAB */
        Positioned(
          right: 20,
          bottom: 20,
          child: FloatingActionButton.small(
            heroTag: 'locate_me',
            backgroundColor: Colors.white,
            foregroundColor: Colors.blueAccent,
            onPressed: _flyToUser,
            child: const Icon(Icons.my_location_rounded),
          ),
        ),
      ],
    ),
  );

  // ──────────────────────────────────────────────────────────────
  /// Sliding bottom sheet that appears after a POI tap.
  Widget _buildDetailCard() {
    // short-circuit if nothing selected
    if (_selectedName == null) return const SizedBox.shrink();

    return Material(
      elevation: 12,
      color: const Color(0xFFF7F2FD), // gentle lilac
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: SafeArea(
        top: false,
        child: Padding(
  padding: EdgeInsets.fromLTRB(
    20,
    16,
    20,
    12 + MediaQuery.of(context).viewPadding.bottom,
  ),
  child: ConstrainedBox(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.85,
    ),
    child: SingleChildScrollView(
      child: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    // Top-right Close X button
    Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8.0, right: 4.0),
          child: IconButton(
            icon: const Icon(Icons.close_rounded, size: 24, color: Colors.deepPurple),
            onPressed: () async {
              await _clearRoute();
              setState(() => _panelVisible = false);
            },
            tooltip: 'Close',
          ),
        ),
      ],
    ),

    /* ───── TAGS ───── */
    Wrap(
      spacing: 8,
      runSpacing: 4,
      children: _selectedTags.map(_tagChip).toList(),
    ),
    const SizedBox(height: 12),

    /* ───── NAME ───── */
    Text(
      _selectedName!,
      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
    ),

    /* ───── ADDRESS W/ PIN ICON ───── */
    const SizedBox(height: 4),
    Row(
      children: [
        const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            _selectedAddress?.isNotEmpty == true ? _selectedAddress! : 'Address unavailable',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ),
      ],
    ),


              /* ───── PHOTO STRIP ───── */
              const SizedBox(height: 16),
              SizedBox(
                height: 92,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedPhotos.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) {
                    final url = _selectedPhotos[i];

                    // thumbnail widget
                    final thumb = ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Hero(
                        // ── Hero tag
                        tag: url,
                        child: 
                              Image.network(
                                url,
                                width: 140,
                                height: 92,
                                fit: BoxFit.cover,
                                loadingBuilder: (_, child, progress) {
                                  if (progress == null) return child;
                                  return Center(child: CircularProgressIndicator(
                                    value: progress.expectedTotalBytes != null 
                                        ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                        : null,
                                  ));
                                },
                                errorBuilder: (_, __, ___) => Container(
                                  width: 140,
                                  height: 92,
                                  color: Colors.grey.shade200,
                                  child: Icon(Icons.broken_image, color: Colors.grey.shade400),
                                ),
                              )
                      ),
                    );

                    // make it tappable
                    return GestureDetector(
                      onTap: () =>
                          _showPhotoViewer(context, url), // helper we added
                      child: thumb,
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),


              /* ───── ETA  /  ACTION BUTTONS ───── */
              if (_etaMinutes['drive'] != null && !_showAllEtas)
                Center(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (_lastPos == null || _selectedPosition == null) return;
                      await _drawRoute(
                        'drive',
                        from: mapbox.Position(
                          _lastPos!.longitude,
                          _lastPos!.latitude,
                        ),
                        to: _selectedPosition!,
                      );
                      setState(() {
                        _activeMode = 'drive';
                        _showAllEtas = true;
                      });
                      // fire off bike + walk ETAs in background
                      _fetchEta(
                        'bike',
                        from: mapbox.Position(
                          _lastPos!.longitude,
                          _lastPos!.latitude,
                        ),
                        to: _selectedPosition!,
                      );
                      _fetchEta(
                        'walk',
                        from: mapbox.Position(
                          _lastPos!.longitude,
                          _lastPos!.latitude,
                        ),
                        to: _selectedPosition!,
                      );
                    },
                    icon: const Icon(
                      Icons.directions_car_filled_rounded,
                      size: 20,
                    ),
                    label: Text(_prettyMinutes(_etaMinutes['drive']!)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                )
              else if (_showAllEtas)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _modeChip('drive', Icons.directions_car_filled_rounded),
                    _modeChip('bike', Icons.directions_bike_rounded),
                    _modeChip('walk', Icons.directions_walk_rounded),
                  ],
                )
              else
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Colors.deepPurple,
                    ),
                  ),
                ),


            ],
          ),
        ),
      ),
    )));
  }

  /// Tiny pill used by the tag wrap above.
  Widget _tagChip(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.deepPurple,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        letterSpacing: .4,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
  );

  /* ═════════════ init helpers ═════════════ */
  Future<void> _onMapCreated(mapbox.MapboxMap map) async {
  _map = map;
  _annMgr = await map.annotations.createPointAnnotationManager();
  await _addUserPinSprite();

  // 🔄 Load universities + location
  if (_universities == null) await _loadCampusDataset();
  await _initLocation();

  debugPrint("🗺️ Map created, waiting for style to load...");
}

  @override
  void initState() {
    super.initState();
    _universities = null;
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _name = prefs.getString('name');
      _username = prefs.getString('username');
    });
  }

  Future<void> _loadCampusDataset() async {
    final jsonStr = await rootBundle.loadString(
      'assets/top_us_universities_full.geojson',
    );

    final fc = mapbox.FeatureCollection.fromJson(jsonDecode(jsonStr));

    // ─── build the search index ───
    for (final feat in fc.features ?? []) {
      // ---------- names & misc ----------
      final props = Map<String, dynamic>.from(feat.properties ?? {});
      final name = (props['name'] ?? props['title'] ?? '').toString().trim();
      if (name.isEmpty) continue; // skip nameless records
      final cat = (props['type'] ?? 'place').toString();

      // ---------- read the geometry ----------
      double? lng, lat;

      // a) geometry already a mapbox.Point
      if (feat.geometry is mapbox.Point) {
        final p = feat.geometry as mapbox.Point;
        lng = p.coordinates.lng.toDouble();
        lat = p.coordinates.lat.toDouble();
      }

      // b) anything else → fall back to raw GeoJSON map
      lng ??= (feat.geometry?.toJson()['coordinates']?[0] as num?)?.toDouble();
      lat ??= (feat.geometry?.toJson()['coordinates']?[1] as num?)?.toDouble();
      if (lng == null || lat == null) continue; // not a Point ➜ ignore

      // ---------- add to in-memory index ----------
      _placeIndex.add(
        Place(
          id: 'local:$name', // ← any unique string is fine
          name: name,
          category: cat,
          coord: mapbox.Position(lng, lat),
        ),
      );
    }

    setState(() => _universities = fc);
  }

  /* ═════════════ blue user-pin helpers ═════════════ */
  Future<void> _addUserPinSprite() async {
    if (_map == null) return;
    final style = _map!.style;
    if (await style.getStyleImage('user_pin') != null) return;

    const sz = 24.0;
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec)
      ..drawCircle(
        const Offset(sz / 2, sz / 2),
        sz / 2,
        Paint()..color = Colors.blueAccent,
      )
      ..drawCircle(
        const Offset(sz / 2, sz / 2),
        sz / 2,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );

    final img = await rec.endRecording().toImage(sz.toInt(), sz.toInt());
    final data = (await img.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();

    await style.addStyleImage(
      'user_pin',
      1.0,
      mapbox.MbxImage(width: sz.toInt(), height: sz.toInt(), data: data),
      false,
      [],
      [],
      null,
    );
  }

  Future<void> _initLocation() async {
    if (!(await Permission.locationWhenInUse.request()).isGranted) return;
    _lastPos = await geo.Geolocator.getCurrentPosition();
    await _updateUserPin();
    await _flyToUser();
  }

  Future<void> _updateUserPin() async {
    if (_map == null || _annMgr == null || _lastPos == null) return;

    final point = mapbox.Point(
      coordinates: mapbox.Position(_lastPos!.longitude, _lastPos!.latitude),
    );

    try {
      // Always delete and recreate to avoid broken state after hot restart
      if (_userPinAnn != null) {
        await _annMgr!.delete(_userPinAnn!);
      }

      _userPinAnn = await _annMgr!.create(
        mapbox.PointAnnotationOptions(
          geometry: point,
          iconImage: 'user_pin',
          iconSize: 1.0,
        ),
      );
    } catch (e) {
      print('⚠️ Failed to recreate user pin: $e');
    }
  }

  void _scaleUserPin() {
    if (_userPinAnn == null || _annMgr == null) return;

    try {
      _userPinAnn!.iconSize = ((_camZoom - 10) * .4).clamp(0.7, 1.0);
      _annMgr!.update(_userPinAnn!);
    } catch (e) {
      print('⚠️ Failed to scale pin: $e');
    }
  }

  Future<void> _flyToUser() async {
    if (_map == null || _lastPos == null) return;
    await _map!.flyTo(
      mapbox.CameraOptions(
        center: mapbox.Point(
          coordinates: mapbox.Position(_lastPos!.longitude, _lastPos!.latitude),
        ),
        zoom: 13,
        bearing: 0, // ← north-up
        pitch: 0, // ← looking straight down
      ),
      mapbox.MapAnimationOptions(duration: 600),
    );
  }

  bool _tapLocked = false;

  /// If it’s a university, draw the halo; then always zoom & show a bottom sheet.
  /// User tapped the map: pick the top‐most rendered feature, zoom to it,
  /// optionally draw a halo, then slide up the info panel.
  // ──────────────────────────────────────────────────────────────
// 2)  _handleMapTap – user taps directly on the map
// ──────────────────────────────────────────────────────────────
/// User tapped the map.
/// • Pick the top rendered feature with a readable name  
/// • Extract its coordinates (or fall back to the tap)  
/// • Optionally draw a halo if it’s a university  
/// • Fly the camera and populate the bottom panel
Future<void> _handleMapTap(mapbox.Point geoTap) async {
  if (_map == null) return;

  // ── 1. clear any old routes / halos ──
  await _clearRoute();
  _map!.style.removeStyleLayer(_hlLay).catchError((_) {});
  _map!.style.removeStyleLayer(_hlLine).catchError((_) {});
  _map!.style.removeStyleSource(_hlSrc).catchError((_) {});

  // ── 2. hit‑test ──
  final screenPt = await _map!.pixelForCoordinate(geoTap);
  final hits = await _map!.queryRenderedFeatures(
    mapbox.RenderedQueryGeometry.fromScreenCoordinate(screenPt),
    mapbox.RenderedQueryOptions(),
  );

  // ── 3. pick the first feature with a “name”‐property ──
  final rendered = hits
      .whereType<mapbox.QueriedRenderedFeature>()
      .firstWhereOrNull((q) {
        final raw = (q.queriedFeature?.feature['properties'] as Map?) ?? {};
        final keys = raw.keys.map((k) => k.toString().toLowerCase()).toSet();
        return keys.intersection({'name','name_en','title','text'}).isNotEmpty;
      });
  if (rendered == null) return;

  // ── 4. safe‐cast & extract geometry + properties ──
  final featureMap = rendered.queriedFeature!.feature as Map;
  final geom       = featureMap['geometry'] as Map?;
  final props      = Map<String, dynamic>.from((featureMap['properties'] as Map?) ?? {});

  final name = (props['name'] ??
                props['name_en'] ??
                props['title'] ??
                props['text'] ??
                'Unknown').toString();

  double lat, lng;
  if (geom != null && geom['type'] == 'Point') {
    final coords = geom['coordinates'] as List;
    lng = (coords[0] as num).toDouble();
    lat = (coords[1] as num).toDouble();
  } else {
    lng = geoTap.coordinates.lng.toDouble(); 
    lat = geoTap.coordinates.lat.toDouble(); 
  }
  final destPos = mapbox.Position(lng, lat);

  final sourceLayer  = rendered.queriedFeature!.sourceLayer ?? '';
  final isUniversity = _communityLayers.any((id) => sourceLayer.contains(id));

  debugPrint('🧩 tapped $name   [$sourceLayer]');

  // ── 5. optional halo ──
  if (isUniversity) {
    await _drawHighlightCircle(destPos);
    setState(() => _showReturn = true);
  }

  // ── 6. DEBUG + fly ──
  debugPrint('🛫 Flying to $name @ ($lat, $lng)');   // ✅ new debug line
  final bump = _lastPos != null
      ? _zoomBumpForDistance(destPos, mapbox.Position(_lastPos!.longitude, _lastPos!.latitude))
      : 0.0;
  final targetZoom = (14.0 - bump).clamp(3.0, 17.0);

  await _map!.flyTo(
    mapbox.CameraOptions(
      center: mapbox.Point(coordinates: destPos),
      zoom: targetZoom,
      padding: _edgeInsetsForRoute(context),
    ),
    mapbox.MapAnimationOptions(duration: 700),
  );

  // ── 7. populate & show the bottom sheet ──
  setState(() {
    _selectedName     = name;
    _selectedCategory = isUniversity ? 'university' : (props['category'] ?? props['type'] ?? '').toString();
    _selectedTags     = [
      _selectedCategory!.toUpperCase(),
      if (isUniversity) 'COMMUNITY'
    ];
    _selectedPosition = destPos;
    // rebuild photo URLs
    final slug = name.toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
        .trim()
        .replaceAll(' ', '-');
    final folder = Uri.encodeComponent('PICTURES - $name');
    final baseUrl = Config.universityPicturesEndpoint(folder);
    _selectedPhotos = List<String>.generate(5, (i) => '$baseUrl/${i+1}-$slug.jpg');

    _panelVisible = true;
    _etaMinutes.clear();
    _showAllEtas = false;
  });

  // ── 8. kick off ETA fetch ──
  if (_lastPos != null) {
    _fetchEta(
      'drive',
      from: mapbox.Position(_lastPos!.longitude, _lastPos!.latitude),
      to: destPos,
    );
  }
}



  double _degToRad(double d) => d * math.pi / 180;

  /* draw orange circle (~150 m) */
  Future<void> _drawHighlightCircle(mapbox.Position center) async {
    if (_map == null) return;
    const segments = 32;
    const R = 6378137.0; // Earth radius (m)

    final dLat = (_circleRadiusMeters / R) * 180 / math.pi;
    final dLng = dLat / math.cos(center.lat.toDouble() * math.pi / 180);

    final ring = List.generate(segments, (i) {
      final t = 2 * math.pi * i / (segments - 1);
      return [
        center.lng.toDouble() + dLng * math.cos(t),
        center.lat.toDouble() + dLat * math.sin(t),
      ];
    });

    final style = _map!.style;

    // Remove previous circle and border layers
    if (await style.styleLayerExists(_hlLine))
      await style.removeStyleLayer(_hlLine);
    if (await style.styleLayerExists(_hlLay))
      await style.removeStyleLayer(_hlLay);
    if (await style.styleSourceExists(_hlSrc))
      await style.removeStyleSource(_hlSrc); // <- now safe

    await style.addSource(
      mapbox.GeoJsonSource(
        id: _hlSrc,
        data: jsonEncode({
          'type': 'FeatureCollection',
          'features': [
            {
              'type': 'Feature',
              'geometry': {
                'type': 'Polygon',
                'coordinates': [ring],
              },
            },
          ],
        }),
      ),
    );

    await style.addLayer(
      mapbox.FillLayer(
        id: _hlLay,
        sourceId: _hlSrc,
        fillColor: _badgeColor.value,
        fillOpacity: 0.3,
      ),
    );

    await style.addLayer(
      mapbox.LineLayer(
        id: _hlLine,
        sourceId: _hlSrc,
        lineColor: _borderColor.value,
        lineWidth: 2.5,
        lineOpacity: 0.65,
      ),
    );
  }

  /* ═════════════════ view reset / cleanup ════════════════ */
  Future<void> _resetView() async {
    if (_map == null) return;
    final style = _map!.style;
    if (await style.styleLayerExists(_hlLine))
      await style.removeStyleLayer(_hlLine);
    if (await style.styleLayerExists(_hlLay))
      await style.removeStyleLayer(_hlLay);
    if (await style.styleSourceExists(_hlSrc))
      await style.removeStyleSource(_hlSrc);

    await _map!.flyTo(
      mapbox.CameraOptions(
        center: mapbox.Point(
          coordinates: mapbox.Position(
            mainCampusBadge.lng,
            mainCampusBadge.lat,
          ),
        ),
        zoom: 4.2,
      ),
      mapbox.MapAnimationOptions(duration: 800),
    );
    await _clearRoute();
    setState(() {
      _showReturn = false;
      _panelVisible = false;
    });
  }

  @override
  void dispose() {
    _annMgr?.deleteAll();
    super.dispose();
  }
}

/* ═════════ utility: annotation click ═════════ */
class _PointAnnotationClickHandler
    extends mapbox.OnPointAnnotationClickListener {
  final bool Function(mapbox.PointAnnotation) onTap;
  _PointAnnotationClickHandler(this.onTap);
  @override
  bool onPointAnnotationClick(mapbox.PointAnnotation ann) => onTap(ann);
}
