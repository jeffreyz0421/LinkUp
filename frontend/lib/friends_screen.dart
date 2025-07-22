// ███  friends_screen.dart  ███
//
// Simple “Friends” page.
//
// ──────────────────────────────────────────────────────────
//  • Same gradient background & bottom‑nav layout as MapScreen.
//  • Shows the current user’s friends in a scrollable list
//      – real users will come from a future FriendService
//      – for now we inject a dummy list so you can see the UI.
//  • A transparent “Add friend” tile sits at the top of the list.
//  • Guests (isGuest == true) just see a friendly message.
//  • All sizing / colours match the profile & map screens so it
//    drops into the app without visual hiccups.
//

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:shared_preferences/shared_preferences.dart';
import 'add_a_friend.dart'; 

import 'cas.dart';                // for the centred +
import 'session_manager.dart';   // to detect guest / user‑id

/* ───── layout constants (same as other screens) ───── */
const double _navBarHeight  = 88;
const double _centerFabSize = 64;

/* ───── simple POJO for a friend ───── */
class Friend {
  final String id;
  final String name;
  final String username;
  final String avatarUrl;

  /// UI‑only for now – will be filled by backend later
  final String where;          // e.g. “Ann Arbor”
  final int    lastSeen;       // minutes ago

  Friend(
    this.id,
    this.name,
    this.username,
    this.avatarUrl, {
    required this.where,
    required this.lastSeen,
  });
}

final List<Friend> _dummyFriends = [
  Friend('1','Tony Soprano','@waste_mgmt',
         'https://i.pravatar.cc/150?img=68',
         where: 'Ann Arbor',  lastSeen: 24),
  Friend('2','Walter White','@heisenberg',
         'https://i.pravatar.cc/150?img=32',
         where: 'Detroit',    lastSeen: 5),
  Friend('3','Marty Byrde','@financials',
         'https://i.pravatar.cc/150?img=15',
         where: 'Chicago',    lastSeen: 120),
  Friend('d4', 'Michael Scott',  '@dundermifflin',
          'https://i.pravatar.cc/150?img=12',
          where: 'Dubai',    lastSeen: 51),
];

/* ═════════════════  FriendsScreen  ═════════════════ */
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});
  @override State<FriendsScreen> createState() => _FriendsScreenState();
}
// ── tiny header with a back button ──
Widget _header(BuildContext ctx) => Padding(
  padding: const EdgeInsets.only(top: 8, left: 8, right: 8),
  child: Row(
    children: [
      IconButton(
        icon: const Icon(Icons.arrow_back,
            size: 30, color: Color(0xFF4B5563)),
        onPressed: () => Navigator.pop(ctx),   // ← pops back to MapScreen
      ),
      const SizedBox(width: 8),
      const Text('Friends',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
    ],
  ),
);


class _FriendsScreenState extends State<FriendsScreen> {
  bool       _loading = true;
  bool       _isGuest = true;
  List<Friend> _friends = [];

  /* ── lifecycle ── */
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
  _isGuest = SessionManager.instance.isGuest;

  // always inject the stand‑ins while backend isn’t ready
  _friends = List.of(_dummyFriends);

  _isGuest = false;          // <── force‑show list

  if (mounted) setState(() => _loading = false);
}


  /* ═════════════════  BUILD  ═════════════════ */
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFFB3FFFF), Color(0xFFBABAF2)])),
        child: Stack(alignment: Alignment.bottomCenter, children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(context),                // ← always visible
                  const SizedBox(height: 16),
                  Expanded(
                    child: _isGuest
                        ? const Center(
                            child: Text(
                              'Sign in to view and add friends.',
                              style: TextStyle(fontSize: 18),
                            ),
                          )
                        : _friendList(),
                  ),
                ],
              ),
            ),
          ),
          _bottomNav(context),
          _fabPlus(context),
        ]),
      ),
    );
  }

  /* ───── listview with add‑button header ───── */
  Widget _friendList() => ListView.builder(
        padding: EdgeInsets.only(bottom: _navBarHeight + 12),
        itemCount: _friends.length + 1,   // +1 for the “add” tile
        itemBuilder: (ctx, i) {
          if (i == 0) return _addTile();
          final f = _friends[i - 1];
          return _friendTile(f);
        });

  Widget _addTile() => GestureDetector(
        onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AddFriendScreen()),
            );
          },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white60, width: 1.5),
          ),
          child: Row(children: const [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white30,
              child: Icon(Icons.person_add, color: Colors.deepPurple),
            ),
            SizedBox(width: 16),
            Text('Add friend',
                style: TextStyle(fontSize: 18, color: Colors.deepPurple)),
          ]),
        ),
      );

  Widget _friendTile(Friend f) => Container(
  margin: const EdgeInsets.only(bottom: 12),
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
  ),
  child: Row(
    children: [
      CircleAvatar(radius: 28, backgroundImage: NetworkImage(f.avatarUrl)),
      const SizedBox(width: 16),

      // ── left block: name + @user
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(f.name,  style: const TextStyle(fontSize: 18)),
            Text(f.username,
                style: const TextStyle(
                    fontSize: 14, color: Colors.grey, letterSpacing: .2)),
          ],
        ),
      ),

      // ── right block: location + time
      Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('in ${f.where}',
              style: const TextStyle(
                  fontSize: 14, color: Colors.green)),
          Text('${f.lastSeen} m ago',
              style: const TextStyle(
                  fontSize: 12, color: Colors.grey)),
        ],
      ),
    ],
  ),
);


  /* ───── bottom nav (Friends highlighted) ───── */
  Widget _bottomNav(BuildContext ctx) => Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: _navBarHeight,
          width: double.infinity,
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).padding.bottom),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(color: Colors.black26,
                  blurRadius: 12, offset: Offset(0, -4))
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(Icons.people_alt,   'Friends',
                  isActive: true, onTap: () {}),
              _navItem(Icons.home_rounded, 'Comunity',    onTap: () {}),
              const SizedBox(width: _centerFabSize),
              _navItem(Icons.link_outlined, 'Links',  onTap: () {}),
              _navItem(Icons.person_outline,'Profile', onTap: () {
                Navigator.pop(ctx);              // go back to profile
              }),
            ],
          ),
        ),
      );

  Widget _navItem(IconData icon, String label,
          {required VoidCallback onTap, bool isActive = false}) =>
      InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: isActive
                    ? BoxDecoration(
                        border: Border.all(color: Colors.purple, width: 2),
                        borderRadius: BorderRadius.circular(6))
                    : null,
                child: Icon(icon, size: 18,                         // ⬅︎ 21 → 18
                    color: isActive ? Colors.purple : const Color(0xFF4B5563))),
                const SizedBox(height: 2), 
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color:
                          isActive ? Colors.purple : Colors.grey.shade800)),
            ],
          ),
        ),
      );

  /* ───── centre FAB ───── */
  Widget _fabPlus(BuildContext ctx) => Positioned(
        bottom: _navBarHeight - (_centerFabSize / 2) - 6,
        child: GestureDetector(
          onTap: () => Navigator.of(ctx).push(
              MaterialPageRoute(builder: (_) => const CASScreen())),
          child: Container(
            width: _centerFabSize,
            height: _centerFabSize,
            decoration: BoxDecoration(
              color: Colors.deepPurpleAccent,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(color: Colors.black26,
                    blurRadius: 10, offset: Offset(0, 4)),
              ],
            ),
            child: const Center(
                child: Icon(Icons.add, color: Colors.white, size: 32)),
          ),
        ),
      );
}
