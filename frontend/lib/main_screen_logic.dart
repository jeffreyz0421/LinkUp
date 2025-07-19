//  ███  main_screen_logic.dart  ███
//
//  Pure logic & data helpers for MapScreen.
//  No UI except the image viewer.
//
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'config.dart';
import 'models.dart';
import 'cas.dart';

/* ────────── global constants ────────── */
const styleUri = 'mapbox://styles/its-aymann/cmccryahv002f01s249cg9lpg';
const accessToken =
    'pk.eyJ1IjoiaXRzLWF5bWFubiIsImEiOiJjbWNiMGd3OXQwNDN3MmtvZmtteW9wdWloIn0.LNn78rWGpjC2g81fTb3YRw';

const hlSrc = 'campus_hl_src';
const hlLay = 'campus_hl_fill';
const hlLine = 'campus_hl_border';
const circleRadiusMetres = 5_000;

final borderColor = ui.Color.fromARGB(255, 54, 79, 107);
final badgeColor = const ui.Color.fromARGB(180, 76, 175, 80);

/// any Mapbox source‑layers that count as “community/university”
const communityLayers = {
  'all‑US‑uni',
  'top_us_universities_full-cushtv',
  'all-uni-logos-940kmm',
};

final mainCampusBadge = Building(
  id: 'campus',
  name: 'University of Michigan',
  lat: 42.2769,
  lng: -83.7412,
  spaces: [],
);

/* ─────────────────────────────────────────
 *  Lightweight data class returned by search
 * ───────────────────────────────────────── */
class Place {
  final String id;
  final String name;
  final String category;
  final mapbox.Position coord;
  final String address;
  const Place({
    required this.id,
    required this.name,
    required this.category,
    required this.coord,
    this.address = '',
  });
}

/* ─────────────────────────────────────────
 *  Remote Mapbox *Search‑box* wrapper
 * ───────────────────────────────────────── */
class MapboxRemoteSearch {
  static const _token =
      'pk.eyJ1IjoiaXRzLWF5bWFubiIsImEiOiJjbWNiMGd3OXQwNDN3MmtvZmtteW9wdWloIn0.LNn78rWGpjC2g81fTb3YRw';
  final String _session = const Uuid().v4();

  /* ---- suggest ---- */
  Future<List<Place>> suggest(String q, {mapbox.Position? proximity}) async {
    if (q.trim().length < 2) return [];

    final url = _sbUrl('suggest', {
      'q': q,
      'types': 'poi,place,address',
      'limit': '10',
      if (_proxBias(q) && proximity != null)
        'proximity': '${proximity.lng},${proximity.lat}',
    });

    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) return [];

    final raw = (jsonDecode(res.body)['suggestions'] as List);
    var places = raw.map(_rowToPlace).toList();

    /*  simple re‑rank for longer queries  */
    if (q.trim().length > 4) {
      final toks = q.toLowerCase().split(RegExp(r'\s+'));
      int sim(Place p) =>
          toks.where((t) => p.name.toLowerCase().contains(t)).length;
      places.sort((a, b) => sim(b).compareTo(sim(a)));
    }
    return places;
  }

  /* ---- retrieve ---- */
  Future<Place?> retrieve(String id) async {
    final url =
        'https://api.mapbox.com/search/searchbox/v1/retrieve/'
        '$id?session_token=$_session&access_token=$_token';
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) return null;

    final feature = (jsonDecode(res.body)['features'] as List).first;
    double? lng, lat;

    /* geometry */
    final geom = feature['geometry'] as Map?;
    if (geom != null) {
      final c = _centroid(geom);
      lng = c['lng'];
      lat = c['lat'];
    }
    /* bbox fallback */
    if ((lng == null || lat == null) && feature['bbox'] is List) {
      final b = (feature['bbox'] as List).map((e) => (e as num).toDouble());
      lng = (b.elementAt(0) + b.elementAt(2)) / 2;
      lat = (b.elementAt(1) + b.elementAt(3)) / 2;
    }
    if (lng == null || lat == null) return null;

    final props = feature['properties'];
    final rawCat = (props['category'] ?? props['feature_type'] ?? 'poi');
    final catStr = rawCat.toString();
    final isUni = catStr.toLowerCase().contains('university');

    return Place(
      id: id,
      name: props['name'],
      category: isUni ? 'university' : rawCat,
      address:
          props['full_address'] ??
          props['place_formatted'] ??
          props['name_context'] ??
          props['context']?.toString() ??
          '',
      coord: mapbox.Position(lng, lat),
    );
  }

  /* ---------- helpers ---------- */
  bool _proxBias(String q) =>
      q.trim().split(RegExp(r'\s+')).length == 1 && q.trim().length <= 4;

  Map<String, double?> _centroid(Map geom) {
    final t = geom['type'];
    final c = geom['coordinates'];

    List<List> flat(dynamic x) => (x is List && x.isNotEmpty && x.first is! num)
        ? x.expand(flat).toList()
        : [x as List];

    if (t == 'Point') {
      return {'lng': (c[0] as num).toDouble(), 'lat': (c[1] as num).toDouble()};
    }
    if (t == 'LineString' ||
        t == 'MultiLineString' ||
        t == 'Polygon' ||
        t == 'MultiPolygon') {
      final f = flat(c);
      double sx = 0, sy = 0;
      for (final p in f) {
        sx += (p[0] as num);
        sy += (p[1] as num);
      }
      return {'lng': sx / f.length, 'lat': sy / f.length};
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
    final rawCat = s['feature_type']?.toString().toLowerCase() ?? 'poi';
    final isUni = rawCat.contains('university');

    return Place(
      id: s['mapbox_id'],
      name: s['name'],
      category: isUni ? 'university' : s['feature_type'] ?? 'poi',
      address:
          s['full_address'] ??
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

/* ─────────────────────────────────────────
 *  Search‑delegate (plain Flutter widget)
 * ───────────────────────────────────────── */
class PlaceSearchDelegate extends SearchDelegate<Place?> {
  final MapboxRemoteSearch remote;
  final mapbox.Position? proximity;
  PlaceSearchDelegate(this.remote, this.proximity);

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
                p.address.isNotEmpty ? p.address : p.category,
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

  @override
  Widget buildResults(BuildContext ctx) => buildSuggestions(ctx);
}

/* ─────────────────────────────────────────
 *  A full‑screen, pinch‑zoom photo viewer
 * ───────────────────────────────────────── */
Future<void> showPhotoViewer(BuildContext ctx, String url) {
  final size = MediaQuery.of(ctx).size;
  return Navigator.of(ctx).push(
    PageRouteBuilder(
      opaque: false,
      pageBuilder: (_, __, ___) => Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Hero(
                  tag: url,
                  child: SizedBox(
                    width: size.width,
                    height: size.height,
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
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

/* ─────────────────────────────────────────
 *  ***  THE “ENGINE” STATE CLASS  ***
 *  (Everything from your old _MapScreenState
 *   that doesn’t create UI widgets)
 * ───────────────────────────────────────── */
abstract class MapScreenLogicState<T extends StatefulWidget> extends State<T> {
  mapbox.Position get camCenter   => _camCenter;
  double          get camZoom     => _camZoom;
  bool            get panelVisible=> _panelVisible;
  double          get panelHeight => _panelHeight;
  List<String>    get selectedTags=> _selectedTags;
  String?         get selectedName   => _selectedName;
  String?         get selectedAddress=> _selectedAddress;
  Map<String,int> get etaMinutes  => _etaMinutes;
  bool            get showAllEtas => _showAllEtas;
  String          get activeMode  => _activeMode;
  MapboxRemoteSearch get remote   => _remote;
  geo.Position?   get lastPos     => _lastPos;
  List<String> get selectedPhotos => _selectedPhotos;
  mapbox.Position? get selectedPosition => _selectedPosition;
  
  void setActiveMode(String mode) => setState(() => _activeMode = mode);
  void setShowAllEtas(bool v)     => setState(() => _showAllEtas = v);
  // ───── PUBLIC HOOKS THAT THE UI LAYER CAN CALL ─────
  /* ─── UI helper ─── */
void setPanelVisible(bool value) {
  if (_panelVisible == value) return;          // nothing to change
  setState(() => _panelVisible = value);       // update + rebuild
}
void onMapCreated(mapbox.MapboxMap map)      => _onMapCreated(map);
void onStyleLoaded()                         => _onStyleLoaded();
void onCameraChange(mapbox.CameraChangedEventData e)
                                             => _onCameraChange(e);
void handleMapTap(mapbox.Point pt)           => _handleMapTap(pt);

Future<void> resetView()                     => _resetView();
Future<void> goToPlace(Place p)              => _goToPlace(p);
Future<void> flyToUser()                     => _flyToUser();
Future<void> drawRoute(String mode,
        {required mapbox.Position from, required mapbox.Position to})
                                             => _drawRoute(mode, from: from, to: to);
Future<void> fetchEta(String mode,
        {required mapbox.Position from, required mapbox.Position to})
                                             => _fetchEta(mode, from: from, to: to);
Future<void> clearRoute()                    => _clearRoute();

  /*  ══════ 1.  fields  ══════ */
  mapbox.MapboxMap? _map;
  mapbox.PointAnnotationManager? _annMgr;
  mapbox.PointAnnotation? _userPinAnn;

  mapbox.Position _camCenter = mapbox.Position(
    mainCampusBadge.lng,
    mainCampusBadge.lat,
  );
  double _camZoom = 4.2;

  final _remote = MapboxRemoteSearch();
  final _placeIndex = <Place>[];

  Building? _selectedBuilding;
  mapbox.FeatureCollection? _universities;
  geo.Position? _lastPos;

  String? _name, _username;
  String? _selectedName, _selectedAddress, _selectedCategory;
  mapbox.Position? _selectedPosition;

  bool _mapReady = false;
  bool _panelVisible = false;
  bool _showAllEtas = false;
  bool _isCommunity = false;
  bool _showReturn = false;
  bool _tapLocked = false;

  final List<String> _selectedTags = [];
  List<String> _selectedPhotos = [];

  final Map<String, int> _etaMinutes = {}; // {"drive":10, "bike":22…}
  String _activeMode = 'drive';

  double get _panelHeight => MediaQuery.of(context).size.height * 0.45;

  /*  ══════ 2.  lifecycle  ══════ */
  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _name = prefs.getString('name');
      _username = prefs.getString('username');
    });
  }

  /*  ══════ 3.  Mapbox callbacks  ══════ */
  Future<void> _onMapCreated(mapbox.MapboxMap map) async {
    _map = map;
    _annMgr = await map.annotations.createPointAnnotationManager();
    if (_universities == null) await _loadCampusDataset();
  }

  Future<void> _onStyleLoaded() async {
    await _addUserPinSprite();
    await _initLocation();
    setState(() => _mapReady = true);
  }

  void _onCameraChange(mapbox.CameraChangedEventData evt) {
  final nz = evt.cameraState.zoom;
  final nc = evt.cameraState.center.coordinates;
  if (nz != _camZoom || nc != _camCenter) {
    setState(() {
      _camZoom   = nz;
      _camCenter = nc;
    });
    _scaleUserPin();
  }
}

  /*  ══════ 4.  implementation methods  ══════ */

  /* ---- user‑location bootstrap ---- */
  Future<void> _initLocation() async {
    // Hard‑coded to Ann Arbor (replace with real GPS later)
    _lastPos = geo.Position(
      latitude: 42.2780,
      longitude: -83.7382,
      timestamp: DateTime.now(),
      accuracy: 5,
      altitude: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: 1.0,
      headingAccuracy: 1.0,
    );
    await _updateUserPin();
    await _flyToUser();
  }

  /* ---- sprite & annotation helpers ---- */
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

  Future<void> _updateUserPin() async {
    if (_map == null || _annMgr == null || _lastPos == null) return;

    final point = mapbox.Point(
      coordinates: mapbox.Position(_lastPos!.longitude, _lastPos!.latitude),
    );

    try {
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
      // ignore error on hot‑reload
    }
  }

  void _scaleUserPin() {
    if (_userPinAnn == null || _annMgr == null) return;
    try {
      _userPinAnn!.iconSize = ((_camZoom - 10) * .4).clamp(0.7, 1.0);
      _annMgr!.update(_userPinAnn!);
    } catch (_) {}
  }

  Future<void> _flyToUser() async {
    if (_map == null || _lastPos == null) return;
    await _map!.flyTo(
      mapbox.CameraOptions(
        center: mapbox.Point(
          coordinates: mapbox.Position(_lastPos!.longitude, _lastPos!.latitude),
        ),
        zoom: 13,
        bearing: 0,
        pitch: 0,
      ),
      mapbox.MapAnimationOptions(duration: 600),
    );
  }

  /* ---- local GeoJSON (universities) ---- */
  Future<void> _loadCampusDataset() async {
    final jsonStr = await rootBundle.loadString(
      'assets/top_us_universities_full.geojson',
    );
    final fc = mapbox.FeatureCollection.fromJson(jsonDecode(jsonStr));

    /* build in‑memory search index */
    for (final feat in fc.features ?? []) {
      final props = Map<String, dynamic>.from(feat.properties ?? {});
      final name = (props['name'] ?? props['title'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      final cat = (props['type'] ?? 'place').toString();

      double? lng, lat;
      if (feat.geometry is mapbox.Point) {
        final p = feat.geometry as mapbox.Point;
        lng = p.coordinates.lng.toDouble();
        lat = p.coordinates.lat.toDouble();
      }
      lng ??= (feat.geometry?.toJson()['coordinates']?[0] as num?)?.toDouble();
      lat ??= (feat.geometry?.toJson()['coordinates']?[1] as num?)?.toDouble();
      if (lng == null || lat == null) continue;

      _placeIndex.add(
        Place(
          id: 'local:$name',
          name: name,
          category: cat,
          coord: mapbox.Position(lng, lat),
        ),
      );
    }
    setState(() => _universities = fc);
  }

  /* ---- primary “go‑to” logic (called by UI) ---- */
  Future<void> _goToPlace(Place initial) async {
    var p = initial;
    if ((p.coord.lat.abs() < 0.001 || p.coord.lng.abs() < 0.001)) {
      final fixed = await _remote.retrieve(p.id);
      if (fixed != null) p = fixed;
    }
    if (_map == null) return;

    await _clearRoute();
    _map!.style.removeStyleLayer(hlLay).catchError((_) {});
    _map!.style.removeStyleLayer(hlLine).catchError((_) {});
    _map!.style.removeStyleSource(hlSrc).catchError((_) {});

    _isCommunity = p.category.toLowerCase() == 'university';
    if (_isCommunity) await _drawHighlightCircle(p.coord);

    await _map!.flyTo(
      mapbox.CameraOptions(
        center: mapbox.Point(coordinates: p.coord),
        zoom: 14,
        padding: _edgeInsetsForRoute(context),
      ),
      mapbox.MapAnimationOptions(duration: 800),
    );

    Future.delayed(const Duration(milliseconds: 850), () {
      if (!mounted) return;
      _handlePlaceSelect(p);
    });
  }

  Future<void> _handlePlaceSelect(Place place) async {
    _selectedName = place.name;
    _selectedCategory = place.category;
    _selectedAddress = place.address;
    _selectedPosition = place.coord;
    _isCommunity =
        place.category.toLowerCase() == 'university' ||
        place.name.toLowerCase().contains('university');
    _selectedTags
      ..clear()
      ..add('UNIVERSITY')
      ..addAll(_isCommunity ? ['COMMUNITY'] : []);

    if (_isCommunity) await _drawHighlightCircle(place.coord);

    final slug = place.name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
        .trim()
        .replaceAll(' ', '-');
    final folder = Uri.encodeComponent('PICTURES - ${place.name}');
    final base = Config.universityPicturesEndpoint(folder);
    _selectedPhotos = List<String>.generate(
      5,
      (i) => '$base/${i + 1}-$slug.jpg',
    );

    setState(() {
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

  /* ---- tap on any rendered map feature ---- */
  Future<void> _handleMapTap(mapbox.Point geoTap) async {
    if (_map == null) return;

    await _clearRoute();
    _map!.style.removeStyleLayer(hlLay).catchError((_) {});
    _map!.style.removeStyleLayer(hlLine).catchError((_) {});
    _map!.style.removeStyleSource(hlSrc).catchError((_) {});

    final screenPt = await _map!.pixelForCoordinate(geoTap);
    final hits = await _map!.queryRenderedFeatures(
      mapbox.RenderedQueryGeometry.fromScreenCoordinate(screenPt),
      mapbox.RenderedQueryOptions(),
    );

    final rendered = hits
        .whereType<mapbox.QueriedRenderedFeature>()
        .firstWhereOrNull((q) {
          final raw = (q.queriedFeature?.feature['properties'] as Map?) ?? {};
          final keys = raw.keys.map((k) => k.toString().toLowerCase()).toSet();
          return keys.intersection({
            'name',
            'name_en',
            'title',
            'text',
          }).isNotEmpty;
        });
    if (rendered == null) return;

    final feat = rendered.queriedFeature!.feature as Map;
    final geom = feat['geometry'] as Map?;
    final props = Map<String, dynamic>.from((feat['properties'] as Map?) ?? {});
    final name =
        (props['name'] ??
                props['name_en'] ??
                props['title'] ??
                props['text'] ??
                'Unknown')
            .toString();

    double lat, lng;
    if (geom != null && geom['type'] == 'Point') {
      final c = geom['coordinates'] as List;
      lng = (c[0] as num).toDouble();
      lat = (c[1] as num).toDouble();
    } else {
      lng = geoTap.coordinates.lng.toDouble();
      lat = geoTap.coordinates.lat.toDouble();
    }
    final destPos = mapbox.Position(lng, lat);
    final sourceLayer = rendered.queriedFeature!.sourceLayer ?? '';
    final isUni = communityLayers.any((id) => sourceLayer.contains(id));

    if (isUni) {
      await _drawHighlightCircle(destPos);
      setState(() => _showReturn = true);
    }

    final bump = _lastPos != null
        ? _zoomBumpForDistance(
            destPos,
            mapbox.Position(_lastPos!.longitude, _lastPos!.latitude),
          )
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

    String? resolvedAddr;
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        resolvedAddr = [
          if (p.street?.isNotEmpty ?? false) p.street,
          if (p.locality?.isNotEmpty ?? false) p.locality,
          if (p.administrativeArea?.isNotEmpty ?? false) p.administrativeArea,
          if (p.postalCode?.isNotEmpty ?? false) p.postalCode,
        ].join(', ');
      }
    } catch (_) {}

    _selectedTags
      ..clear()
      ..add(
        (isUni
            ? 'UNIVERSITY'
            : (props['category'] ?? props['type'] ?? '')
                  .toString()
                  .toUpperCase()),
      )
      ..addAll(isUni ? ['COMMUNITY'] : []);

    _selectedPhotos = List<String>.generate(5, (i) {
      final slug = name
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
          .trim()
          .replaceAll(' ', '-');
      final folder = Uri.encodeComponent('PICTURES - $name');
      final base = Config.universityPicturesEndpoint(folder);
      return '$base/${i + 1}-$slug.jpg';
    });

    setState(() {
      _selectedName = name;
      _selectedAddress = resolvedAddr;
      _selectedCategory = isUni
          ? 'university'
          : (props['category'] ?? props['type'] ?? '').toString();
      _selectedPosition = destPos;
      _panelVisible = true;
      _etaMinutes.clear();
      _showAllEtas = false;
    });

    if (_lastPos != null) {
      _fetchEta(
        'drive',
        from: mapbox.Position(_lastPos!.longitude, _lastPos!.latitude),
        to: destPos,
      );
    }
  }

  /* ---- Directions & ETA ---- */
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
        '?overview=false&access_token=$accessToken';
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) return;
    final data = jsonDecode(res.body);
    if ((data['routes'] as List).isEmpty) return;
    final secs = (data['routes'][0]['duration'] as num).toDouble();
    setState(() => _etaMinutes[mode] = (secs / 60).round());
  }

  Future<void> _drawRoute(
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
        '?geometries=geojson&overview=full&access_token=$accessToken';
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) return;
    final data = jsonDecode(res.body);
    if ((data['routes'] as List).isEmpty) return;

    final route = data['routes'][0];
    final secs = (route['duration'] as num).toDouble();
    final coords = (route['geometry']['coordinates'] as List)
        .cast<List>()
        .map((c) => mapbox.Position(c[0] as double, c[1] as double))
        .toList();
    setState(() => _etaMinutes[mode] = (secs / 60).round());

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

    /*  fit camera to route */
    double minLat = double.infinity, maxLat = -double.infinity;
    double minLng = double.infinity, maxLng = -double.infinity;
    for (final p in coords) {
      final dLat = p.lat.toDouble();
      final dLng = p.lng.toDouble();
      if (dLat < minLat) minLat = dLat;
      if (dLat > maxLat) maxLat = dLat;
      if (dLng < minLng) minLng = dLng;
      if (dLng > maxLng) maxLng = dLng;
    }
    minLat = math.min(minLat, math.min(from.lat.toDouble(), to.lat.toDouble()));
    maxLat = math.max(maxLat, math.max(from.lat.toDouble(), to.lat.toDouble()));
    minLng = math.min(minLng, math.min(from.lng.toDouble(), to.lng.toDouble()));
    maxLng = math.max(maxLng, math.max(from.lng.toDouble(), to.lng.toDouble()));

    final bounds = mapbox.CoordinateBounds(
      southwest: mapbox.Point(coordinates: mapbox.Position(minLng, minLat)),
      northeast: mapbox.Point(coordinates: mapbox.Position(maxLng, maxLat)),
      infiniteBounds: false,
    );
    var cam = await _map!.cameraForCoordinateBounds(
      bounds,
      _edgeInsetsForRoute(context),
      0,
      0,
      null,
      null,
    );
    const kMin = 3.5, kMax = 17.5;
    if (cam.zoom != null) {
      cam = mapbox.CameraOptions(
        center: cam.center,
        zoom: cam.zoom!.clamp(kMin, kMax),
        bearing: cam.bearing,
        pitch: cam.pitch,
        padding: cam.padding,
      );
    }
    await _map!.flyTo(cam, mapbox.MapAnimationOptions(duration: 700));
  }

  /* ---- quick demo: straight line route ---- */
  Future<void> _drawRouteToSelection() async {
    if (_map == null || _lastPos == null || _selectedPosition == null) return;

    const srcId = 'temp_route_src';
    const layerId = 'temp_route_layer';
    final style = _map!.style;
    if (await style.styleLayerExists(layerId))
      await style.removeStyleLayer(layerId);
    if (await style.styleSourceExists(srcId))
      await style.removeStyleSource(srcId);

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
  }

  /* ---- geometric helpers ---- */
  double _haversineMeters(num lat1, num lon1, num lat2, num lon2) {
    const R = 6_371_000.0;
    final phi1 = _degToRad(lat1.toDouble());
    final phi2 = _degToRad(lat2.toDouble());
    final dPhi = _degToRad((lat2 - lat1).toDouble());
    final dLambda = _degToRad((lon2 - lon1).toDouble());
    final a =
        math.sin(dPhi / 2) * math.sin(dPhi / 2) +
        math.cos(phi1) *
            math.cos(phi2) *
            math.sin(dLambda / 2) *
            math.sin(dLambda / 2);
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _zoomBumpForDistance(mapbox.Position a, mapbox.Position b) {
    final d = _haversineMeters(a.lat, a.lng, b.lat, b.lng);
    if (d < 5_000) return 0;
    if (d < 30_000) return 0.8;
    return 1.5;
  }

  double _degToRad(double d) => d * math.pi / 180;

  /* ---- highlight circle ---- */
  Future<void> _drawHighlightCircle(mapbox.Position centre) async {
    if (_map == null) return;
    const seg = 32;
    const R = 6_378_137.0;
    final dLat = (circleRadiusMetres / R) * 180 / math.pi;
    final dLng = dLat / math.cos(centre.lat.toDouble() * math.pi / 180);
    final ring = List.generate(seg, (i) {
      final t = 2 * math.pi * i / (seg - 1);
      return [centre.lng + dLng * math.cos(t), centre.lat + dLat * math.sin(t)];
    });

    final style = _map!.style;
    if (await style.styleLayerExists(hlLine))
      await style.removeStyleLayer(hlLine);
    if (await style.styleLayerExists(hlLay))
      await style.removeStyleLayer(hlLay);
    if (await style.styleSourceExists(hlSrc))
      await style.removeStyleSource(hlSrc);

    await style.addSource(
      mapbox.GeoJsonSource(
        id: hlSrc,
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
        id: hlLay,
        sourceId: hlSrc,
        fillColor: badgeColor.value,
        fillOpacity: 0.3,
      ),
    );
    await style.addLayer(
      mapbox.LineLayer(
        id: hlLine,
        sourceId: hlSrc,
        lineColor: borderColor.value,
        lineWidth: 2.5,
        lineOpacity: 0.65,
      ),
    );
  }

  /* ---- route / panel insets ---- */
  mapbox.MbxEdgeInsets _edgeInsetsForRoute(BuildContext ctx) {
    final media = MediaQuery.of(ctx);
    final bottomPx = _panelHeight + media.padding.bottom + 24;
    return mapbox.MbxEdgeInsets(
      left: 48,
      top: 48 + media.padding.top,
      right: 48,
      bottom: bottomPx,
    );
  }

  /* ---- clear & reset ---- */
  Future<void> _clearRoute() async {
    if (_map == null) return;
    final style = _map!.style;
    if (await style.styleLayerExists('route_layer'))
      await style.removeStyleLayer('route_layer');
    if (await style.styleSourceExists('route_src'))
      await style.removeStyleSource('route_src');
  }

  Future<void> _resetView() async {
    if (_map == null) return;
    final style = _map!.style;
    if (await style.styleLayerExists(hlLine))
      await style.removeStyleLayer(hlLine);
    if (await style.styleLayerExists(hlLay))
      await style.removeStyleLayer(hlLay);
    if (await style.styleSourceExists(hlSrc))
      await style.removeStyleSource(hlSrc);

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
