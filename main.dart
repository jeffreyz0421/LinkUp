import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'map_screen.dart';

void main() {
  // Make sure the Flutter binding is ready **before** any plugin call
  WidgetsFlutterBinding.ensureInitialized();

  // Set your Mapbox public access-token once at app start
  MapboxOptions.setAccessToken(
    'pk.eyJ1IjoiamVmZnJleXo0MSIsImEiOiJjbWNhd3dsZHUwOGtkMm1xMHhjNXZoYno3In0.UGzY7ZB9wfxlfjexJJFW8w',
  );

  runApp(const LinkUpApp());
}

class LinkUpApp extends StatelessWidget {
  const LinkUpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LinkUp',
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: const MapScreen(), // your Mapbox page
    );
  }
}
