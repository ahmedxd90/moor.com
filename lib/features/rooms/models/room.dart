class Room {
  const Room({
    required this.id,
    required this.name,
    required this.ownerId,
    this.description,
    this.coverUrl,
    this.roomTheme = 'music',
    this.memberCount = 0,
    this.likesCount = 0,
    this.isLive = false,
    this.isLocked = false,
    this.country,
  });

  final String id;
  final String name;
  final String ownerId;
  final String? description;
  final String? coverUrl;
  final String roomTheme;
  final int memberCount;
  final int likesCount;
  final bool isLive;
  final bool isLocked;
  final String? country;

  factory Room.fromMap(Map<String, dynamic> map) {
    final metadata = map['metadata'] is Map
        ? Map<String, dynamic>.from(map['metadata'] as Map)
        : const <String, dynamic>{};
    final status = (map['status'] as String?) ?? 'open';
    return Room(
      id: map['id'] as String,
      name: (map['name'] as String?) ?? 'غرفة بدون اسم',
      ownerId: map['owner_id'] as String,
      description:
          (metadata['description'] as String?) ??
          (metadata['notice'] as String?),
      coverUrl: map['cover_url'] as String?,
      roomTheme: (metadata['theme'] as String?) ?? 'music',
      memberCount: (metadata['member_count'] as num?)?.toInt() ?? 0,
      likesCount: (metadata['likes_count'] as num?)?.toInt() ?? 0,
      isLive: status == 'live' || metadata['is_live'] == true,
      isLocked: status == 'locked' || metadata['is_locked'] == true,
      country: map['country_code'] as String?,
    );
  }
}
