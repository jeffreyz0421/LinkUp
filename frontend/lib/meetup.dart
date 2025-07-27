// lib/meetup.dart

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:http/http.dart' as http;

import 'session_manager.dart';
import 'services/profile_service.dart';
import 'main_screen_ui.dart';
import 'cas.dart';
import 'main_screen_logic.dart'; // brings in styleUri

/// Entry point for the 4‑step Meetup wizard
class MeetupFlow extends StatelessWidget {
  const MeetupFlow({super.key});
  @override
  Widget build(BuildContext context) => const MeetupVibePage();
}

/// STEP 1/4: Select VIBE
/// /// STEP 1/4: Select VIBE
/// /// STEP 1/4: Select VIBE
/// /// STEP 1/4: Select VIBE

class MeetupVibePage extends StatefulWidget {
  const MeetupVibePage({super.key});
  @override
  State<MeetupVibePage> createState() => _MeetupVibePageState();
}

class _MeetupVibePageState extends State<MeetupVibePage> {
  final _allVibes = <String>[
    'Basketball',
    'Soccer',
    'Book Club',
    'Hiking',
    'Cooking',
    'Board Games',
    'Music',
    'Tennis',
    'DJ',
    'League of Legends',
    'Watch a Movie',
    'Touching',
    'Coding',
    'Photography',         //List for now, will implement a backend later
  ];
  List<String> _hobbies = [];
  String? _selectedVibe;
  final _searchCtl = TextEditingController();

  List<String> get _filtered {
    final q = _searchCtl.text.toLowerCase();
    final filtered = q.isEmpty
        ? List<String>.from(_allVibes)
        : _allVibes.where((v) => v.toLowerCase().contains(q)).toList();
    // Promote exact match to front:
    filtered.sort((a, b) {
      if (a.toLowerCase() == q) return -1;
      if (b.toLowerCase() == q) return 1;
      return 0;
    });
    return filtered;
  }

  @override
  void initState() {
    super.initState();
    _loadHobbies();
  }

  //Future<void> _loadHobbies() async {
  //  final userId = await SessionManager.instance.userId;
  //  if (userId != null) {
  //    try {
  //      _hobbies = await ProfileService(http.Client()).getHobbies(userId);
  //    } catch (_) {
        // Fallback to empty list or dummy data
   //     _hobbies = [];
   //   }
   // }
   // if (mounted) setState(() {});
  //}
  Future<void> _loadHobbies() async {
  try {
    // comment out the real network fetch until the backend is live
    // _hobbies = await ProfileService(http.Client()).getHobbies(userId);
    _hobbies = ['Coding','Music','Photography'];
  } catch (_) {
    _hobbies = [];
  }
  if (mounted) setState(() {});
}

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('What event is your meetup?'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.black54),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFB3FFFF), Color(0xFFBABAF2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // — Search bar —
            TextField(
              controller: _searchCtl,
              decoration: InputDecoration(
                hintText: 'Search vibes…',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white70,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),

            // — Always show this header & section divider —
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Based on your hobbies',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _hobbies.map((h) {
                final selected = _selectedVibe == h;
                return ChoiceChip(
                  label: Text(
                    h,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.black87,
                    ),
                  ),
                  backgroundColor: Colors.purple.shade100,
                  selectedColor: Colors.deepPurple,
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedVibe = h),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.grey),
            const SizedBox(height: 16),

            // — All vibes —
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _filtered.map((v) {
                    final isSel = _selectedVibe == v;
                    return ChoiceChip(
                      label: Text(v),
                      selected: isSel,
                      selectedColor: Colors.deepPurpleAccent,
                      onSelected: (_) => setState(() {
                        _selectedVibe = v;
                        if (!_allVibes.contains(v)) _allVibes.add(v);
                      }),
                    );
                  }).toList(),
                ),
              ),
            ),

            // — Next button with white text when enabled, grey when disabled —
            ElevatedButton(
              onPressed: _selectedVibe == null
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              MeetupLocationPage(vibe: _selectedVibe!),
                        ),
                      );
                    },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white, // enabled text
                disabledForegroundColor: Colors.grey, // disabled text
              ),
              child: const Text('Next'),
            ),
          ],
        ),
      ),
    );
  }
}

/// STEP 2/4: Select LOCATION on Map
/// /// STEP 2/4: Select LOCATION on Map
/// /// STEP 2/4: Select LOCATION on Map
/// STEP 2/4: Select LOCATION on Map
class MeetupLocationPage extends StatefulWidget {
  final String vibe;
  const MeetupLocationPage({ required this.vibe, super.key });

  @override
  State<MeetupLocationPage> createState() => _MeetupLocationPageState();
}

/// NOTE: we *extend* MapScreenLogicState<T> so we inherit all your map+search+locate‑me logic.
class _MeetupLocationPageState
    extends MapScreenLogicState<MeetupLocationPage> {

  mapbox.Point? _pickedPoint;
  String?      _pickedName;

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
            onMapCreated          : onMapCreated,
            onStyleLoadedListener : (_) => onStyleLoaded(),
            onCameraChangeListener: onCameraChange,
            onTapListener: (event) async {
              // first, run the mix‑in logic and wait for it to finish:
              await handleMapTap(event.point);

              // now selectedName / selectedPosition have been updated,
              // so copy them into your local fields and rebuild:
              setState(() {
                _pickedPoint = selectedPosition != null
                    ? mapbox.Point(coordinates: selectedPosition!)
                    : null;
                _pickedName  = selectedName;
              });
            },
          ),

          // ─────────── locate‐me FAB ───────────
          Positioned(
            right : 20,
            bottom: 88 + 20, // same offset as your main screen
            child : SizedBox(
              width : 48, height: 48,
              child : FloatingActionButton(
                heroTag         : 'locate_me',
                backgroundColor : Colors.white,
                foregroundColor : Colors.blueAccent,
                onPressed       : flyToUser,
                child           : const Icon(Icons.my_location_rounded),
              ),
            ),
          ),

          // ─────────── search bar ───────────
          Positioned(
            top : MediaQuery.of(context).padding.top + 16,
            left: 16, right: 16,
            child: GestureDetector(
              onTap: () async {
                final result = await showSearch<Place?>(
                  context : context,
                  delegate: PlaceSearchDelegate(
                    remote,
                    lastPos != null
                      ? mapbox.Position(lastPos!.longitude, lastPos!.latitude)
                      : null,
                  ),
                );
                if (result != null) {
                  // animate camera & record selection
                  await goToPlace(result);
                  setState(() {
                    _pickedPoint = mapbox.Point(coordinates: result.coord);
                    _pickedName  = result.name;
                  });
                }
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
                      child: Text(
                        'Search a place…',
                        style: TextStyle(fontSize: 16, color: Colors.black54),
                      ),
                    ),
                    Icon(Icons.search, color: Colors.grey.shade700),
                  ],
                ),
              ),
            ),
          ),

          // ─────────── header (just below search) ───────────
          Positioned(
            top : MediaQuery.of(context).padding.top + 56 + 24,
            left: 16,
            child: Row(
              children: const [
                BackButton(color: Colors.black54),
                SizedBox(width: 8),
                Text(
                  'Select a spot',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // ─────────── DETAIL PANEL (from your mix‑in) ───────────
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            left: 0,
            right: 0,
            // slide up from off‐screen when panelVisible is true:
            bottom: panelVisible ? 0 : -panelHeight,
            height: panelHeight,
            child: buildDetailCard(context),
          ),

          // ─────────── bottom confirm card ───────────
          if (_pickedName != null)
            Container(
              margin: const EdgeInsets.only(top: 0),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 12,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // “You are selecting:” italic, then name bold
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 16, color: Colors.black87),
                      children: [
                        const TextSpan(
                          text: 'You are selecting: ',
                          style: TextStyle(fontStyle: FontStyle.italic),
                        ),
                        TextSpan(
                          text: _pickedName,
                          style: const TextStyle(
                            fontStyle: FontStyle.normal,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // No
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _pickedPoint = null;
                            _pickedName  = null;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24)),
                        ),
                        child: const Text('No',
                            style: TextStyle(color: Colors.white)),
                      ),

                      // Yes → next step
                      ElevatedButton(
                        onPressed: () {
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
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24)),
                        ),
                        child: const Text('Yes',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
/// STEP 3/4: Invite Friends / Suggested
/// /// STEP 3/4: Invite Friends / Suggested
/// /// STEP 3/4: Invite Friends / Suggested
/// /// STEP 3/4: Invite Friends / Suggested
///
class MeetupInvitePage extends StatefulWidget {
  final String vibe;
  final String locationName;
  final mapbox.Point locationCoordinates;
  const MeetupInvitePage({
    required this.vibe,
    required this.locationName,
    required this.locationCoordinates,
    super.key,
  });
  @override
  State<MeetupInvitePage> createState() => _MeetupInvitePageState();
}

class _MeetupInvitePageState extends State<MeetupInvitePage> {
  final List<String> _friends = ['Alice', 'Bob', 'Charlie', 'Dave'];
  final List<String> _suggested = ['Eve', 'Frank', 'Grace'];
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Who do you invite?'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.black54),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFB3FFFF), Color(0xFFBABAF2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Your friends',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ..._friends.map(
              (f) => CheckboxListTile(
                title: Text(f),
                subtitle: Text(widget.vibe),
                value: _selected.contains(f),
                onChanged: (_) => setState(() {
                  if (_selected.contains(f))
                    _selected.remove(f);
                  else
                    _selected.add(f);
                }),
              ),
            ),
            const Divider(),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Suggested',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ..._suggested.map(
              (f) => CheckboxListTile(
                title: Text(f),
                subtitle: const Text('Nearby'),
                value: _selected.contains(f),
                onChanged: (_) => setState(() {
                  if (_selected.contains(f))
                    _selected.remove(f);
                  else
                    _selected.add(f);
                }),
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _selected.isEmpty
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MeetupConfirmPage(
                          vibe: widget.vibe,
                          locationName: widget.locationName,
                          coordinates: widget.locationCoordinates,
                          invited: _selected.toList(),
                        ),
                      ),
                    ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white, 
              ),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}

/// STEP 4/4: Confirmation + Create
/// /// STEP 4/4: Confirmation + Create
/// /// STEP 4/4: Confirmation + Create
/// /// STEP 4/4: Confirmation + Create
class MeetupConfirmPage extends StatefulWidget {
  final String vibe;
  final String locationName;
  final mapbox.Point coordinates;
  final List<String> invited;
  const MeetupConfirmPage({
    required this.vibe,
    required this.locationName,
    required this.coordinates,
    required this.invited,
    super.key,
  });
  @override
  State<MeetupConfirmPage> createState() => _MeetupConfirmPageState();
}

class _MeetupConfirmPageState extends State<MeetupConfirmPage> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime? _start;

  Future<void> _pickDateTime() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(hours: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d == null) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (t == null) return;
    setState(() {
      _start = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  Future<void> _createEvent() async {
    // TODO: POST to your backend CreateMeetup endpoint here
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm your meetup'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.black54),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFB3FFFF), Color(0xFFBABAF2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Event Name'),
            ),
            const SizedBox(height: 12),
            ListTile(
              title: const Text('Starts at'),
              subtitle: Text(
                _start == null ? 'Pick a time' : _start.toString(),
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDateTime,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const Divider(height: 32),
            Text('Vibe: ${widget.vibe}'),
            Text('Location: ${widget.locationName}'),
            Text('Invited: ${widget.invited.join(', ')}'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: (_nameCtrl.text.isNotEmpty && _start != null)
                  ? _createEvent
                  : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white, 
              ),
              child: const Text('Create Meetup'),
            ),
          ],
        ),
      ),
    );
  }
}
