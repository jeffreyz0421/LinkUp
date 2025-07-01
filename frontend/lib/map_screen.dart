import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'models.dart';
import 'popover_sheet.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapboxMap? mapboxMap;
  PointAnnotationManager? annotationManager;

  final List<Building> buildings = [
    Building(
      id: '1',
      name: 'Mason Hall',
      lat: 42.2769,
      lng: -83.7412,
      spaces: [Space(name: 'Room 123'), Space(name: 'Study Lounge')],
    ),
    Building(
      id: '2',
      name: 'Shapiro Library',
      lat: 42.2746,
      lng: -83.7382,
      spaces: [Space(name: 'Quiet Study'), Space(name: 'Group Pods')],
    ),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        body: MapWidget(
          key: const ValueKey('mapWidget'),
          cameraOptions: CameraOptions(
            center: Point(coordinates: Position(-83.7412, 42.2769)),
            zoom: 14,
          ),
          onMapCreated: _onMapCreated,
        ),
      );

  Future<void> _onMapCreated(MapboxMap map) async {
    mapboxMap = map;
    annotationManager =
        await map.annotations.createPointAnnotationManager();

    for (final b in buildings) {
      await annotationManager!.create(
        PointAnnotationOptions(
          geometry: Point(coordinates: Position(b.lng, b.lat)),
          iconImage: 'marker-15',
          iconSize: 1.5,
          textField: b.name,
          textOffset: [0, 1.5],
        ),
      );
    }

    // hand an object that implements OnPointAnnotationClickListener
    annotationManager!.addOnPointAnnotationClickListener(
      _TapListener(buildings, context),
    );
  }
}

/* ---------- listener implementation ---------- */
class _TapListener implements OnPointAnnotationClickListener {
  _TapListener(this.buildings, this.ctx);
  final List<Building> buildings;
  final BuildContext ctx;

  @override
  bool onPointAnnotationClick(PointAnnotation ann) {
    final tapped = buildings.firstWhere(
      (b) => b.name == ann.textField,
      orElse: () => buildings.first,
    );

    showBuildingSheet(
      ctx: ctx,
      building: tapped,
      onSelect: (space) {
        Navigator.push(
          ctx,
          MaterialPageRoute(
            builder: (_) => DestinationPage(label: space.name),
          ),
        );
      },
    );
    return true; // tell Mapbox the tap was handled
  }
}

/* ---------- simple destination page ---------- */
class DestinationPage extends StatelessWidget {
  final String label;
  const DestinationPage({super.key, required this.label});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(label)),
        body: Center(
          child: Text(
            "You're now viewing: $label",
            style: const TextStyle(fontSize: 20),
          ),
        ),
      );
}
