// map_screen.dart
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:permission_handler/permission_handler.dart';
import 'profile_screen.dart';

/* ─────────── project-local model ─────────── */
import 'models.dart';        // contains `Building`

/* ────────────── constants ────────────── */
const _styleUri = 'mapbox://styles/its-aymann/cmccryahv002f01s249cg9lpg';

const _hlSrc = 'campus_hl_src';   // highlight circle source id
const _hlLay = 'campus_hl_fill';  // …and its fill-layer id
const _circleRadiusMeters = 5000;
const _hlLine = 'campus_hl_border'; // border line-layer id
final _borderColor = ui.Color.fromARGB(255, 54, 79, 107); // a calm blue-gray


final _badgeColor = const ui.Color.fromARGB(255, 231, 245, 233);

final mainCampusBadge = Building(
  id: 'campus',
  name: 'University of Michigan',
  lat: 42.2769,
  lng: -83.7412,
  spaces: [],
);

/* ═══════════════════════════════════ MAP SCREEN ══════════════════════════════════ */
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}


class _MapScreenState extends State<MapScreen> {
  
  /* ---------------- runtime fields ---------------- */
  // ─── at the top of _MapScreenState ───

  mapbox.MapboxMap?              _map;
  mapbox.PointAnnotationManager? _annMgr;
  mapbox.PointAnnotation?        _userPinAnn;
  mapbox.FeatureCollection? _universities;
  bool _panelVisible = false;                 // NEW
  double get _panelHeight => MediaQuery.of(context).size.height * 0.33;
  String? _name;
  String? _username;
  String? _selectedName;
  String? _selectedCategory;


  
  double _zoom = 4.2;
  bool   _showReturn = false;
  geo.Position? _lastPos;

  /* ═════════════════ widget tree ═════════════════ */
  @override
  Widget build(BuildContext context) => Scaffold(
    
        body: Stack(children: [
          mapbox.MapWidget(
            styleUri: _styleUri,
            cameraOptions: mapbox.CameraOptions(
              center: mapbox.Point(
                coordinates:
                    mapbox.Position(mainCampusBadge.lng, mainCampusBadge.lat),
              ),
              zoom: _zoom,
            ),

            onMapCreated: _onMapCreated,
            onCameraChangeListener: (evt) {
              if (evt.cameraState.zoom != _zoom) {
                _zoom = evt.cameraState.zoom;
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
              bottom: _panelVisible ? 0 : -_panelHeight,   // slide up / down
              height: _panelHeight,
              child: _buildDetailCard(),
            ),


          /* return button */
          if (_showReturn)
            Positioned(
              top: 40,
              left: 20,
              child: ElevatedButton(
                onPressed: _resetView,
                child: const Text('Explore Mode'),
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
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
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
        ]),
      );

Widget _buildDetailCard() {
  return Material(
      elevation: 12,
      color: const Color(0xFFF7F2FD),
      borderRadius: const BorderRadius.only(
        topLeft:  Radius.circular(16),
        topRight: Radius.circular(16),
      ),
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: (_selectedName == null)
            ? const SizedBox.shrink()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_selectedName!,
                      style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(_selectedCategory ?? '',
                      style: const TextStyle(color: Colors.grey)),
                  const Spacer(),
                  Center(
                    child: ElevatedButton(
                      onPressed: () =>
                          setState(() => _panelVisible = false),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
      ),
    ),
  );
}


  /* ═════════════ init helpers ═════════════ */
  Future<void> _onMapCreated(mapbox.MapboxMap map) async {
  _map    = map;
  _annMgr = await map.annotations.createPointAnnotationManager();
  await _addUserPinSprite();


  if (_universities == null) await _loadCampusDataset();
  await _initLocation();
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
  try {
    final jsonStr = await rootBundle.loadString('assets/top_us_universities_full.geojson');
    final json = jsonDecode(jsonStr);
    final fc = mapbox.FeatureCollection.fromJson(json);
    setState(() => _universities = fc);
  } catch (e) {
    print('⚠️ Failed to load university dataset: $e');
  }
}


  /* ═════════════ blue user-pin helpers ═════════════ */
  Future<void> _addUserPinSprite() async {
    if (_map == null) return;
    final style = _map!.style;
    if (await style.getStyleImage('user_pin') != null) return;

    const sz = 24.0;
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec)
      ..drawCircle(const Offset(sz / 2, sz / 2), sz / 2,
          Paint()..color = Colors.blueAccent)
      ..drawCircle(const Offset(sz / 2, sz / 2), sz / 2,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);

    final img  = await rec.endRecording().toImage(sz.toInt(), sz.toInt());
    final data =
        (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();

    await style.addStyleImage(
      'user_pin', 1.0,
      mapbox.MbxImage(width: sz.toInt(), height: sz.toInt(), data: data),
      false, [], [], null,
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
    _userPinAnn!.iconSize = ((_zoom - 10) * .4).clamp(0.7, 1.0);
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
      ),
      mapbox.MapAnimationOptions(duration: 600),
    );
  }
bool _tapLocked = false;

/// React to a user-tap on the map.  
/// If a university symbol (layer **all-US-uni**) is rendered at that pixel,
/// fly the camera there and draw / refresh the orange halo.
/// React to a user‐tap on the map.
/// If it’s a university, draw the halo; then always zoom & show a bottom sheet.
Future<void> _handleMapTap(mapbox.Point geoTap) async {
  if (_map == null) return;

  // 1) get the screen point & hit-test
  final screenPt = await _map!.pixelForCoordinate(geoTap);
  final hits = await _map!.queryRenderedFeatures(
    mapbox.RenderedQueryGeometry.fromScreenCoordinate(screenPt),
    mapbox.RenderedQueryOptions(
      layerIds: [
        'all-US-uni',                   // built-in Mapbox layer
        'top_us_universities_full-cushtv',  // your custom geojson layer
        'umich-libraries-c51lhb',
        'umich-buildings-50-2f0xwm',
        'umich-fraternities-geocoded',
        'umich-theaters-7gdqq6',
        'poi-label-restaurants',
      ],
    ),
  );
  final rendered =
      hits.whereType<mapbox.QueriedRenderedFeature>().firstOrNull;
  if (rendered == null) return;

  // 2) pull out the GeoJSON feature and coords
  final feature = rendered.queriedFeature?.feature;
  if (feature == null) return;

  double lat, lng;
  final geom = feature['geometry'];
  if (geom is Map && geom['type'] == 'Point') {
    final coords = geom['coordinates'];
    if (coords is List && coords.length >= 2) {
      lng = (coords[0] as num).toDouble();
      lat = (coords[1] as num).toDouble();
    } else {
      lng = geoTap.coordinates.lng.toDouble();
      lat = geoTap.coordinates.lat.toDouble();
    }
  } else {
    lng = geoTap.coordinates.lng.toDouble();
    lat = geoTap.coordinates.lat.toDouble();
  }

  // 3) grab properties
  final rawProps = feature['properties'];
  final props = <String, dynamic>{};
  if (rawProps is Map) {
    rawProps.forEach((k, v) {
      if (k != null) props[k] = v;
    });
  }
  final name = props['name'] ?? props['name_en'] ?? 'Unknown';
  final sourceLayer =
      rendered.queriedFeature!.sourceLayer ?? 'unknown_layer';
  final category = props['type'] ?? props['category'] ?? sourceLayer;

  print('🧩 Tapped: $name ($sourceLayer)');

  // 4) If it’s one of *our* university layers, draw the halo
  final isUniLayer = sourceLayer == 'all-US-uni' ||
      sourceLayer.contains('top_us_universities');
  if (isUniLayer) {
    await _drawHighlightCircle(mapbox.Position(lng, lat));
    setState(() => _showReturn = true);
  }

  // 5) fly the camera in
  await _map!.flyTo(
    mapbox.CameraOptions(
      center:
          mapbox.Point(coordinates: mapbox.Position(lng, lat)),
      zoom: 14,
    ),
    mapbox.MapAnimationOptions(duration: 700),
  );

// 6) wait a beat, then open your side sheet
      await Future.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      setState(() {
        _selectedName     = name.toString();
      _selectedCategory = category.toString();
      _panelVisible     = true;      // slide it in
    });

}





  /* haversine distance (metres) */
double _haversineMeters(num lat1, num lon1, num lat2, num lon2) {
  const earthRadius = 6_371_000.0;                     // metres

  final double phi1     = _degToRad(lat1.toDouble());
  final double phi2     = _degToRad(lat2.toDouble());
  final double dPhi     = _degToRad((lat2 - lat1).toDouble());
  final double dLambda  = _degToRad((lon2 - lon1).toDouble());

  final a = math.sin(dPhi / 2) * math.sin(dPhi / 2) +
            math.cos(phi1)   * math.cos(phi2) *
            math.sin(dLambda / 2) * math.sin(dLambda / 2);

  return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
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
    if (await style.styleLayerExists(_hlLine)) await style.removeStyleLayer(_hlLine);
    if (await style.styleLayerExists(_hlLay))  await style.removeStyleLayer(_hlLay);
    if (await style.styleSourceExists(_hlSrc)) await style.removeStyleSource(_hlSrc); // <- now safe


    await style.addSource(
      mapbox.GeoJsonSource(
        id: _hlSrc,
        data: jsonEncode({
          'type': 'FeatureCollection',
          'features': [
            {
              'type': 'Feature',
              'geometry': {'type': 'Polygon', 'coordinates': [ring]},
            }
          ]
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
    if (await style.styleLayerExists(_hlLine)) await style.removeStyleLayer(_hlLine);
    if (await style.styleLayerExists(_hlLay))  await style.removeStyleLayer(_hlLay);
    if (await style.styleSourceExists(_hlSrc)) await style.removeStyleSource(_hlSrc);


    await _map!.flyTo(
      mapbox.CameraOptions(
        center: mapbox.Point(
          coordinates: mapbox.Position(
              mainCampusBadge.lng, mainCampusBadge.lat)),
        zoom: 4.2,
      ),
      mapbox.MapAnimationOptions(duration: 800),
    );
    setState(() { _showReturn = false;
    _panelVisible = false;});
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