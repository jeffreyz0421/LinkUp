import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'map_screen.dart';


void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Set your Mapbox access token
  MapboxOptions.setAccessToken(
    'pk.eyJ1IjoiaXRzLWF5bWFubiIsImEiOiJjbWNiMGd3OXQwNDN3MmtvZmtteW9wdWloIn0.LNn78rWGpjC2g81fTb3YRw',
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
      home: const MapScreen(), // Starts with your custom map screen
    );
  }
}
