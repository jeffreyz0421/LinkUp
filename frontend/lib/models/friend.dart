// lib/models/friend.dart

class Friend {
  final String id;
  final String name;
  final String username;
  final String avatarUrl;
  final String where;     // <— add this
  final int lastSeen;     // <— and this

  Friend({
    required this.id,
    required this.name,
    required this.username,
    required this.avatarUrl,
    required this.where,
    required this.lastSeen,
  });

  factory Friend.fromJson(Map<String, dynamic> json) => Friend(
        id: json['id'] as String,
        name: json['name'] as String,
        username: json['username'] as String,
        avatarUrl: json['avatar_url'] as String? ?? '',
        where: json['last_active_location']?['place'] as String? ?? '',
        lastSeen: json['last_active_minutes_ago'] as int? ?? 0,
      );
}
