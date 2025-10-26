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
// lib/friends_screen.dart
// lib/friends_screen.dart

// lib/friends_screen.dart
// lib/friends_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:http/http.dart' as http;

import 'session_manager.dart';
import 'models/friend.dart';
import 'services/friend_service.dart' show FriendService;
import 'add_a_friend.dart';
import 'cas.dart'; // for the centered “+” FAB

const double _navBarHeight  = 88;
const double _centerFabSize = 64;

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({Key? key}) : super(key: key);

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _service = FriendService(http.Client());
  bool         _loading = true;
  bool         _isGuest = true;
  List<Friend> _friends = [];
  String?      _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    _isGuest = SessionManager.instance.isGuest;
    if (!_isGuest) {
      try {
        _friends = await _service.listFriends();
      } catch (e) {
        _error = 'Failed to load friends: $e';
      }
    }
    setState(() => _loading = false);
  }

  Widget _header(BuildContext ctx) => Padding(
        padding: const EdgeInsets.only(top: 8, left: 8, right: 8),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back,
                  size: 30, color: Color(0xFF4B5563)),
              onPressed: () => Navigator.pop(ctx),
            ),
            const SizedBox(width: 8),
            const Text('Friends',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const Spacer(),
            // ← new add-friend button
            IconButton(
              icon: const Icon(Icons.person_add, color: Color(0xFF4B5563)),
              tooltip: 'Add a friend',
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.of(ctx).push(
                  MaterialPageRoute(builder: (_) => const AddFriendScreen()),
                );
              },
            ),
          ],
        ),
      );

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
            colors: [Color(0xFFB3FFFF), Color(0xFFBABAF2)],
          ),
        ),
        child: Stack(alignment: Alignment.bottomCenter, children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(context),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _isGuest
                        ? const Center(
                            child: Text(
                              'Sign in to view and add friends.',
                              style: TextStyle(fontSize: 18),
                            ),
                          )
                        : _buildFriendList(),
                  ),
                ],
              ),
            ),
          ),
          _buildBottomNav(context),
          _buildFabPlus(context),
        ]),
      ),
    );
  }

  Widget _buildFriendList() {
    if (_error != null) {
      return Center(
          child: Text(_error!, style: const TextStyle(color: Colors.red)));
    }
    if (_friends.isEmpty) {
      return const Center(
          child: Text('You have no friends yet.',
              style: TextStyle(fontSize: 18)));
    }
    return ListView.builder(
      padding: EdgeInsets.only(bottom: _navBarHeight + 12),
      itemCount: _friends.length + 1,
      itemBuilder: (ctx, i) {
        if (i == 0) return _buildAddTile();
        final f = _friends[i - 1];
        return _buildFriendTile(f);
      },
    );
  }

  Widget _buildAddTile() => GestureDetector(
        onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddFriendScreen())),
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

  Widget _buildFriendTile(Friend f) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundImage: f.avatarUrl.isNotEmpty
                  ? NetworkImage(f.avatarUrl)
                  : const AssetImage('assets/default_pfp.png')
                      as ImageProvider,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f.name, style: const TextStyle(fontSize: 18)),
                  Text('@${f.username}',
                      style: const TextStyle(
                          fontSize: 14, color: Colors.grey, letterSpacing: .2)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('in ${f.where}',
                    style: const TextStyle(fontSize: 14, color: Colors.green)),
                Text('${f.lastSeen} m ago',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ],
        ),
      );

  Widget _buildBottomNav(BuildContext ctx) => Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: _navBarHeight,
          width: double.infinity,
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).padding.bottom),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black26, blurRadius: 12, offset: Offset(0, -4))
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(Icons.people_alt, 'Friends',
                  isActive: true, onTap: () {}),
              _navItem(Icons.home_rounded, 'Comunity', onTap: () {}),
              const SizedBox(width: _centerFabSize),
              _navItem(Icons.link_outlined, 'Links', onTap: () {}),
              _navItem(Icons.person_outline, 'Profile', onTap: () {
                Navigator.pushReplacementNamed(ctx, '/profile');
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
                        borderRadius: BorderRadius.circular(6),
                      )
                    : null,
                child: Icon(icon,
                    size: 18,
                    color: isActive ? Colors.purple : const Color(0xFF4B5563)),
              ),
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

  Widget _buildFabPlus(BuildContext ctx) => Positioned(
        bottom: _navBarHeight - (_centerFabSize / 2) - 6,
        child: GestureDetector(
          onTap: () => Navigator.of(ctx)
              .push(MaterialPageRoute(builder: (_) => const CASScreen())),
          child: Container(
            width: _centerFabSize,
            height: _centerFabSize,
            decoration: BoxDecoration(
              color: Colors.deepPurpleAccent,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))
              ],
            ),
            child: const Center(child: Icon(Icons.add, color: Colors.white, size: 32)),
          ),
        ),
      );
}
