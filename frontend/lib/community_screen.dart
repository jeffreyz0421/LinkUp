// ███  community_screen.dart  ███
//
// A very first pass at the “Communities” page.
//
// ──────────────────────────────────────────────────────────
//  • Matches gradient + bottom‑nav styling of other screens.
//  • Lists the communities the signed‑in user belongs to.
//      – “MY COMMUNITY” tag shown for the primary community.
//      – For now we inject a dummy list so you can see the UI.
//  • A transparent “Join a community” tile sits on top.
//  • Guests just see a sign‑in message.
//  • Clicking “Join” just pops a SnackBar (placeholder).
//

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import 'cas.dart';
import 'session_manager.dart';

/* ───── shared layout constants ───── */
const double _navBarHeight  = 88;
const double _centerFabSize = 64;

/* ───── simple model ───── */
class Community {
  final String id;
  final String name;
  final bool  isMine;
  final String logo;           // new
  Community(this.id, this.name,
      {this.isMine = false, required this.logo});
}

/* ═════════════════════════════════════ */

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});
  @override State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  bool _loading = true;
  bool _isGuest = true;
  List<Community> _communities = [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    _isGuest = SessionManager.instance.isGuest;

    if (!_isGuest) {
      // Dummy data for now
      _communities = [
        Community('u‑mich',  'University of Michigan',
            isMine: true,  logo: 'assets/logos/Umich_Logo.png'),
        Community('harvard', 'Harvard University',
            logo: 'assets/logos/Harvard_logo.png'),
        Community('stanford','Stanford University',
            logo: 'assets/logos/stanford_logo.png'),
      ];
    }

    if (mounted) setState(() => _loading = false);
  }

  /* ════════════  BUILD  ════════════ */

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
                  _header(context),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _isGuest
                      ? const Center(
                          child: Text('Sign in to view and join communities.',
                              style: TextStyle(fontSize: 18)))
                      : _communityList(),
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

  /* ───── header with back arrow ───── */
  Widget _header(BuildContext ctx) => Row(
    children: [
      IconButton(
        icon: const Icon(Icons.arrow_back, size: 30, color: Color(0xFF4B5563)),
        onPressed: () => Navigator.pop(ctx),
      ),
      const SizedBox(width: 8),
      const Text('Communities',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
    ],
  );

  /* ───── list with “join” tile ───── */
  Widget _communityList() => ListView.builder(
    padding: EdgeInsets.only(bottom: _navBarHeight + 12),
    itemCount: _communities.length + 1,         // +1 for join tile
    itemBuilder: (ctx, i) {
      if (i == 0) return _joinTile();
      final c = _communities[i - 1];
      return _communityTile(c);
    });

  Widget _joinTile() => GestureDetector(
    onTap: () {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Join‑community coming soon')));
    },
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white60, width: 1.5)),
      child: Row(children: const [
        CircleAvatar(
          radius: 28, backgroundColor: Colors.white30,
          child: Icon(Icons.add_circle_outline,
              color: Colors.deepPurple)),
        SizedBox(width: 16),
        Text('Join a community',
            style: TextStyle(fontSize: 18, color: Colors.deepPurple)),
      ]),
    ),
  );

  Widget _communityTile(Community c) => Container(
  margin: const EdgeInsets.only(bottom: 12),
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12)),
  child: Row(children: [
    CircleAvatar(
      radius: 28,
      backgroundImage: AssetImage(c.logo),
      backgroundColor:
          c.isMine ? const Color(0xFFFFE0B2) : const Color(0xFFD1C4E9)),
    const SizedBox(width: 16),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(c.name,
                style: const TextStyle(fontSize: 18,
                    fontWeight: FontWeight.w500)),
            if (c.isMine)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC107),   // gold
                  borderRadius: BorderRadius.circular(4)),
                child: const Text('MY COMMUNITY',
                    style: TextStyle(
                      fontSize: 10, color: Colors.white,
                      letterSpacing: .5))),
          ],
        ),
      ),
    ]),
  );

  /* ───── bottom nav (Comm highlighted) ───── */
  Widget _bottomNav(BuildContext ctx) => Align(
    alignment: Alignment.bottomCenter,
    child: Container(
      height: _navBarHeight,
      width: double.infinity,
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).padding.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [BoxShadow(
          color: Colors.black26, blurRadius: 12, offset: Offset(0,-4))]),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _navItem(Icons.people_alt, 'Friends',
            onTap: () => Navigator.pop(ctx)),           // back to Friends/Map
        _navItem(Icons.home_rounded, 'Comm',
            isActive: true, onTap: () {}),
        const SizedBox(width: _centerFabSize),
        _navItem(Icons.link_outlined, 'Links', onTap: () {}),
        _navItem(Icons.person_outline, 'Profile', onTap: () {}),
      ]),
    ));

  Widget _navItem(IconData ic, String lbl,
      {required VoidCallback onTap, bool isActive = false}) => InkWell(
    onTap: () { HapticFeedback.lightImpact(); onTap(); },
    borderRadius: BorderRadius.circular(8),
    child: SizedBox(
      width: 64,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: isActive
              ? BoxDecoration(
                  border: Border.all(color: Colors.purple, width: 2),
                  borderRadius: BorderRadius.circular(6))
              : null,
          child: Icon(ic, size: 18,
              color: isActive ? Colors.purple : const Color(0xFF4B5563))),
        const SizedBox(height: 2),
        Text(lbl,
            style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w500,
              color: isActive ? Colors.purple : Colors.grey.shade800)),
      ]),
    ));

  /* ───── centre FAB ───── */
  Widget _fabPlus(BuildContext ctx) => Positioned(
    bottom: _navBarHeight - (_centerFabSize / 2) - 6,
    child: GestureDetector(
      onTap: () => Navigator.of(ctx).push(
          MaterialPageRoute(builder: (_) => const CASScreen())),
      child: Container(
        width: _centerFabSize, height: _centerFabSize,
        decoration: BoxDecoration(
          color: Colors.deepPurpleAccent, shape: BoxShape.circle,
          boxShadow: const [BoxShadow(
            color: Colors.black26, blurRadius: 10, offset: Offset(0,4))]),
        child: const Center(
            child: Icon(Icons.add, color: Colors.white, size: 32)),
      ),
    ));
}
