// ███  add_a_friend.dart  ███
//
// Search‑and‑add page.
//
// • Same gradient & header/back button as the Friends screen.
// • Username‑only search bar styled like MapScreen’s.
//
// Future hook‑up:
//   – Replace the _allUsers dummy list with a REST call
//     (e.g. FriendService.search(usernamePrefix))
//   – When you tap a result, call your "send friend request"
//     endpoint then pop() back or show a confirmation.
//
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

/* layout constants kept in‑sync with the other screens */
const double _navBarHeight  = 88;
const double _centerFabSize = 64;

/* quick model */
class Friend {
  final String id;
  final String name;
  final String username;
  final String avatarUrl;
  const Friend(this.id, this.name, this.username, this.avatarUrl);
}

class AddFriendScreen extends StatefulWidget {
  const AddFriendScreen({super.key});
  @override State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  final _searchCtl = TextEditingController();

  /* —— dummy backend data —— */
  static const List<Friend> _allUsers = [
    Friend('1', 'Tony Soprano',   'waste_mgmt',  'https://i.pravatar.cc/150?img=68'),
    Friend('2', 'Walter White',   'heisenberg',  'https://i.pravatar.cc/150?img=32'),
    Friend('3', 'Jeff Zheng',     'lowkeythegoat',   'https://i.pravatar.cc/150?img=12'),
    Friend('4', 'Tanvir Jawad',   'ilikepreschools',  'https://i.pravatar.cc/150?img=47'),
    Friend('5', 'Ayman Mostafa',  'aytouch',    'https://i.pravatar.cc/150?img=8'),
  ];

  /* —— live‑filtered list —— */
  List<Friend> _results = _allUsers;

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String txt) {
    final q = txt.trim().toLowerCase();
    setState(() =>
      _results = q.isEmpty
          ? _allUsers
          : _allUsers
              .where((f) => f.username.toLowerCase().contains(q))
              .toList());
  }

  /* ───────────────────────────── BUILD ───────────────────────────── */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFFB3FFFF), Color(0xFFBABAF2)])),
        child: SafeArea(
          child: Column(children: [
            _header(context),
            const SizedBox(height: 12),
            _searchBar(),
            const SizedBox(height: 12),
            Expanded(child: _resultsList()),
          ]),
        ),
      ),
    );
  }

  /* —— header with back arrow —— */
  Widget _header(BuildContext ctx) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Row(children: [
      IconButton(
        icon: const Icon(Icons.arrow_back, size: 30, color: Color(0xFF4B5563)),
        onPressed: () => Navigator.pop(ctx)),
      const SizedBox(width: 8),
      const Text('Add a friend',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
    ]));

  /* —— rounded search bar —— */
  Widget _searchBar() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.65),
        borderRadius: BorderRadius.circular(32)),
      child: TextField(
        controller: _searchCtl,
        onChanged: _onSearchChanged,
        textInputAction: TextInputAction.search,
        decoration: const InputDecoration(
          hintText: 'Search username…',
          prefixIcon: Icon(Icons.search),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 14)),
      ),
    ));

  /* —— results —— */
  Widget _resultsList() => _results.isEmpty
      ? const Center(child: Text('No users found.',
          style: TextStyle(fontSize: 16, color: Colors.black54)))
      : ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, _navBarHeight + 12),
          itemCount: _results.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _friendTile(_results[i]));

  Widget _friendTile(Friend f) => GestureDetector(
    onTap: () {
      HapticFeedback.selectionClick();
      // TODO: send friend‑request API call
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sent request to @${f.username}')));
    },
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        CircleAvatar(radius: 28, backgroundImage: NetworkImage(f.avatarUrl)),
        const SizedBox(width: 16),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(f.name, style: const TextStyle(fontSize: 18)),
          Text('@${f.username}',
              style: const TextStyle(fontSize: 14, color: Colors.grey)),
        ])
      ])));
}


//How you’ll wire it up later
//Search API
//Replace _allUsers with a call to your backend endpoint each time the
//query changes (think debounce + FutureBuilder or a small Provider).

//Friend request
//Inside the onTap handler of _friendTile, call
//FriendService.sendRequest(currentUserId, f.id) and update the UI
//(e.g., grey‑out the tile or swap the icon to a check‑mark).

//Everything else—the gradient, header, and tile styling—already matches
//the existing screens, so it should slot right in. Happy testing!