// lib/meetup_invite_page.dart

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;

import 'MeetupConfirmPage.dart';

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

  String _searchQuery = '';
  final _searchCtl = TextEditingController();

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  void _toggle(String name) {
    setState(() {
      if (_selected.contains(name))
        _selected.remove(name);
      else
        _selected.add(name);
    });
  }

  List<String> get _filteredFriends {
    if (_searchQuery.isEmpty) return _friends;
    return _friends
        .where((f) => f.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  List<String> get _filteredSuggested {
    if (_searchQuery.isEmpty) return _suggested;
    return _suggested
        .where((s) => s.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          fontFamily: 'Poppins',
          color: Color(0xFF1C1B1F),
        ),
      ),
    );
  }

  Widget _buildPersonRow(String name, String subtitle) {
    final selected = _selected.contains(name);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              image: const DecorationImage(
                image: AssetImage('assets/default_pfp.png'),
                fit: BoxFit.cover,
              ),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
          ),
          const SizedBox(width: 12),
          // name + subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Poppins',
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'Poppins',
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          // add/remove pill
          GestureDetector(
            onTap: () => _toggle(name),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF6366F1).withOpacity(0.1)
                    : const Color(0x196366F1),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color:
                      selected ? const Color(0xFF6366F1) : Colors.transparent,
                  width: selected ? 1.5 : 0,
                ),
              ),
              child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 16, color: Color(0xFF6366F1)),
                    const SizedBox(width: 4),
                    Text(
                      selected ? 'Added' : 'Add',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Poppins',
                        color: Color(0xFF6366F1),
                      ),
                    ),
                  ],
                ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ─── TOP BAR ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // round orange back button
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF16365),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // search pill
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color(0xFFF1F2F5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TextField(
                        controller: _searchCtl,
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: InputDecoration(
                          hintText: 'Find friends',
                          hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          suffixIcon: Padding(
                            padding: const EdgeInsets.only(right: 12.0),
                            child: Icon(Icons.search, color: Color(0xFF6B7280)),
                          ),
                          suffixIconConstraints: BoxConstraints(minWidth: 24, minHeight: 24),
                        ),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ─── INVITE LISTS ─────────────────────────────────
            Expanded(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('Invite Friends'),
                      ..._filteredFriends
                          .map((f) => _buildPersonRow(f, widget.vibe)),
                      _buildSectionHeader('Suggested'),
                      ..._filteredSuggested
                          .map((s) => _buildPersonRow(s, 'Nearby')),
                    ],
                  ),
                ),
              ),
            ),

            // ─── CONFIRM BUTTON ───────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MeetupConfirmPage(
                                vibe: widget.vibe,
                                locationName: widget.locationName,
                                coordinates: widget.locationCoordinates,
                                invited: _selected.toList(),
                              ),
                            ),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    disabledBackgroundColor: Colors.grey.shade300,
                    disabledForegroundColor: Colors.white70,
                  ),
                  child: Ink(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFFF16365),
                          Color(0xFFEC4899),
                          Color(0xFFF5600B)
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                    child: Center(
                      child: Text(
                        'Confirm Invitations',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Poppins',
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // safe‐area bottom
            SizedBox(height: MediaQuery.of(context).viewPadding.bottom),
          ],
        ),
      ),
    );
  }
}

