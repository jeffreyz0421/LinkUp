import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'cas.dart';

enum LinkType { hosting, invitation, attending }

class LinkItem {
  final String functionID;
  final String name;
  final String host;
  final String vibe;
  final String imageUrl;
  final LinkType type;

  LinkItem({
    required this.functionID,
    required this.name,
    required this.host,
    required this.vibe,
    required this.imageUrl,
    required this.type,
  });
}

class LinksScreen extends StatefulWidget {
  const LinksScreen({super.key});

  @override
  State<LinksScreen> createState() => _LinksScreenState();
}

class _LinksScreenState extends State<LinksScreen> {
  final List<LinkItem> _links = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDummyData();
  }

  void _loadDummyData() {
    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() {
        _links.addAll([
          LinkItem(
            functionID: 'FUNC001',
            name: 'Sunset Picnic',
            host: 'Alice',
            vibe: 'Chill vibes at the park',
            imageUrl: 'https://images.unsplash.com/photo-1528605248644-14dd04022da1',
            type: LinkType.hosting,
          ),
          LinkItem(
            functionID: 'FUNC004',
            name: 'Bonfire & Party at the Beach',
            host: 'Jay',
            vibe: 'Good music, better vibes 🔥',
            imageUrl: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e',
            type: LinkType.invitation,
          ),
          LinkItem(
            functionID: 'FUNC003',
            name: 'Beach Volleyball',
            host: 'Charlie',
            vibe: 'Competitive but fun!',
            imageUrl: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e',
            type: LinkType.attending,
          ),
        ]);
        _loading = false;
      });
    });
  }

  void _acceptInvitation(LinkItem item) {
    setState(() {
      final idx = _links.indexOf(item);
      if (idx != -1) {
        _links[idx] = LinkItem(
          functionID: item.functionID,
          name: item.name,
          host: item.host,
          vibe: item.vibe,
          imageUrl: item.imageUrl,
          type: LinkType.attending,
        );
      }
    });
  }

  void _declineInvitation(LinkItem item) {
    setState(() => _links.remove(item));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFB3FFFF), Color(0xFFBABAF2)]),
        ),
        child: Stack(alignment: Alignment.bottomCenter, children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back,
                            size: 30, color: Color(0xFF4B5563)),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      const Text('Links',
                          style: TextStyle(
                              fontSize: 26, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _links.isEmpty
                            ? const Center(child: Text('No links found.'))
                            : ListView.builder(
                                padding: const EdgeInsets.only(bottom: 88),
                                itemCount: _links.length,
                                itemBuilder: (context, i) => _buildLinkCard(_links[i]),
                              ),
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

  Widget _buildLinkCard(LinkItem item) {
    final Color cardColor;
    switch (item.type) {
      case LinkType.hosting:
        cardColor = Colors.lightBlue.shade50;
        break;
      case LinkType.invitation:
        cardColor = Colors.yellow.shade50;
        break;
      case LinkType.attending:
        cardColor = Colors.green.shade50;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
            child: Image.network(
              item.imageUrl,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 160,
                color: Colors.grey.shade300,
                child: const Icon(Icons.broken_image, size: 48),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(item.name,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(20)),
                      child: const Text('PULLUP',
                          style: TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('ID: ${item.functionID}'),
                Text('Host: ${item.host}'),
                Text('Vibe: ${item.vibe}'),
                Text(
                  item.type == LinkType.hosting
                      ? 'You are the host'
                      : item.type == LinkType.invitation
                          ? 'You are invited'
                          : 'You are attending',
                  style: const TextStyle(
                      fontStyle: FontStyle.italic, color: Colors.grey),
                ),
                if (item.type == LinkType.invitation) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _acceptInvitation(item),
                        icon: const Icon(Icons.check),
                        label: const Text('Accept'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20))),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => _declineInvitation(item),
                        icon: const Icon(Icons.close),
                        label: const Text('Decline'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20))),
                      ),
                    ],
                  ),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomNav(BuildContext ctx) => Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: 88,
          width: double.infinity,
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).padding.bottom),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, -4))
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(Icons.people_alt, 'Friends', onTap: () {}),
              _navItem(Icons.home_rounded, 'Comunity', onTap: () {}),
              const SizedBox(width: 64),
              _navItem(Icons.link_outlined, 'Links', isActive: true, onTap: () {}),
              _navItem(Icons.person_outline, 'Profile', onTap: () => Navigator.pop(ctx)),
            ],
          ),
        ),
      );

  Widget _navItem(IconData icon, String label,
          {required VoidCallback onTap, bool isActive = false}) =>
      InkWell(
        onTap: onTap,
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
                child: Icon(icon, size: 18,
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

  Widget _fabPlus(BuildContext ctx) => Positioned(
        bottom: 88 - (64 / 2) - 6,
        child: GestureDetector(
          onTap: () => Navigator.of(ctx)
              .push(MaterialPageRoute(builder: (_) => const CASScreen())),
          child: Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: Colors.deepPurpleAccent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black26,
                    blurRadius: 10, offset: Offset(0, 4)),
              ],
            ),
            child:
                const Center(child: Icon(Icons.add, color: Colors.white, size: 32)),
          ),
        ),
      );
}
