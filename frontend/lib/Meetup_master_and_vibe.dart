// lib/meetup.dart

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:http/http.dart' as http;

import 'session_manager.dart';
import 'services/profile_service.dart';
import 'main_screen_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cas.dart';
import 'main_screen_logic.dart'; // brings in styleUri
import 'MeetupLocationPage.dart'; // Ensure this file defines MeetupLocationPage

/// Entry point for the 4‑step Meetup wizard
class MeetupFlow extends StatelessWidget {
  const MeetupFlow({super.key});
  @override
  Widget build(BuildContext context) => const MeetupVibePage();
}

/// STEP 1/4: Select VIBE
/// /// STEP 1/4: Select VIBE
/// /// STEP 1/4: Select VIBE
class MeetupVibePage extends StatefulWidget {
  const MeetupVibePage({super.key});
  @override
  State<MeetupVibePage> createState() => _MeetupVibePageState();
}

class _MeetupVibePageState extends State<MeetupVibePage> {
  final List<String> _allVibes = [
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
    'Photography',
    'Gaming',
    'Coffee Chat',
    'Art',
    'Food',
    'Movies',
    'Fitness',
    'Reading',
    'Swimming',
    'Dancing',
    'Study',
    'Yoga',
    'Travel',
    'Karaoke',
    'Tech',
  ];

  List<String> _hobbies = [];
  String? _selectedVibe;
  final _searchCtl = TextEditingController();
  String? _hobbiesError;
  bool _loadingHobbies = true;

  List<String> get _filteredAllVibes {
    final q = _searchCtl.text.toLowerCase();
    final filtered = q.isEmpty
        ? List<String>.from(_allVibes)
        : _allVibes.where((v) => v.toLowerCase().contains(q)).toList();
    final ql = _searchCtl.text.toLowerCase();
    filtered.sort((a, b) {
      if (a.toLowerCase() == ql) return -1;
      if (b.toLowerCase() == ql) return 1;
      return 0;
    });
    return filtered;
  }

  List<String> get _filteredTopVibes {
    final q = _searchCtl.text.toLowerCase();
    final top = _hobbies.where((v) => _allVibes.contains(v)).toList();
    if (q.isEmpty) return top;
    return top.where((v) => v.toLowerCase().contains(q)).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadHobbies();
  }

  Future<void> _loadHobbies() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final service = ProfileService(http.Client());
      final fetched = await service.getHobbies();
      if (fetched.isNotEmpty) {
        _hobbies = fetched;
        await prefs.setStringList('hobbies', _hobbies);
      } else {
        _hobbies = ['Coding', 'Music', 'Photography'];
        await prefs.setStringList('hobbies', _hobbies);
      }
    } catch (e) {
      _hobbies = prefs.getStringList('hobbies') ?? ['Coding', 'Music', 'Photography'];
      _hobbiesError = 'Could not load fresh hobbies; showing cached/default ones.';
    } finally {
      if (mounted) setState(() => _loadingHobbies = false);
    }
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  LinearGradient gradientForVibe(String vibe) {
    switch (vibe.toLowerCase()) {
      case 'gaming':
        return const LinearGradient(colors: [Color(0xFFFA517F), Color(0xFFF16365)]);
      case 'basketball':
        return const LinearGradient(colors: [Color(0xFFEA8E33), Color(0xFFF63B3E)]);
      case 'coffee chat':
        return const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFEA580C)]);
      default:
        return const LinearGradient(
          colors: [Color(0xFFF16365), Color(0xFFEC4899), Color(0xFFF5600B)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        );
    }
  }

  IconData iconForVibe(String vibe) {
    final lower = vibe.toLowerCase();
    if (lower.contains('game')) return Icons.videogame_asset;
    if (lower.contains('basket')) return Icons.sports_basketball;
    if (lower.contains('coffee') || lower.contains('chat')) return Icons.local_cafe;
    if (lower.contains('music')) return Icons.music_note;
    if (lower.contains('hiking')) return Icons.terrain;
    if (lower.contains('book')) return Icons.book;
    if (lower.contains('photo')) return Icons.photo_camera;
    if (lower.contains('dance')) return Icons.directions_run;
    if (lower.contains('fitness')) return Icons.fitness_center;
    if (lower.contains('movie')) return Icons.movie;
    if (lower.contains('yoga')) return Icons.self_improvement;
    if (lower.contains('travel')) return Icons.flight;
    if (lower.contains('tech')) return Icons.memory;
    return Icons.star;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // no AppBar to use custom header
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // gradient header
                Container(
                  height: 72,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFF16365), Color(0xFFEC4899), Color(0xFFF5490B)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        left: 12,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      const Center(
                        child: Text(
                          'MeetUp Vibe',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // search bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF6FF),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x22000000),
                          blurRadius: 15,
                          offset: Offset(0, 10),
                        ),
                        BoxShadow(
                          color: Color(0x11000000),
                          blurRadius: 6,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchCtl,
                      onChanged: (_) => setState(() {}),
                      textAlignVertical: TextAlignVertical.center,
                      decoration: InputDecoration(
                        hintText: 'What vibe are you looking for?',
                        hintStyle: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF5D61A1),
                        ),
                        border: InputBorder.none,
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF5D61A1)),
                        prefixIconConstraints:
                            const BoxConstraints(minWidth: 48, minHeight: 48),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      ),
                      style: const TextStyle(color: Colors.black87),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 140),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Vibes Based on Your Hobbies
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Top Vibes Based on Your Hobbies',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (_hobbiesError != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF0D9),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.orangeAccent),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _hobbiesError!,
                                      style: const TextStyle(color: Colors.black87, fontSize: 12),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _hobbiesError = null;
                                      });
                                    },
                                    child: const Icon(Icons.close, size: 18, color: Colors.black54),
                                  )
                                ],
                              ),
                            ),
                          ),

                        const SizedBox(height: 8),

                        SizedBox(
                          height: 112,
                          child: _loadingHobbies
                              ? const Center(child: CircularProgressIndicator())
                              : ListView.separated(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _filteredTopVibes.length,
                                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                                  itemBuilder: (ctx, idx) {
                                    final vibe = _filteredTopVibes[idx];
                                    final selected = _selectedVibe == vibe;
                                    return GestureDetector(
                                      onTap: () => setState(() {
                                        _selectedVibe = vibe;
                                      }),
                                      child: Container(
                                        width: 100,
                                        decoration: BoxDecoration(
                                          gradient: selected ? gradientForVibe(vibe) : null,
                                          color: selected ? null : Colors.white,
                                          borderRadius: BorderRadius.circular(16),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Color(0x22000000),
                                              blurRadius: 15,
                                              offset: Offset(0, 10),
                                            ),
                                            BoxShadow(
                                              color: Color(0x11000000),
                                              blurRadius: 6,
                                              offset: Offset(0, 4),
                                            ),
                                          ],
                                          border: selected
                                              ? null
                                              : Border.all(color: const Color(0xFFE5E7EB), width: 1),
                                        ),
                                        padding: const EdgeInsets.all(8),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              iconForVibe(vibe),
                                              size: 28,
                                              color: selected ? Colors.white : Colors.deepPurple,
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              vibe,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: selected ? Colors.white : Colors.black87,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),

                        const SizedBox(height: 24),

                        // Discover More Vibes
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: '# ',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purple.shade700,
                                  ),
                                ),
                                const TextSpan(
                                  text: 'Discover More Vibes',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: _filteredAllVibes
                                .where((v) => !_hobbies.contains(v))
                                .map((v) {
                              final selected = _selectedVibe == v;
                              return GestureDetector(
                                onTap: () => setState(() {
                                  _selectedVibe = v;
                                }),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    gradient: selected ? gradientForVibe(v) : null,
                                    color: selected ? null : Colors.white,
                                    borderRadius: BorderRadius.circular(999),
                                    boxShadow: const [
                                      BoxShadow(
                                          color: Color(0x22000000),
                                          blurRadius: 8,
                                          offset: Offset(0, 4)),
                                    ],
                                    border: selected
                                        ? null
                                        : Border.all(color: const Color(0xFFE5E7EB), width: 1),
                                  ),
                                  child: Text(
                                    '# $v',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: selected ? Colors.white : const Color(0xFF6B4F5F),
                                      shadows: selected
                                          ? null
                                          : const [
                                              Shadow(
                                                  color: Color(0x22000000),
                                                  offset: Offset(0, 1),
                                                  blurRadius: 2)
                                            ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                        const SizedBox(height: 160), // extra padding so last content isn't hidden
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // floating continue button
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: SizedBox(
                height: 70,
                child: GestureDetector(
                  onTap: _selectedVibe == null
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MeetupLocationPage(
                                vibe: _selectedVibe!,
                              ),
                            ),
                          );
                        },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: _selectedVibe != null
                          ? const LinearGradient(
                              colors: [
                                Color(0xFFF16365),
                                Color(0xFFEC4899),
                                Color(0xFFF5600B)
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            )
                          : null,
                      color: _selectedVibe == null ? Colors.grey.shade300 : null,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        'Continue to Next Step →',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: _selectedVibe == null ? Colors.black38 : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
