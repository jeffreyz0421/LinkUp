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
// lib/add_a_friend.dart

// lib/add_a_friend.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:http/http.dart' as http;

import 'session_manager.dart';
// only bring in the service, not its Friend type
import 'package:linkup/services/friend_service.dart' show FriendService;
// bring in your real Friend model under an alias
import 'package:linkup/models/friend.dart' as friend_model;

const double _navBarHeight = 88;

class AddFriendScreen extends StatefulWidget {
  const AddFriendScreen({Key? key}) : super(key: key);
  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  final _searchCtl = TextEditingController();
  final _service = FriendService(http.Client());

  List<friend_model.Friend> _results = [];
  final Set<String> _requested = {};
  bool _loading = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _searchCtl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtl.removeListener(_onSearchChanged);
    _searchCtl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final q = _searchCtl.text.trim();
    if (q.isEmpty) {
      setState(() {
        _results = [];
        _errorMsg = null;
      });
    } else {
      _search(q);
    }
  }

  Future<void> _search(String query) async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    try {
      // searchUsers now returns List<friend_model.Friend>
      final List<friend_model.Friend> users =
          await _service.searchUsers(query);
      setState(() => _results = users);
    } catch (e) {
      setState(() => _errorMsg = 'Failed to search: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _sendRequest(String friendId) async {
    try {
      await _service.sendRequest(friendId);
      HapticFeedback.selectionClick();
      setState(() => _requested.add(friendId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend request sent')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending request: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGuest = SessionManager.instance.isGuest;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFB3FFFF), Color(0xFFBABAF2)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _header(context),
              const SizedBox(height: 12),
              if (isGuest)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  child: Text(
                    'Sign in to search for friends.',
                    style: TextStyle(fontSize: 18),
                  ),
                )
              else ...[
                _searchBar(),
                if (_errorMsg != null)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(_errorMsg!,
                        style: const TextStyle(color: Colors.red)),
                  ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _resultsList(),
                ),
              ],
              // bottom padding so list doesn’t hide under nav
              SizedBox(height: isGuest ? 0 : _navBarHeight),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(children: [
          IconButton(
            icon: const Icon(Icons.arrow_back,
                size: 30, color: Color(0xFF4B5563)),
            onPressed: () => Navigator.pop(ctx),
          ),
          const SizedBox(width: 8),
          const Text('Add a friend',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        ]),
      );

  Widget _searchBar() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.85),
            borderRadius: BorderRadius.circular(24),
          ),
          child: TextField(
            controller: _searchCtl,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText: 'Search by username…',
              prefixIcon: Padding(
                padding: EdgeInsets.only(left: 12, right: 8),
                child: Icon(Icons.search, color: Color(0xFF5D61A1)),
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      );

  Widget _resultsList() {
    if (_results.isEmpty) {
      return const Center(
        child: Text('No users found.', style: TextStyle(fontSize: 16)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _resultTile(_results[i]),
    );
  }

  Widget _resultTile(friend_model.Friend f) {
    final already = _requested.contains(f.id);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
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
                const SizedBox(height: 2),
                Text('@${f.username}',
                    style: const TextStyle(fontSize: 14, color: Colors.grey)),
              ],
            ),
          ),
          GestureDetector(
            onTap: already ? null : () => _sendRequest(f.id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: already ? Colors.grey.shade300 : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: already ? Colors.grey : Colors.blue,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    already ? Icons.check : Icons.person_add,
                    size: 18,
                    color: already ? Colors.grey : Colors.blue,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    already ? 'Requested' : 'Add',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: already ? Colors.grey : Colors.blue,
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
}
