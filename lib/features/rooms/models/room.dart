class Room {
  const Room({
    required this.id,
    required this.name,
    required this.ownerId,
    this.roomNumber,
    this.description,
    this.coverUrl,
    this.roomTheme = 'music',
    this.memberCount = 0,
    this.likesCount = 0,
    this.isLive = false,
    this.isLocked = false,
    this.country,
    this.participantAvatars = const [],
    this.seatCount = 10,
    this.settings = const {},
  });

  final String id;
  final String name;
  final String ownerId;
  final int? roomNumber;
  final String? description;
  final String? coverUrl;
  final String roomTheme;
  final int memberCount;
  final int likesCount;
  final bool isLive;
  final bool isLocked;
  final String? country;
  final List<String> participantAvatars;
  final int seatCount;
  final Map<String, dynamic> settings;

  bool get allowMemberMic => settings['allow_member_mic'] == true;

  Room copyWith({
    String? name,
    String? description,
    String? coverUrl,
    int? seatCount,
    Map<String, dynamic>? settings,
  }) => Room(
    id: id,
    name: name ?? this.name,
    ownerId: ownerId,
    roomNumber: roomNumber,
    description: description ?? this.description,
    coverUrl: coverUrl ?? this.coverUrl,
    roomTheme: roomTheme,
    memberCount: memberCount,
    likesCount: likesCount,
    isLive: isLive,
    isLocked: isLocked,
    country: country,
    participantAvatars: participantAvatars,
    seatCount: seatCount ?? this.seatCount,
    settings: settings ?? this.settings,
  );
  String get announcement => (settings['announcement'] as String?) ?? '';
  int get memberFee => (settings['member_fee'] as num?)?.toInt() ?? 0;

  factory Room.fromMap(Map<String, dynamic> map) {
    final metadata = map['metadata'] is Map
        ? Map<String, dynamic>.from(map['metadata'] as Map)
        : const <String, dynamic>{};
    final settings = metadata['settings'] is Map
        ? Map<String, dynamic>.from(metadata['settings'] as Map)
        : const <String, dynamic>{};
    final status = (map['status'] as String?) ?? 'open';
    return Room(
      id: map['id'] as String,
      name: (map['name'] as String?) ?? 'غرفة بدون اسم',
      ownerId: map['owner_id'] as String,
      roomNumber: (map['room_id'] as num?)?.toInt(),
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
      participantAvatars: metadata['participant_avatars'] is List
          ? (metadata['participant_avatars'] as List)
                .whereType<String>()
                .toList(growable: false)
          : const [],
      seatCount: (metadata['seat_count'] as num?)?.toInt() ?? 10,
      settings: settings,
    );
  }
}

class RoomMember {
  const RoomMember({
    required this.userId,
    this.seatIndex,
    this.role = 'listener',
    this.name = 'عضو',
    this.avatarUrl,
    this.sakiId,
    this.joinedAt,
    this.isMuted = false,
    this.isSpeaking = false,
    this.isModerator = false,
  });

  final String userId;
  final int? seatIndex;
  final String role;
  final String name;
  final String? avatarUrl;
  final int? sakiId;
  final DateTime? joinedAt;
  final bool isMuted;
  final bool isSpeaking;
  final bool isModerator;

  bool get isOwner => role == 'owner' || role == 'host';
  bool get isSpeaker => seatIndex != null;

  factory RoomMember.fromMap(
    Map<String, dynamic> map, {
    Map<String, dynamic>? profile,
  }) {
    final profileData = profile?['data'] is Map
        ? Map<String, dynamic>.from(profile!['data'] as Map)
        : const <String, dynamic>{};
    final name =
        (profileData['fullName'] as String?) ??
        (profileData['userName'] as String?) ??
        (profileData['name'] as String?) ??
        'عضو';
    final avatar =
        (profileData['avatarUrl'] as String?) ??
        (profileData['avatar_url'] as String?);
    final sakiId = (profile?['saki_id'] as num?)?.toInt();
    return RoomMember(
      userId: map['user_id'] as String,
      seatIndex: (map['seat_index'] as num?)?.toInt(),
      role: (map['role'] as String?) ?? 'listener',
      name: name,
      avatarUrl: avatar,
      sakiId: sakiId,
      joinedAt: DateTime.tryParse(map['joined_at'] as String? ?? '')?.toLocal(),
      isMuted: map['is_muted'] == true,
      isSpeaking: map['is_speaking'] == true,
      isModerator: map['is_moderator'] == true,
    );
  }
}

class RoomSeatInvite {
  const RoomSeatInvite({
    required this.id,
    required this.roomId,
    required this.inviterId,
    required this.inviteeId,
    required this.seatIndex,
    required this.status,
    this.expiresAt,
    this.createdAt,
  });

  final String id;
  final String roomId;
  final String inviterId;
  final String inviteeId;
  final int seatIndex;
  final String status;
  final DateTime? expiresAt;
  final DateTime? createdAt;

  factory RoomSeatInvite.fromMap(Map<String, dynamic> map) => RoomSeatInvite(
    id: map['id'] as String,
    roomId: map['room_id'] as String,
    inviterId: map['inviter_id'] as String,
    inviteeId: map['invitee_id'] as String,
    seatIndex: (map['seat_index'] as num?)?.toInt() ?? 0,
    status: (map['status'] as String?) ?? 'pending',
    expiresAt: DateTime.tryParse(map['expires_at'] as String? ?? '')?.toLocal(),
    createdAt: DateTime.tryParse(map['created_at'] as String? ?? '')?.toLocal(),
  );
}

class RoomGift {
  const RoomGift({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.giftType,
    required this.quantity,
    this.senderName,
    this.receiverId,
    this.unitPrice = 0,
    this.createdAt,
  });

  final String id;
  final String roomId;
  final String senderId;
  final String giftType;
  final int quantity;
  final String? senderName;
  final String? receiverId;
  final int unitPrice;
  final DateTime? createdAt;

  factory RoomGift.fromMap(Map<String, dynamic> map, {String? senderName}) =>
      RoomGift(
        id: map['id'] as String,
        roomId: map['room_id'] as String,
        senderId: map['sender_id'] as String,
        giftType: (map['gift_type'] as String?) ?? 'rose',
        quantity: (map['quantity'] as num?)?.toInt() ?? 1,
        senderName: senderName,
        receiverId: map['receiver_id'] as String?,
        unitPrice: (map['unit_price'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.tryParse(
          map['created_at'] as String? ?? '',
        )?.toLocal(),
      );
}

class GiftCatalogItem {
  const GiftCatalogItem({
    required this.giftType,
    required this.displayName,
    required this.category,
    required this.price,
    required this.emoji,
    this.assetUrl,
  });

  final String giftType;
  final String displayName;
  final String category;
  final int price;
  final String emoji;
  final String? assetUrl;

  factory GiftCatalogItem.fromMap(Map<String, dynamic> map) {
    return GiftCatalogItem(
      giftType: map['gift_type'] as String,
      displayName: (map['display_name'] as String?) ?? 'هدية',
      category: (map['category'] as String?) ?? 'general',
      price: (map['price'] as num?)?.toInt() ?? 1,
      emoji: (map['emoji'] as String?) ?? '🎁',
      assetUrl: map['asset_url'] as String?,
    );
  }
}

class GiftRankingEntry {
  const GiftRankingEntry({
    required this.rank,
    required this.userId,
    required this.totalCoins,
    required this.totalGifts,
    this.name,
    this.avatarUrl,
    this.sakiId,
  });

  final int rank;
  final String userId;
  final int totalCoins;
  final int totalGifts;
  final String? name;
  final String? avatarUrl;
  final int? sakiId;

  GiftRankingEntry copyWithProfile(Map<String, dynamic>? profile) {
    if (profile == null) return this;
    final data = profile['data'] is Map
        ? Map<String, dynamic>.from(profile['data'] as Map)
        : const <String, dynamic>{};
    return GiftRankingEntry(
      rank: rank,
      userId: userId,
      totalCoins: totalCoins,
      totalGifts: totalGifts,
      name:
          (data['fullName'] as String?) ??
          (data['userName'] as String?) ??
          (data['name'] as String?),
      avatarUrl:
          (data['avatarUrl'] as String?) ?? (data['avatar_url'] as String?),
      sakiId: (profile['saki_id'] as num?)?.toInt(),
    );
  }
}

class SeatReaction {
  const SeatReaction({
    required this.id,
    required this.roomId,
    required this.seatIndex,
    required this.userId,
    required this.reaction,
    this.createdAt,
  });

  final String id;
  final String roomId;
  final int seatIndex;
  final String userId;
  final String reaction;
  final DateTime? createdAt;

  factory SeatReaction.fromMap(Map<String, dynamic> map) => SeatReaction(
    id: map['id'] as String,
    roomId: map['room_id'] as String,
    seatIndex: (map['seat_index'] as num?)?.toInt() ?? 0,
    userId: map['user_id'] as String,
    reaction: (map['reaction'] as String?) ?? '❤️',
    createdAt: DateTime.tryParse(map['created_at'] as String? ?? '')?.toLocal(),
  );
}
