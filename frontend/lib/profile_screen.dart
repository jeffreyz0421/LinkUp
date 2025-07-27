// ███  profile_screen.dart  ███
//
// High‑fidelity profile page.
//
// ╭───────────────────────────── FEATURES ─────────────────────────────╮
// │ • Gradient / blur background identical to MapScreen               │
// │ • Bottom nav‑bar clone (Profile tab highlighted)                  │
// │ • Centered purple “+” -> CASScreen                                │
// │ • Circle avatar with camera / gallery picker + permission checks  │
// │ • Hobby chips: add • drag‑reorder • remove                        │
// │ • Tags persisted via REST (GET / PUT) using ProfileService        │
// ╰────────────────────────────────────────────────────────────────────╯
//
// External deps used here:
//
//   image_picker            – pick profile photo
//   permission_handler      – runtime camera / gallery perms
//   shared_preferences       – cache basic user fields locally
//   http                     – raw client used by ProfileService
//   services/profile_service.dart         (REST helpers)
//   session_manager.dart                 (current JWT & user‑id)
//
// Make sure you created/updated those two helper files exactly as in
// the previous answer (they expose ProfileService.{getHobbies,setHobbies}
// and SessionManager.instance.{jwt,userId}).
// ███  profile_screen.dart  ███
//
// Pixel‑perfect profile page kept in sync with the backend.
//
// ──────────────────────────────────────────────────────────
// • Matches MapScreen’s gradient + bottom‑nav.
// • Circle avatar with camera / gallery picker + perm checks.
// • Hobby chips (add ▸ drag‑reorder ▸ delete) persisted via REST.
// • Purple “+” opens CASScreen.
// • Works in two modes:
//     – Logged‑in user  → hobbies pulled/pushed to server.
//     – Guest           → everything runs locally, nothing persisted.
//
// External helper files (see previous replies):
//   • services/profile_service.dart      (REST wrapper)
//   • session_manager.dart               (jwt & user‑id, nullable)
//   • config.dart                        (serverBaseUrl)
//   • cas.dart                           (destination for the FAB)
//
// lib/profile_screen.dart

import 'dart:io';
import 'dart:ui' show ImageFilter;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'cas.dart';
import 'config.dart';
import 'session_manager.dart';

/// Simple REST wrapper for GET/PUT /api/users/{userId}/hobbies
class ProfileService {
  final http.Client _client;
  ProfileService(this._client);

  Future<List<String>> getHobbies(String userId) async {
    final token = await SessionManager.instance.jwt;
    final resp = await _client.get(
      Uri.parse('${Config.serverBaseUrl}/users/$userId/hobbies'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (resp.statusCode == 200) {
      final body = Map<String, dynamic>.from(jsonDecode(resp.body));
      return List<String>.from(body['hobbies'] as List);
    }
    throw Exception('Failed to load hobbies (${resp.statusCode})');
  }

  Future<void> setHobbies(String userId, List<String> hobbies) async {
    final token = await SessionManager.instance.jwt;
    final resp = await _client.put(
      Uri.parse('${Config.serverBaseUrl}/users/$userId/hobbies'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'hobbies': hobbies}),
    );
    if (resp.statusCode != 202 && resp.statusCode != 200) {
      throw Exception('Failed to save hobbies (${resp.statusCode})');
    }
  }
}

class TagData {
  final String id, text;
  TagData({required this.id, required this.text});
  @override bool operator ==(Object o) => o is TagData && o.id == id;
  @override int get hashCode => id.hashCode;
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

const double _navBarHeight = 72;
const double _centerFabSize = 64;

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  File? _pfp;
  String? _name = 'Your Name', _username = '', _email = '', _phone = '';

  final List<TagData> _tags = [];
  bool _showAddInput = false;
  final _tagCtl = TextEditingController();
  final _tagFocus = FocusNode();
  final _tagScroll = ScrollController();

  bool _loading = true, _syncing = false;
  final _api = ProfileService(http.Client());
  String? _userId;
  bool get _isGuest => _userId == null || _userId!.isEmpty;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _tagCtl.dispose();
    _tagFocus.dispose();
    _tagScroll.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      _userId = await SessionManager.instance.userId;
      final prefs = await SharedPreferences.getInstance();
      _name = prefs.getString('name') ?? _name;
      _username = prefs.getString('username') ?? '';
      _email = prefs.getString('email') ?? '';
      _phone = prefs.getString('phone_number') ?? '';
      if (!_isGuest) {
        final raw = await _api.getHobbies(_userId!);
        _tags.addAll(raw.map((h) => TagData(id: h, text: h)));
      }
    } catch (e) {
      debugPrint('Profile bootstrap error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _syncTags() async {
    if (_isGuest) return;
    setState(() => _syncing = true);
    try {
      await _api.setHobbies(_userId!, _tags.map((t) => t.text).toList());
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to sync – $e')));
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  void _addTag() {
    final t = _tagCtl.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _tags.add(TagData(id: DateTime.now().toIso8601String(), text: t));
      _showAddInput = false;
      _tagCtl.clear();
    });
    _syncTags();
    Future.microtask(() => _tagScroll.jumpTo(_tagScroll.position.maxScrollExtent));
  }

  void _removeTag(String id) {
    setState(() => _tags.removeWhere((e) => e.id == id));
    _syncTags();
  }

  void _reorderTags(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) newIndex--;
      final t = _tags.removeAt(oldIndex);
      _tags.insert(newIndex, t);
    });
    _syncTags();
  }

  Future<void> _pickImage(ImageSource src) async {
    final perm = src == ImageSource.camera ? Permission.camera : Permission.photos;
    if (!(await perm.request()).isGranted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Permission needed'),
          content: const Text('Enable access to change photo.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(onPressed: () => openAppSettings(), child: const Text('Settings')),
          ],
        ),
      );
      return;
    }
    final x = await ImagePicker().pickImage(source: src, imageQuality: 85, maxWidth: 800);
    if (x != null && mounted) setState(() => _pfp = File(x.path));
    // TODO: upload to your avatar endpoint
  }

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
          _blur(-134, -58, 582, const Color(0xFF60A5FA), 184),
          _blur(27, 419, 934, const Color(0xFFD8B4FE), 295),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 384),
                child: Column(
                  children: [
                    _header(),
                    _profileInfo(),
                    Expanded(child: _tagSection()),
                  ],
                ),
              ),
            ),
          ),
          _bottomNav(),
          _fabPlus(),
        ]),
      ),
    );
  }

  Widget _blur(double l, double t, double s, Color c, double sigma) =>
      Positioned(
        left: l, top: t,
        child: Container(
          width: s, height: s,
          decoration: BoxDecoration(color: c.withOpacity(.8), shape: BoxShape.circle),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: const SizedBox(),
          ),
        ),
      );

  Widget _header() => Padding(
        padding: const EdgeInsets.all(8),
        child: Row(children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 30, color: Color(0xFF4B5563)),
            onPressed: () => Navigator.pop(context),
          ),
        ]),
      );

  Widget _profileInfo() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(children: [
          Stack(children: [
            CircleAvatar(
              radius: 83,
              backgroundColor: const Color(0xFFE8DCEF),
              backgroundImage: _pfp != null ? FileImage(_pfp!) : null,
              child: _pfp == null
                  ? const Icon(Icons.person, size: 64, color: Color(0xFF5E2BC5))
                  : null,
            ),
            Positioned(right: 8, bottom: 8, child: _camBtn()),
          ]),
          const SizedBox(height: 16),
          Text(_name ?? 'Your name',
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text('@$_username', style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          Text(_email ?? '', style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          Text(_phone ?? '', style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
        ]),
      );

  Widget _camBtn() => Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: Colors.white, shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.1), blurRadius: 8, offset: const Offset(0,4))],
        ),
        child: IconButton(
          icon: const Icon(Icons.camera_alt, size: 20, color: Color(0xFF4B5563)),
          padding: EdgeInsets.zero,
          onPressed: () => _showPickSheet(),
        ),
      );

  void _showPickSheet() => showModalBottomSheet(
        context: context,
        builder: (_) => SafeArea(
          child: Wrap(children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
          ]),
        ),
      );

  Widget _tagSection() => Padding(
        padding: EdgeInsets.only(left: 16, right: 16, bottom: _navBarHeight + 12),
        child: Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(5)),
          constraints: const BoxConstraints(maxHeight: 332),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Expanded(
                child: Stack(children: [
                  SingleChildScrollView(
                    controller: _tagScroll,
                    child: Wrap(
                      spacing: 12, runSpacing: 12,
                      children: [
                        for (int i = 0; i < _tags.length; i++)
                          _draggableChip(_tags[i], i),
                        _showAddInput ? _inputChip() : _addChipBtn(),
                      ],
                    ),
                  ),
                  if (_syncing)
                    const Positioned(top: 0, right: 0, child: SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2),
                    )),
                ]),
              ),
              if (_tags.length > 2)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Text('Drag to reorder • Tap red × to delete',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
                ),
            ]),
          ),
        ),
      );

  Widget _draggableChip(TagData t, int i) => LongPressDraggable<TagData>(
        data: t,
        feedback: _chip(t.text, elevated: true),
        childWhenDragging: Opacity(opacity: .35, child: _chip(t.text)),
        child: DragTarget<TagData>(
          onWillAccept: (d) => d != null && d != t,
          onAccept: (d) => _reorderTags(_tags.indexOf(d), i),
          builder: (_, __, ___) => _chip(t.text, onRemove: () => _removeTag(t.id)),
        ),
      );

  Widget _chip(String txt, {VoidCallback? onRemove, bool elevated = false}) => Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            elevation: elevated ? 8 : 0,
            borderRadius: BorderRadius.circular(5),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFF7C91ED), borderRadius: BorderRadius.circular(5)),
              child: Text(txt, style: const TextStyle(color: Colors.white, fontSize: 18)),
            ),
          ),
          if (onRemove != null)
            Positioned(
              right: -8, top: -8,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 20, height: 20,
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  child: const Icon(Icons.close, size: 12, color: Colors.white),
                ),
              ),
            ),
        ],
      );

  Widget _addChipBtn() => GestureDetector(
        onTap: () {
          setState(() => _showAddInput = true);
          Future.delayed(const Duration(milliseconds: 90), () => _tagFocus.requestFocus());
        },
        child: const Icon(Icons.add, size: 24),
      );

  Widget _inputChip() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(color: const Color(0xFF7C91ED), borderRadius: BorderRadius.circular(5)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 80, maxWidth: 120),
            child: TextField(
              controller: _tagCtl,
              focusNode: _tagFocus,
              maxLength: 20,
              buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
              style: const TextStyle(color: Colors.white, fontSize: 18),
              decoration: const InputDecoration(
                hintText: 'Enter tag',
                hintStyle: TextStyle(color: Colors.white70),
                border: InputBorder.none,
                isDense: true,
              ),
              onSubmitted: (_) => _addTag(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(onTap: _addTag, child: const Icon(Icons.add, size: 16, color: Colors.white)),
          const SizedBox(width: 4),
          GestureDetector(onTap: () {
            setState(() => _showAddInput = false);
            _tagCtl.clear();
          }, child: const Icon(Icons.close, size: 16, color: Colors.white)),
        ]),
      );

  Widget _bottomNav() => Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: _navBarHeight,
          width: double.infinity,
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, -4))],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _navItem(Icons.people_alt, 'Friends', onTap: () {}),
            _navItem(Icons.home_rounded, 'Community', onTap: () {}),
            const SizedBox(width: _centerFabSize),
            _navItem(Icons.link_outlined, 'Links', onTap: () {}),
            _navItem(Icons.person_outline, 'Profile', isActive: true, onTap: () {}),
          ]),
        ),
      );

  Widget _navItem(IconData ic, String lbl, {bool isActive = false, required VoidCallback onTap}) =>
      InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 64,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: isActive
                  ? BoxDecoration(border: Border.all(color: Colors.purple, width: 2), borderRadius: BorderRadius.circular(6))
                  : null,
              child: Icon(ic, size: 21, color: isActive ? Colors.purple : const Color(0xFF4B5563)),
            ),
            const SizedBox(height: 4),
            Text(lbl, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isActive ? Colors.purple : Colors.black)),
          ]),
        ),
      );

  Widget _fabPlus() => Positioned(
        bottom: _navBarHeight - (_centerFabSize / 2) - 6,
        left: 0,
        right: 0,
        child: Center(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CASScreen()));
            },
            child: Container(
              width: _centerFabSize,
              height: _centerFabSize,
              decoration: const BoxDecoration(
                color: Colors.deepPurpleAccent,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
              ),
              child: const Center(child: Icon(Icons.add, color: Colors.white, size: 32)),
            ),
          ),
        ),
      );
}


//Quick test
//1. Log in → call SessionManager().update(...) with the token & userID.
//2. Open Profile; the chips load from /api/users/{id}/hobbies.
//3. Add, reorder, or delete chips — the list is immediately PUT back.

//That’s it — your hobbies are now part of the persisted user profile and stay
//up‑to‑date with one tidy service class and a few lines in ProfileScreen.