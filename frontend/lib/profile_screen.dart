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
import 'login_screen.dart';

class Profile {
  final String name, username, email, phone;
  final List<String> hobbies;

  Profile({
    required this.name,
    required this.username,
    required this.email,
    required this.phone,
    required this.hobbies,
  });

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        name: (j['name'] as String?) ?? '',
        username: (j['username'] as String?) ?? '',
        email: (j['email'] as String?) ?? '',
        phone: (j['phone_number'] as String?) ?? '',
        hobbies: List<String>.from((j['hobbies'] as List<dynamic>? ?? [])),
      );
}

class ProfileService {
  final http.Client _client;
  ProfileService(this._client);

  String get _base => Config.serverBaseUrl;

  Future<Profile> getProfile() async {
    final token = await SessionManager.instance.jwt;
    if (token == null || token.isEmpty) {
      throw Exception('unauthorized');
    }
    final uri = Uri.parse('$_base/api/users');
    final resp = await _client
        .get(
          uri,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        )
        .timeout(Duration(milliseconds: Config.apiTimeout));

    if (resp.statusCode == 302) {
      throw Exception('unauthorized');
    }
    if (resp.statusCode == 401 || resp.statusCode == 403) {
      throw Exception('unauthorized');
    }
    if (resp.statusCode != 200) {
      throw Exception('Failed to load profile (${resp.statusCode}): ${resp.body}');
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    return Profile.fromJson(body);
  }

  Future<void> setHobbies(List<String> hobbies) async {
    final token = await SessionManager.instance.jwt;
    if (token == null || token.isEmpty) return;
    final uri = Uri.parse('$_base/api/users');
    final resp = await _client
        .put(
          uri,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'hobbies': hobbies}),
        )
        .timeout(Duration(milliseconds: Config.apiTimeout));

    if (resp.statusCode != 200 &&
        resp.statusCode != 202 &&
        resp.statusCode != 204) {
      throw Exception('Failed to save hobbies (${resp.statusCode})');
    }
  }
}

class TagData {
  final String id, text;
  TagData({required this.id, required this.text});
  @override
  bool operator ==(Object o) => o is TagData && o.id == id;
  @override
  int get hashCode => id.hashCode;
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
  String? _name, _username, _email, _phone;
  final List<TagData> _tags = [];
  bool _showAddInput = false;
  final _tagCtl = TextEditingController();
  final _tagFocus = FocusNode();
  final _tagScroll = ScrollController();

  bool _loading = true, _syncing = false;
  final _api = ProfileService(http.Client());
  String? _userId;
  String? _errorMsg;
  bool _suppressErrorBanner = false;
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

  Future<void> _clearSessionAndRedirect() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt');
    await prefs.remove('user_id');
    await prefs.remove('username');
    await prefs.remove('name');
    await prefs.remove('email');
    await prefs.remove('phone_number');
    await SessionManager.instance.update(userId: '', jwt: '', username: '');
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  Future<void> _bootstrap() async {
  try {
    _userId = await SessionManager.instance.userId;
    final prefs = await SharedPreferences.getInstance();

    _name = prefs.getString('name') ?? 'Your Name';
    _username = prefs.getString('username') ?? '';
    _email = prefs.getString('email') ?? '';
    _phone = prefs.getString('phone_number') ?? '';

    // Load cached hobbies first so UI shows something immediately.
    final cachedHobbies = prefs.getStringList('hobbies') ?? [];
    _tags
      ..clear()
      ..addAll(cachedHobbies.map((h) => TagData(id: h, text: h)));

    if (!_isGuest) {
      final prof = await _api.getProfile();

      await prefs.setString('name', prof.name);
      await prefs.setString('username', prof.username);
      await prefs.setString('email', prof.email);
      await prefs.setString('phone_number', prof.phone);
      await prefs.setStringList('hobbies', prof.hobbies);

      _name = prof.name;
      _username = prof.username;
      _email = prof.email;
      _phone = prof.phone;
      _tags
        ..clear()
        ..addAll(prof.hobbies.map((h) => TagData(id: h, text: h)));
    }
  } catch (e) {
    debugPrint('Profile bootstrap error: $e');
    if (e.toString().toLowerCase().contains('unauthorized')) {
      await _clearSessionAndRedirect();
      return;
    }
    setState(() {
      _errorMsg = 'Failed to load fresh profile; showing cached values.';
      _suppressErrorBanner = false;
    });
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() => _suppressErrorBanner = true);
    });
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}


  Future<void> _syncTags() async {
  if (_isGuest) return;
  setState(() => _syncing = true);
  try {
    final hobbyList = _tags.map((t) => t.text).toList();
    await _api.setHobbies(hobbyList);
    // Persist locally on success
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('hobbies', hobbyList);
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to sync – $e')));
    }
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
    Future.microtask(
        () => _tagScroll.jumpTo(_tagScroll.position.maxScrollExtent));
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
    final perm =
        src == ImageSource.camera ? Permission.camera : Permission.photos;
    if (!(await perm.request()).isGranted) {
      if (!mounted) return;
      showDialog(
          context: context,
          builder: (_) => AlertDialog(
                title: const Text('Permission needed'),
                content: const Text('Enable access to change photo.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  TextButton(
                      onPressed: () => openAppSettings(),
                      child: const Text('Settings')),
                ],
              ));
      return;
    }
    final x = await ImagePicker()
        .pickImage(source: src, imageQuality: 85, maxWidth: 800);
    if (x != null && mounted) setState(() => _pfp = File(x.path));
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
        child: Stack(children: [
          _blur(-134, -58, 582, const Color(0xFF60A5FA), 184),
          _blur(27, 419, 934, const Color(0xFFD8B4FE), 295),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 384),
                child: Column(
                  children: [
                    _header(),
                    if (_errorMsg != null && !_suppressErrorBanner)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF0D9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.orangeAccent),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _errorMsg!,
                                  style: const TextStyle(
                                      color: Colors.black87, fontSize: 14),
                                ),
                              ),
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _suppressErrorBanner = true),
                                child: const Icon(Icons.close,
                                    size: 18, color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // Profile info + hobbies. Profile info is intrinsic; hobbies expands.
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.only(
                          bottom: _navBarHeight +
                              MediaQuery.of(context).padding.bottom +
                              12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _profileInfo(),
                            _tagSection(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _bottomNav(),
          ),
          Positioned(
            bottom: _navBarHeight - (_centerFabSize / 2),
            left: 0,
            right: 0,
            child: _fabPlusContent(),
          ),
        ]),
      ),
    );
  }

  Widget _blur(double l, double t, double s, Color c, double sigma) =>
      Positioned(
        left: l,
        top: t,
        child: Container(
          width: s,
          height: s,
          decoration:
              BoxDecoration(color: c.withOpacity(.8), shape: BoxShape.circle),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: const SizedBox(),
          ),
        ),
      );

  Widget _header() => Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            IconButton(
              icon:
                  const Icon(Icons.arrow_back, size: 30, color: Color(0xFF4B5563)),
              onPressed: () => Navigator.pop(context),
            ),
            const Spacer(),
            TextButton(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Sign Out'),
                        content:
                            const Text('Are you sure you want to sign out?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Sign Out'),
                          ),
                        ],
                      ),
                    ) ??
                    false;
                if (confirmed) {
                  await _clearSessionAndRedirect();
                }
              },
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                backgroundColor: Colors.white.withOpacity(0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                foregroundColor: const Color(0xFF4B5563),
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
              child: const Text('Sign Out'),
            ),
          ],
        ),
      );

  Widget _profileInfo() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(children: [
          Stack(children: [
            CircleAvatar(
              radius: 83,
              backgroundColor: const Color(0xFFE8DCEF),
              backgroundImage: _pfp != null
                  ? FileImage(_pfp!)
                  : const AssetImage('assets/default_pfp.png') as ImageProvider,
            ),
            Positioned(right: 8, bottom: 8, child: _camBtn()),
          ]),
          const SizedBox(height: 16),
          Text(_name?.isNotEmpty == true ? _name! : 'Your name',
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text('@${_username ?? ""}',
              style: const TextStyle(color: Colors.black, fontSize: 16)),
          const SizedBox(height: 8),
          if ((_email ?? '').isNotEmpty || (_phone ?? '').isNotEmpty)
            _contactInfoBox(),
          const SizedBox(height: 24),
        ]),
      );

  Widget _contactInfoBox() => Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.9),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((_email ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Text('📧', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 6),
                    const Text('Email: ',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    Expanded(
                      child: Text(
                        _email!,
                        style: const TextStyle(color: Colors.black87),
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  ],
                ),
              ),
            if ((_phone ?? '').isNotEmpty)
              Row(
                children: [
                  const Text('📞', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  const Text('Phone: ',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  Expanded(
                    child: Text(
                      _phone!,
                      style: const TextStyle(color: Colors.black87),
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                ],
              ),
          ],
        ),
      );

  Widget _camBtn() => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(.1),
                blurRadius: 8,
                offset: const Offset(0, 4))
          ],
        ),
        child: IconButton(
          icon:
              const Icon(Icons.camera_alt, size: 20, color: Color(0xFF4B5563)),
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
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          // fixed height so it doesn’t resize when tags are added
          height: 300,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Column(
              children: [
                // header row with label and plus
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      const Text('Hobbies 🎯:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const Spacer(),
                      IconButton(
                        onPressed: () {
                          setState(() => _showAddInput = true);
                          Future.delayed(
                              const Duration(milliseconds: 90),
                              () => _tagFocus.requestFocus());
                        },
                        icon: const Icon(Icons.add, size: 24),
                        tooltip: 'Add hobby',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      // scrollable tags area
                      SingleChildScrollView(
                        controller: _tagScroll,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (int i = 0; i < _tags.length; i++)
                              _draggableChip(_tags[i], i),
                            _showAddInput ? _inputChip() : const SizedBox.shrink(),
                          ],
                        ),
                      ),
                      if (_syncing)
                        const Positioned(
                          top: 6,
                          right: 6,
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_tags.length > 2)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text('Drag to reorder • Tap red × to delete',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
                  ),
              ],
            ),
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

  Widget _chip(String txt, {VoidCallback? onRemove, bool elevated = false}) =>
      Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            elevation: elevated ? 8 : 0,
            borderRadius: BorderRadius.circular(5),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              decoration: BoxDecoration(
                  color: const Color(0xFF7C91ED),
                  borderRadius: BorderRadius.circular(5)),
              child: Text(txt,
                  style: const TextStyle(color: Colors.white, fontSize: 18)),
            ),
          ),
          if (onRemove != null)
            Positioned(
              right: -8,
              top: -8,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration:
                      const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  child: const Icon(Icons.close, size: 12, color: Colors.white),
                ),
              ),
            ),
        ],
      );

  Widget _addChipBtn() => GestureDetector(
        onTap: () {
          setState(() => _showAddInput = true);
          Future.delayed(const Duration(milliseconds: 90),
              () => _tagFocus.requestFocus());
        },
        child: const Icon(Icons.add, size: 24),
      );

  Widget _inputChip() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
            color: const Color(0xFF7C91ED),
            borderRadius: BorderRadius.circular(5)),
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
          GestureDetector(
              onTap: () {
                setState(() => _showAddInput = false);
                _tagCtl.clear();
              },
              child: const Icon(Icons.close, size: 16, color: Colors.white)),
        ]),
      );

  Widget _bottomNav() => Container(
        height: _navBarHeight + MediaQuery.of(context).padding.bottom,
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, -4))],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _navItem(Icons.people_alt, 'Friends', onTap: () {}),
          _navItem(Icons.home_rounded, 'Comunity', onTap: () {}),
          const SizedBox(width: _centerFabSize),
          _navItem(Icons.link_outlined, 'Links', onTap: () {}),
          _navItem(Icons.person_outline, 'Profile', isActive: true, onTap: () {}),
        ]),
      );

  Widget _navItem(IconData ic, String lbl, {bool isActive = false, required VoidCallback onTap}) =>
      InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 60,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: isActive
                  ? BoxDecoration(border: Border.all(color: Colors.purple, width: 2), borderRadius: BorderRadius.circular(6))
                  : null,
              child: Icon(ic, size: 20, color: isActive ? Colors.purple : const Color(0xFF4B5563)),
            ),
            const SizedBox(height: 2),
            Text(lbl,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: isActive ? Colors.purple : Colors.black)),
          ]),
        ),
      );

  Widget _fabPlusContent() => GestureDetector(
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
      );
}
