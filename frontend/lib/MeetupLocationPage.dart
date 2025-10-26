import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'session_manager.dart';
import 'services/profile_service.dart';
import 'main_screen_ui.dart';
import 'cas.dart';
import 'main_screen_logic.dart'; // brings in styleUri
import 'Meetup_master_and_vibe.dart';
import 'MeetupInvitePage.dart';
import 'config.dart';

class MeetupLocationPage extends StatefulWidget {
  final dynamic vibe; // keep dynamic if type is unknown

  const MeetupLocationPage({Key? key, this.vibe}) : super(key: key);

  @override
  _MeetupLocationPageState createState() => _MeetupLocationPageState();
}

class _MeetupLocationPageState extends MapScreenLogicState<MeetupLocationPage> {
  mapbox.Point? _pickedPoint;
  String? _pickedName;
  String? _pickedAddress;

  static const LinearGradient _primaryGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFF16365), Color(0xFFEC4899), Color(0xFFF5600B)],
  );

  static const LinearGradient _disabledGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF9E9E9E), Color(0xFF9E9E9E)],
  );

  /// Update the selected address via reverse geocoding (Mapbox)
  Future<void> _updatePickedAddress() async {
    if (selectedPosition == null) return;
    try {
      final coords = selectedPosition!;
      final token = Config.mapboxAccessToken;
      final url = Uri.parse(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/'
        '${coords.lng},${coords.lat}.json'
        '?access_token=${Uri.encodeComponent(token)}&limit=1',
      );
      final resp = await http.get(url);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final features = data['features'] as List<dynamic>?;
        if (features != null && features.isNotEmpty) {
          setState(() {
            _pickedAddress = features[0]['place_name'] as String?;
          });
        }
      }
    } catch (_) {
      // silently ignore; address is optional
    }
  }

  void _clearSelection() {
    setState(() {
      _pickedPoint = null;
      _pickedName = null;
      _pickedAddress = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // ─────────── the map ───────────
          mapbox.MapWidget(
            styleUri: styleUri,
            cameraOptions: mapbox.CameraOptions(
              center: mapbox.Point(coordinates: camCenter),
              zoom: camZoom,
            ),
            onMapCreated: onMapCreated,
            onStyleLoadedListener: (_) => onStyleLoaded(),
            onCameraChangeListener: onCameraChange,
            onTapListener: (event) async {
              await handleMapTap(event.point);
              setState(() {
                _pickedPoint = selectedPosition != null
                    ? mapbox.Point(coordinates: selectedPosition!)
                    : null;
                _pickedName = selectedName;
              });
              await _updatePickedAddress();
            },
          ),

          // ─────────── globe / explore button ───────────
          Positioned(
            right: 20,
            bottom: 88 + 20 + 70, // above the locate-me FAB
            child: SizedBox(
              width: 48,
              height: 48,
              child: FloatingActionButton(
                heroTag: 'explore_globe',
                backgroundColor: Colors.white,
                foregroundColor: Colors.deepPurple,
                onPressed: () {
                    // Zoom back out to your campus/global view without leaving this page
                    mapController.flyTo(
                      mapbox.CameraOptions(
                        center: mapbox.Point(coordinates: camCenter),
                        zoom: 4.2, // or whatever your “global” zoom level is
                      ),
                      mapbox.MapAnimationOptions(duration: 800),
                    );
                    // also clear any pin selection if you like:
                    _clearSelection();
                  },
                child: const Icon(Icons.public_rounded),
              ),
            ),
          ),

          // ─────────── locate‐me FAB ───────────
          Positioned(
            right: 20,
            bottom: 88 + 20,
            child: SizedBox(
              width: 48,
              height: 48,
              child: FloatingActionButton(
                heroTag: 'locate_me',
                backgroundColor: Colors.white,
                foregroundColor: Colors.blueAccent,
                onPressed: flyToUser,
                child: const Icon(Icons.my_location_rounded),
              ),
            ),
          ),

          // ─────────── top title & search section ───────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Column(
              children: [
                // gradient title bar
                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: _primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x19000000),
                        blurRadius: 15,
                        offset: Offset(0, 10),
                      ),
                      BoxShadow(
                        color: Color(0x11000000),
                        blurRadius: 6,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'Select a Meetup Spot',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // search pill
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFECE6F0),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 15,
                        offset: Offset(0, 10),
                      ),
                      BoxShadow(
                        color: Color(0x11000000),
                        blurRadius: 6,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: InkWell(
                    onTap: () async {
                      final result = await showSearch<Place?>(
                        context: context,
                        delegate: PlaceSearchDelegate(
                          remote,
                          lastPos != null
                              ? mapbox.Position(lastPos!.longitude, lastPos!.latitude)
                              : null,
                        ),
                      );
                      if (result != null) {
                        await goToPlace(result);
                        setState(() {
                          _pickedPoint = mapbox.Point(coordinates: result.coord);
                          _pickedName = result.name;
                          _pickedAddress = null;
                        });
                        await _updatePickedAddress();
                      }
                    },
                    borderRadius: BorderRadius.circular(28),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: const [
                          Icon(Icons.search, color: Color(0xFF5D61A1)),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Find your spot',
                              style: TextStyle(
                                color: Color(0xFF49454F),
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─────────── DETAIL PANEL ───────────
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            left: 0,
            right: 0,
            bottom: panelVisible ? 0 : -panelHeight,
            height: panelHeight,
            child: buildDetailCard(context),
          ),

          // ─────────── bottom confirm card ───────────
          if (_pickedName != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                      BoxShadow(
                        color: Color(0x11000000),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // “You are selecting:” with LuckiestGuy font
                      Text(
                        'You are selecting: $_pickedName',
                        style: const TextStyle(
                          color: Color(0xFFAD5454),
                          fontSize: 16,
                          fontFamily: 'LuckiestGuy',
                        ),
                      ),
                      if (_pickedAddress != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _pickedAddress!,
                          style: TextStyle(
                            color: const Color(0xFFAD5454).withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          // Back button
                          Expanded(
                            child: GestureDetector(
                              onTap: _clearSelection,
                              child: Container(
                                height: 54,
                                decoration: BoxDecoration(
                                  gradient: _disabledGradient,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x19000000),
                                      blurRadius: 15,
                                      offset: Offset(0, 10),
                                    ),
                                    BoxShadow(
                                      color: Color(0x11000000),
                                      blurRadius: 6,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Text(
                                    'Back',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Confirm button
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                if (_pickedPoint == null || _pickedName == null) return;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MeetupInvitePage(
                                      vibe: widget.vibe,
                                      locationName: _pickedName!,
                                      locationCoordinates: _pickedPoint!,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                height: 54,
                                decoration: BoxDecoration(
                                  gradient: _primaryGradient,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x19000000),
                                      blurRadius: 15,
                                      offset: Offset(0, 10),
                                    ),
                                    BoxShadow(
                                      color: Color(0x11000000),
                                      blurRadius: 6,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Text(
                                    'Confirm',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: MediaQuery.of(context).viewPadding.bottom),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}