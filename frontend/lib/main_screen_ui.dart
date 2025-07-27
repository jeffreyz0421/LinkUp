// ███  lib/main_screen_ui.dart  ███
//
// UI layer for the Map screen.
//
//  • Rounded search bar
//  • Mapbox map with symbols & coloured radius‑circles
//  • Sliding detail panel
//  • FABs: locate‑me, explore, big “+”
//  • Bottom nav‑bar (Friends | Comm | + | Links | Profile)
//
//  NEW:
//  ────────────────────────────────────────────────────────────
//  If the radius being drawn belongs to the user’s *primary* community
//  (fetched from SessionManager) it is painted LIGHT‑ORANGE instead of
//  the normal green.
//

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;

import 'cas.dart';
import 'friends_screen.dart';
import 'community_screen.dart';
import 'profile_screen.dart';
import 'main_screen_logic.dart';
import 'session_manager.dart';   // ← added
import 'links_screen.dart';

/* ───── sizing ───── */
const double _navBarHeight  = 88.0;
const double _centerFabSize = 64.0;
const double _sideFabSize   = 48.0;

/* ═════════════════════════════════════════════════════ */

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends MapScreenLogicState<MapScreen> {
  /* cache the user’s own community once */
  String? _myCommunityId;

  /* ─────────────────────────────────── build ─────────────────────────────────── */

  @override
  Widget build(BuildContext context) {
    _myCommunityId ??= SessionManager.instance.primaryCommunityIdSync;
    return Scaffold(
      extendBody: true,
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          /* ───────── MAP ───────── */
          mapbox.MapWidget(
            styleUri: styleUri,
            cameraOptions: mapbox.CameraOptions(
              center: mapbox.Point(coordinates: camCenter),
              zoom  : camZoom,
            ),
            onMapCreated          : onMapCreated,
            onStyleLoadedListener : (_) => onStyleLoaded(),
            onCameraChangeListener: onCameraChange,
            onTapListener         : (c) => handleMapTap(c.point),
          ),

          /* ───────── SEARCH BAR ───────── */
          _searchBar(context),

          /* ───────── SLIDING PANEL ───────── */
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve   : Curves.easeOut,
            left    : 0,
            right   : 0,
            bottom  : panelVisible ? _navBarHeight - 32 : -panelHeight,
            height  : panelHeight - 10,
            child   : _buildDetailCard(context),
          ),

          /* ───────── OVERLAYS ───────── */
          _fabLocateMe(context),
          _fabExplore(context),
          _bottomNavBar(context),
          _centerFab(context),
        ],
      ),
    );
  }

  /* ═════════════════ widgets (unchanged, shortened for brevity) ═══════════════ */

  Widget _searchBar(BuildContext ctx) => Positioned(
        top : MediaQuery.of(ctx).padding.top + 16,
        left: 16,
        right: 16,
        child: GestureDetector(
          onTap: () async {
            final picked = await showSearch<Place?>(
              context : ctx,
              delegate: PlaceSearchDelegate(
                remote,
                lastPos != null
                    ? mapbox.Position(lastPos!.longitude, lastPos!.latitude)
                    : null,
              ),
            );
            if (picked != null) goToPlace(picked);
          },
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xF0EAE6FD),
              borderRadius: BorderRadius.circular(34),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Looking for something?',
                      style: TextStyle(fontSize: 16, color: Colors.black54)),
                ),
                Icon(Icons.search, color: Colors.grey.shade700),
              ],
            ),
          ),
        ),
      );

  Widget _fabExplore(BuildContext ctx) => Positioned(
        right : 20,
        bottom: _navBarHeight + _sideFabSize + 28,
        child : SizedBox(
          width : _sideFabSize,
          height: _sideFabSize,
          child : FloatingActionButton(
            heroTag         : 'explore_globe',
            elevation       : 4,
            backgroundColor : Colors.white,
            foregroundColor : Colors.deepPurple,
            onPressed       : resetView,
            child           : const Icon(Icons.public),
          ),
        ),
      );

  Widget _fabLocateMe(BuildContext ctx) => Positioned(
        right : 20,
        bottom: _navBarHeight + 20,
        child : SizedBox(
          width : _sideFabSize,
          height: _sideFabSize,
          child : FloatingActionButton(
            heroTag         : 'locate_me',
            backgroundColor : Colors.white,
            foregroundColor : Colors.blueAccent,
            onPressed       : flyToUser,
            child           : const Icon(Icons.my_location_rounded),
          ),
        ),
      );

  Widget _bottomNavBar(BuildContext ctx) => Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: _navBarHeight,
          width : double.infinity,
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).padding.bottom),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(color: Colors.black26,
                  blurRadius: 12, offset: Offset(0, -4))
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(Icons.people_alt, 'Friends', onTap: () {
                Navigator.of(ctx).push(MaterialPageRoute(
                    builder: (_) => const FriendsScreen()));
              }),
              _navItem(Icons.home_rounded, 'Comunity', onTap: () {
                Navigator.of(ctx).push(MaterialPageRoute(
                    builder: (_) => const CommunityScreen()));
              }),
              const SizedBox(width: _centerFabSize),
              _navItem(Icons.link_outlined, 'Links', onTap: () {
                Navigator.of(ctx).push(MaterialPageRoute(
                    builder: (_) => const LinksScreen()));
              }),
              _navItem(Icons.person_outline, 'Profile', onTap: () {
                Navigator.of(ctx).push(MaterialPageRoute(
                    builder: (_) => const ProfileScreen()));
              }),
            ],
          ),
        ),
      );

  Widget _navItem(IconData ic, String lbl,
          {required VoidCallback onTap}) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(ic, size: 20, color: Colors.grey.shade700),
              const SizedBox(height: 2),
              Text(lbl,
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      );

  Widget _centerFab(BuildContext ctx) => Positioned(
        bottom: _navBarHeight - (_centerFabSize / 2) - 6,
        child: GestureDetector(
          onTap: () => Navigator.of(ctx)
              .push(MaterialPageRoute(builder: (_) => const CASScreen())),
          child: Container(
            width : _centerFabSize,
            height: _centerFabSize,
            decoration: BoxDecoration(
              color: Colors.deepPurpleAccent,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 4))
              ],
            ),
            child: const Center(
                child: Icon(Icons.add, color: Colors.white, size: 32)),
          ),
        ),
      );

  /* ═════════════════ radius‑circle colour override ═════════════════ */

  @override
  mapbox.CircleLayer buildCommunityRadiusLayer(
  String communityId, {
  required mapbox.Point center,
}) {
  final bool mine =
      communityId == SessionManager.instance.primaryCommunityIdSync;

  return mapbox.CircleLayer(
    id                  : 'radius_$communityId',
    sourceId            : 'source_$communityId',
    circleRadius        : 6000,                      // metres
    circleColor         : mine ? 0xFFFFE6B3 : 0xFF9DD4B3,  // <-- ARGB ints
    circleOpacity       : 0.35,
    circleStrokeColor   : 0xFF000000,                // black
    circleStrokeOpacity : 0.12,
    circleStrokeWidth   : 1,
  );
}
  /* ═════════════════ detail panel & helpers ═════════════════ */
  /// public alias so other files can call it
  Widget buildDetailCard(BuildContext ctx) => _buildDetailCard(ctx);
  /// Sliding panel that appears after a tap / search.
  /// Pure UI – all data comes from the mix‑in getters.
  Widget _buildDetailCard(BuildContext ctx) {
    if (selectedName == null) return const SizedBox.shrink();

    return Material(
      elevation: 12,
      color: const Color(0xFFF7F2FD),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            12 + MediaQuery.of(ctx).viewPadding.bottom,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.85,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // tag list stretches, can wrap onto new lines:
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: selectedTags.map(_tagChip).toList(),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 24,
                          color: Colors.deepPurple,
                        ),
                        tooltip: 'Close',
                        onPressed: () async {
                          await clearRoute();
                          setPanelVisible(false);
                        },
                      ),
                    ],
                  ),

                  /* name */
                  Text(
                    selectedName!,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  /* address */
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          (selectedAddress?.isNotEmpty ?? false)
                              ? selectedAddress!
                              : 'Address unavailable',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),

                  /* photo strip */
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 92,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: selectedPhotos.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, i) {
                        final url = selectedPhotos[i];
                        return GestureDetector(
                          onTap: () => showPhotoViewer(ctx, url),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Hero(
                              tag: url,
                              child: Image.network(
                                url,
                                width: 140,
                                height: 92,
                                fit: BoxFit.cover,
                                loadingBuilder: (_, img, p) => p == null
                                    ? img
                                    : const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                errorBuilder: (_, __, ___) => Container(
                                  width: 140,
                                  height: 92,
                                  color: Colors.grey.shade200,
                                  child: Icon(
                                    Icons.broken_image,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  /* ETA / mode buttons */
                  if (etaMinutes['drive'] != null && !showAllEtas)
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          if (lastPos == null || selectedPosition == null)
                            return;
                          await drawRoute(
                            'drive',
                            from: mapbox.Position(
                              lastPos!.longitude,
                              lastPos!.latitude,
                            ),
                            to: selectedPosition!,
                          );
                          setActiveMode('drive');
                          setShowAllEtas(true);

                          // fire off bike / walk in background
                          fetchEta(
                            'bike',
                            from: mapbox.Position(
                              lastPos!.longitude,
                              lastPos!.latitude,
                            ),
                            to: selectedPosition!,
                          );
                          fetchEta(
                            'walk',
                            from: mapbox.Position(
                              lastPos!.longitude,
                              lastPos!.latitude,
                            ),
                            to: selectedPosition!,
                          );
                        },
                        icon: const Icon(
                          Icons.directions_car_filled_rounded,
                          size: 20,
                        ),
                        label: Text('${etaMinutes['drive']} min'),
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
                  else if (showAllEtas)
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
        ),
      ),
    );
  }

  /* pill‑style tag chip */
  Widget _tagChip(String lbl) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.deepPurple,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      lbl,
      style: const TextStyle(
        fontSize: 12,
        letterSpacing: .4,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
  );

  /* drive / bike / walk chips */
  Widget _modeChip(String mode, IconData icon) {
    final mins = etaMinutes[mode];
    final selected = activeMode == mode;

    return ActionChip(
      avatar: Icon(
        icon,
        size: 18,
        color: selected ? Colors.white : Colors.deepPurple,
      ),
      label: Text(
        mins != null ? '$mins min' : '…',
        style: TextStyle(color: selected ? Colors.white : Colors.deepPurple),
      ),
      backgroundColor: selected ? Colors.deepPurple : Colors.deepPurple.shade50,
      onPressed: mins == null
          ? null
          : () async {
              setActiveMode(mode);
              if (lastPos == null) return;
              await drawRoute(
                mode,
                from: mapbox.Position(lastPos!.longitude, lastPos!.latitude),
                to: camCenter, // current camera centre
              );
            },
    );
  }
}
