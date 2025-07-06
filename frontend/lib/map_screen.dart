// map_screen.dart
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:permission_handler/permission_handler.dart';

/* ─────────── project-local model ─────────── */
import 'models.dart';        // contains `Building`
import 'popover_sheet.dart'; // keep if you still use it

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
  mapbox.MapboxMap?              _map;
  mapbox.PointAnnotationManager? _annMgr;
  mapbox.PointAnnotation?        _userPinAnn;
  late final mapbox.FeatureCollection _universities;
  
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

          /* return button */
          if (_showReturn)
            Positioned(
              top: 40,
              left: 20,
              child: ElevatedButton(
                onPressed: _resetView,
                child: const Text('Return to whole map'),
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

  /* ═════════════ init helpers ═════════════ */
  Future<void> _onMapCreated(mapbox.MapboxMap map) async {
    _map    = map;
    _annMgr = await map.annotations.createPointAnnotationManager();
    await _addUserPinSprite();
    await _loadCampusDataset();
    await _initLocation();
  }

  Future<void> _loadCampusDataset() async {
    final jsonStr =
        await rootBundle.loadString('assets/top_us_universities_full.geojson');
    _universities = mapbox.FeatureCollection.fromJson(jsonDecode(jsonStr));
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

    if (_userPinAnn == null) {
      _userPinAnn = await _annMgr!.create(
        mapbox.PointAnnotationOptions(
          geometry: point,
          iconImage: 'user_pin',
          iconSize: 1.0,
        ),
      );
    } else {
      _userPinAnn!.geometry = point;
      await _annMgr!.update(_userPinAnn!);
    }
  }

  void _scaleUserPin() {
    if (_userPinAnn == null || _annMgr == null) return;
    _userPinAnn!.iconSize = ((_zoom - 10) * .4).clamp(0.7, 1.0);
    _annMgr!.update(_userPinAnn!);
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

/// React to a user-tap on the map.  
/// If a university symbol (layer **all-US-uni**) is rendered at that pixel,
/// fly the camera there and draw / refresh the orange halo.
Future<void> _handleMapTap(mapbox.Point geoTap) async {
  if (_map == null) return;

  /* 1️⃣  lng/lat  →  screen-pixel */
  final screenPt = await _map!.pixelForCoordinate(geoTap);

  /* 2️⃣  rendered-feature query (symbol layer only) */
  final hits = await _map!.queryRenderedFeatures(
    mapbox.RenderedQueryGeometry.fromScreenCoordinate(screenPt),
    mapbox.RenderedQueryOptions(layerIds: ['all-US-uni']),
  );

  final rendered = hits.whereType<mapbox.QueriedRenderedFeature>().firstOrNull;
  if (rendered == null) return;                                  // nothing here

  /* 3️⃣  dig into QueriedFeature → raw GeoJSON map */
  final qFeat = rendered.queriedFeature;
  if (qFeat == null) return;

  final Map raw = qFeat.feature;                                 // generic Map

  /* 4️⃣  geometry sanity-check: must be a Point */
  final geomMap = raw['geometry'];
  if (geomMap is! Map) return;
  if (geomMap['type'] != 'Point') return;

  final coordsAny = geomMap['coordinates'];
  if (coordsAny is! List || coordsAny.length < 2) return;

  final lon = (coordsAny[0] as num).toDouble();
  final lat = (coordsAny[1] as num).toDouble();

  final dest = mapbox.Point(coordinates: mapbox.Position(lon, lat));

  /* 5️⃣  (optional) name / props if you need them later                */
  final propsMap = (raw['properties'] is Map)
      ? (raw['properties'] as Map).cast<String, dynamic>()
      : <String, dynamic>{};
  final campusName =
      (propsMap['name'] ?? propsMap['name_en'] ?? '').toString();

  /* 6️⃣  camera fly & highlight halo                                   */
  await _map!.flyTo(
    mapbox.CameraOptions(center: dest, zoom: 12),
    mapbox.MapAnimationOptions(duration: 800),
  );

  setState(() => _showReturn = true);
  await _drawHighlightCircle(mapbox.Position(lon, lat));

  // If you still keep another highlight method based on the name:
  // _highlightCampus(campusName);
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
    setState(() => _showReturn = false);
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
