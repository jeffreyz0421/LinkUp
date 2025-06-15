import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'models.dart';
import 'map_badges.dart';
import 'popover_sheet.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CampusLifeApp());
}

class CampusLifeApp extends StatelessWidget {
  const CampusLifeApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Loqi', // or whatever name you pick 🙂
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: const MapPage(),
    );
  }
}

class MapPage extends StatefulWidget {
  const MapPage({super.key});
  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final Completer<GoogleMapController> _ctl = Completer();
  final Map<MarkerId, Marker> _markers = {};
  Building? _activeBuilding;

  @override
  void initState() {
    super.initState();
    _loadBuildingMarkers();
  }

  void _loadBuildingMarkers() async {
    for (final b in buildings) {
      final icon = await buildBadge(
          text: b.name,
          bg: Colors.indigo,
          fg: Colors.white,
          fontSize: 14);
      final mId = MarkerId('b_${b.name}');
      _markers[mId] = Marker(
        markerId: mId,
        icon: icon,
        position: b.coord,
        onTap: () => _onBuildingTap(b),
      );
    }
    setState(() {});
  }

  Future<void> _onBuildingTap(Building b) async {
    _activeBuilding = b;
    // Zoom a bit
    final ctl = await _ctl.future;
    await ctl.animateCamera(CameraUpdate.newLatLngZoom(b.coord, 18));
    // show spaces
    _showSpaceMarkers(b);
    // show sheet
    showBuildingSheet(
      ctx: context,
      building: b,
      onSelect: (s) {
        _zoomToSpace(s);
      },
    ).whenComplete(() {
      // sheet closed → clear spaces
      setState(() {
        _activeBuilding = null;
        _markers.removeWhere((k, v) => k.value.startsWith('s_'));
      });
    });
  }

  void _showSpaceMarkers(Building b) async {
    // remove prior space markers
    _markers.removeWhere((k, v) => k.value.startsWith('s_'));
    // add new ones
    for (final s in b.spaces) {
      final icon = await buildBadge(
          text: s.name,
          bg: Colors.yellow.shade700,
          fg: Colors.indigo,
          fontSize: 15);
      final id = MarkerId('s_${s.name}');
      _markers[id] = Marker(
        markerId: id,
        icon: icon,
        position: s.coord,
        onTap: () => _zoomToSpace(s),
      );
    }
    setState(() {});
  }

  Future<void> _zoomToSpace(Space s) async {
    final ctl = await _ctl.future;
    await ctl.animateCamera(CameraUpdate.newLatLngZoom(s.coord, 20));
    // leave sheet open
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
            target: buildings.first.coord, zoom: 16),
        markers: _markers.values.toSet(),
        onMapCreated: (c) => _ctl.complete(c),
        myLocationEnabled: true,
        myLocationButtonEnabled: false,
      ),
    );
  }
}
