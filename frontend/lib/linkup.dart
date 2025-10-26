import 'dart:async';
import 'package:flutter/material.dart';
import 'main_screen_ui.dart'; // MapScreen

class LinkupScreen extends StatefulWidget {
  const LinkupScreen({super.key});
  @override
  State<LinkupScreen> createState() => _LinkupScreenState();
}

class _LinkupScreenState extends State<LinkupScreen> {
  final _controller = PageController();
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    // Auto-advance from Searching -> Match after 2s
    _autoTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      _controller.animateToPage(
        1,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _goToMatchRequest() {
    _controller.animateToPage(
      2,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
    );
  }

  void _goHome(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MapScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _controller,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _SearchingPage(),
          _MatchFoundPage(onLinkup: _goToMatchRequest),
          _RequestSentPage(onReturnHome: () => _goHome(context)),
        ],
      ),
    );
  }
}

/* ─────────────────────────────────────────────
 * PAGE 1: SEARCHING (animated dots + responsive)
 * ──────────────────────────────────────────── */
class _SearchingPage extends StatefulWidget {
  @override
  State<_SearchingPage> createState() => _SearchingPageState();
}

class _SearchingPageState extends State<_SearchingPage>
    with SingleTickerProviderStateMixin {
  int _dotIndex = 0;
  late final Timer _dotTimer;

  @override
  void initState() {
    super.initState();
    _dotTimer = Timer.periodic(const Duration(milliseconds: 280), (_) {
      if (!mounted) return;
      setState(() => _dotIndex = (_dotIndex + 1) % 3);
    });
  }

  @override
  void dispose() {
    _dotTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final padTop = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFAF5FF), Color(0xFFFDF2F8), Color(0xFFFFF7ED)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Stack(
        children: [
          // White card frame
          Positioned.fill(
            left: 3,
            right: 3,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x3F000000),
                    blurRadius: 50,
                    offset: Offset(0, 25),
                  ),
                ],
                borderRadius: BorderRadius.circular(0),
              ),
            ),
          ),
          // Gradient header
          Positioned(
            top: 0,
            left: 3,
            right: 3,
            child: Container(
              height: 72 + padTop,
              padding: EdgeInsets.only(top: padTop),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF065BD4), Color(0xFF07A8D5), Color(0xFF0842D6)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: const Center(
                child: Text(
                  'LinkUp Vibe',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ),
          ),

          // Magnifier
          const Align(
            alignment: Alignment(0, -0.1),
            child: Icon(Icons.search, size: 120, color: Color(0xFF24519A)),
          ),

          // Animated "SEARCHING..." with dots
          Align(
            alignment: const Alignment(0, 0.25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'SEARCHING FOR YOUR\nNEXT LOCAL BUDDY',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF24519A),
                    fontSize: 28, // slight downscale for small phones
                    fontFamily: 'Luckiest Guy',
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) {
                    return AnimatedOpacity(
                      opacity: _dotIndex == i ? 1 : 0.28,
                      duration: const Duration(milliseconds: 220),
                      child: const Text(
                        '.',
                        style: TextStyle(
                          fontSize: 32,
                          color: Color(0xFF24519A),
                          fontFamily: 'Luckiest Guy',
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),

          // Helper text
          const Align(
            alignment: Alignment(0, 0.75),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'We are currently looking for potential matches based on your preferences. Please wait a moment.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF4B5563),
                  fontSize: 16,
                  fontFamily: 'Roboto',
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ─────────────────────────────────────────────
 * PAGE 2: MATCH FOUND (proxy data + exact UI bits)
 * ──────────────────────────────────────────── */
class _ProxyMatch {
  final String name, handle, photoUrl, location, time;
  final List<_Hobby> hobbies;
  _ProxyMatch({
    required this.name,
    required this.handle,
    required this.photoUrl,
    required this.location,
    required this.time,
    required this.hobbies,
  });
}

class _Hobby {
  final String label;
  final IconData icon;
  final List<Color> gradient;
  _Hobby(this.label, this.icon, this.gradient);
}

class _MatchFoundPage extends StatelessWidget {
  final VoidCallback onLinkup;
  _MatchFoundPage({required this.onLinkup, super.key});

  final _ProxyMatch match = _ProxyMatch(
    name: 'Sophia Lee',
    handle: '@sophialee',
    photoUrl: 'https://placehold.co/128x128',
    location: 'Campus Cafe',
    time: 'Just now',
    hobbies: [
      _Hobby('Gaming', Icons.sports_esports_rounded, [const Color(0xFF065CD4), const Color(0xFF07A8D5)]),
      _Hobby('Basketball', Icons.sports_basketball_rounded, [const Color(0xFF07A8D5), const Color(0xFF065CD4)]),
      _Hobby('Coffee\nChat', Icons.local_cafe_rounded, [const Color(0xFF065CD4), const Color(0xFF07A8D5)]),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final padTop = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFAF5FF), Color(0xFFFDF2F8), Color(0xFFFFF7ED)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            left: 3,
            right: 3,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x3F000000),
                    blurRadius: 50,
                    offset: Offset(0, 25),
                  ),
                ],
              ),
            ),
          ),

          // Header with back chevron
          Positioned(
            top: 0,
            left: 3,
            right: 3,
            child: Container(
              height: 72 + padTop,
              padding: EdgeInsets.only(top: padTop),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF065BD4), Color(0xFF07A8D5), Color(0xFF0842D6)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  _circleButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const Spacer(),
                  const Text(
                    'LinkUp Vibe',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),

          // Big checkmark person + title
          Align(
            alignment: const Alignment(0, -0.35),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.verified_user_rounded, size: 64, color: Color(0xFF1D4B8B)),
                SizedBox(height: 8),
                Text(
                  'YOUR MATCH IS',
                  style: TextStyle(
                    color: Color(0xFF1D4B8B),
                    fontSize: 26,
                    fontFamily: 'Luckiest Guy',
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),

          // Profile card
          Align(
            alignment: const Alignment(0, -0.05),
            child: _MatchCard(match: match),
          ),

          // “Their top hobbies”
          Align(
            alignment: const Alignment(0, 0.25),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: const [
                  Icon(Icons.star_rounded, color: Color(0xFFFFC107)),
                  SizedBox(width: 8),
                  Text(
                    'Their top hobbies',
                    style: TextStyle(
                      color: Color(0xFF1F2937),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Hobby tiles
          Align(
            alignment: const Alignment(0, 0.52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: LayoutBuilder(
                builder: (_, c) {
                  final tileW = (c.maxWidth - 32) / 3; // spacing 16*2
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: match.hobbies.map((h) {
                      return _HobbyTile(hobby: h, width: tileW);
                    }).toList(),
                  );
                },
              ),
            ),
          ),

          // Linkup CTA
          Align(
            alignment: const Alignment(0, 0.85),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GestureDetector(
                onTap: onLinkup,
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0760D5), Color(0xFF07A8D5), Color(0xFF0760D5)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 6)),
                    ],
                  ),
                  child: const Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Linkup',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_right_alt_rounded, color: Colors.white, size: 28),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.only(left: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.20),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final _ProxyMatch match;
  const _MatchCard({required this.match});

  @override
  Widget build(BuildContext context) {
    return Container(
  constraints: const BoxConstraints(maxWidth: 560),
  height: 85, // 👈 fixed smaller rectangle height
  margin: const EdgeInsets.symmetric(horizontal: 20),
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  decoration: BoxDecoration(
    color: const Color(0xFFF4F5FF),
    borderRadius: BorderRadius.circular(12),
    boxShadow: const [
      BoxShadow(color: Color(0x19000000), blurRadius: 6, offset: Offset(0, 2)),
    ],
  ),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.center, // keep everything aligned
    children: [
      Stack(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF6366F1), width: 2),
              image: DecorationImage(image: NetworkImage(match.photoUrl), fit: BoxFit.cover),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              match.name,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
            Text(
              match.handle,
              style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.place, size: 13, color: Color(0xFF6366F1)),
                const SizedBox(width: 4),
                Text(match.location,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B))),
                const Spacer(),
                Text(match.time,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
              ],
            ),
          ],
        ),
      ),
      const Icon(Icons.more_vert, color: Color(0xFF94A3B8), size: 20),
    ],
  ),
);
  }
}

class _HobbyTile extends StatelessWidget {
  final _Hobby hobby;
  final double width;
  const _HobbyTile({required this.hobby, required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: width, // square tile; scales with screen
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: hobby.gradient),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x19000000), blurRadius: 10, offset: Offset(0, 6)),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(hobby.icon, color: Colors.white, size: 26),
            const SizedBox(height: 8),
            Text(
              hobby.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ─────────────────────────────────────────────
 * PAGE 3: REQUEST SENT (Return to Map)
 * ──────────────────────────────────────────── */
class _RequestSentPage extends StatelessWidget {
  final VoidCallback onReturnHome;
  const _RequestSentPage({required this.onReturnHome});

  @override
  Widget build(BuildContext context) {
    final padTop = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFAF5FF), Color(0xFFFDF2F8), Color(0xFFFFF7ED)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x3F000000),
                    blurRadius: 50,
                    offset: Offset(0, 25),
                  ),
                ],
              ),
            ),
          ),
          // header
          Positioned(
            top: 0,
            left: 3,
            right: 3,
            child: Container(
              height: 72 + padTop,
              padding: EdgeInsets.only(top: padTop),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF065BD4), Color(0xFF07A8D5), Color(0xFF0842D6)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: const Center(
                child: Text(
                  'LinkUp Vibe',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ),
          ),

          // avatar + text
          const Align(
            alignment: Alignment(0, -0.1),
            child: CircleAvatar(
              radius: 64,
              backgroundImage: NetworkImage('https://placehold.co/128'),
              backgroundColor: Colors.white,
            ),
          ),
          const Align(
            alignment: Alignment(0, 0.16),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'linkup request sent\npending',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF1D4B8B),
                  fontSize: 24,
                  fontFamily: 'Luckiest Guy',
                  height: 1.15,
                ),
              ),
            ),
          ),

          // return button
          Align(
            alignment: const Alignment(0, 0.75),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GestureDetector(
                onTap: onReturnHome,
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0760D5), Color(0xFF07A8D5), Color(0xFF0760D5)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 6)),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'Return to home',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
