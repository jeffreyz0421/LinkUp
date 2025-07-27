// lib/links_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'cas.dart';

enum LinkType { hosting, invitation, attending }

class LinkItem {
  final String functionID;
  final String name;
  final String host;
  final String vibe;
  final String imageUrl;
  final LinkType type;
  final String category;

  LinkItem({
    required this.functionID,
    required this.name,
    required this.host,
    required this.vibe,
    required this.imageUrl,
    required this.type,
    required this.category,
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
    _fetchLinks();
  }

  Future<void> _fetchLinks() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';
    final meId  = prefs.getString('user_id');

    final uri = Uri.parse('${Config.serverBaseUrl}/user/meetups');
    try {
      final resp = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type':  'application/json',
        },
      );

      // backend returns 302 Found, so accept both 200 & 302:
      if (resp.statusCode == 200 || resp.statusCode == 302) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final funcs = (body['functions'] as List<dynamic>).cast<Map<String, dynamic>>();

        setState(() {
          _links.clear();
          for (var f in funcs) {
            // determine hosting / invitation / attending:
            LinkType type;
            if (meId != null && f['host'] == meId) {
              type = LinkType.hosting;
            } else if ((f['invite_status'] as String?)?.toLowerCase() == 'pending') {
              type = LinkType.invitation;
            } else {
              type = LinkType.attending;
            }

            // category based on function_type field, e.g. "meetup"
            final ft = (f['function_type'] as String?) ?? '';
            final category = ft.isNotEmpty
                ? ft[0].toUpperCase() + ft.substring(1)
                : 'Meetup';

            _links.add(LinkItem(
              functionID: f['function_id'] as String,
              name:       f['name']        as String,
              host:       f['host']        as String,
              vibe:       f['vibe']        as String,
              imageUrl:   '', // TODO: wire in your place‑details photo later
              type:       type,
              category:   category,
            ));
          }
        });
      } else {
        debugPrint('Failed to load links: ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching meetups: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _acceptInvitation(LinkItem item) {
    setState(() {
      final idx = _links.indexOf(item);
      if (idx != -1) {
        _links[idx] = LinkItem(
          functionID: item.functionID,
          name:       item.name,
          host:       item.host,
          vibe:       item.vibe,
          imageUrl:   item.imageUrl,
          type:       LinkType.attending,
          category:   item.category,
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
            end:   Alignment.bottomRight,
            colors:[Color(0xFFB3FFFF), Color(0xFFBABAF2)],
          ),
        ),
        child: Stack(alignment: Alignment.bottomCenter, children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          size: 30, color: Color(0xFF4B5563)),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    const Text('Links',
                        style: TextStyle(
                            fontSize: 26, fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _links.isEmpty
                            ? const Center(child: Text('No links found.'))
                            : ListView.builder(
                                padding: const EdgeInsets.only(bottom: 88),
                                itemCount: _links.length,
                                itemBuilder: (ctx, i) => _buildLinkCard(_links[i]),
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
    Color cardColor;
    switch (item.type) {
      case LinkType.hosting:    cardColor = Colors.lightBlue.shade50; break;
      case LinkType.invitation: cardColor = Colors.yellow.shade50;    break;
      case LinkType.attending:  cardColor = Colors.green.shade50;     break;
    }

    String categoryLabel = '';
    Color  categoryColor = Colors.redAccent;
    if (item.category.toLowerCase() == 'pullup') {
      categoryLabel = '🔥 PullUp';
      categoryColor = const Color(0xFFE18585);
    } else if (item.category.toLowerCase() == 'meetup') {
      categoryLabel = '🧺 MeetUp';
      categoryColor = const Color(0xFF83BB5C);
    } else if (item.category.toLowerCase() == 'linkup') {
      categoryLabel = '🤝 LinkUp';
      categoryColor = const Color(0xFF64ABE5);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color:  cardColor,
      shape:  RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: item.imageUrl.isNotEmpty
                ? Image.network(item.imageUrl,
                    height: 160, width: double.infinity, fit: BoxFit.cover)
                : Container(
                    height: 160,
                    color: Colors.grey.shade300,
                    child: const Center(
                      child: Icon(Icons.image_not_supported, size: 48),
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
                          color: categoryColor,
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(categoryLabel,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12)),
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
                      fontStyle: FontStyle.italic,
                      color: Color.fromARGB(255, 75, 145, 108)),
                ),
                if (item.type == LinkType.invitation) ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    ElevatedButton.icon(
                      onPressed: () => _acceptInvitation(item),
                      icon: const Icon(Icons.check),
                      label: const Text('Accept'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color.fromARGB(255, 127, 203, 130),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20))),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _declineInvitation(item),
                      icon: const Icon(Icons.close),
                      label: const Text('Decline'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color.fromARGB(255, 232, 90, 80),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20))),
                    ),
                  ]),
                ],
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
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).padding.bottom),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, -4))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(Icons.people_alt,  'Friends',   onTap: () {}),
              _navItem(Icons.home_rounded, 'Comunity', onTap: () {}),
              const SizedBox(width: 64),
              _navItem(Icons.link_outlined, 'Links', isActive: true,  onTap: () {}),
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
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: isActive
                  ? BoxDecoration(
                      border: Border.all(color: Colors.purple, width: 2),
                      borderRadius: BorderRadius.circular(6))
                  : null,
              child: Icon(icon,
                  size: 18, color: isActive ? Colors.purple : const Color(0xFF4B5563)),
            ),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isActive ? Colors.purple : Colors.grey.shade800)),
          ]),
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
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
            ),
            child: const Center(child: Icon(Icons.add, color: Colors.white, size: 32)),
          ),
        ),
      );
}
