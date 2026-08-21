import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../models/room.dart';

enum RoomFeed { latest, visited, followed }

class RoomsRepository {
  const RoomsRepository();

  SupabaseClient get _client => SupabaseService.client;

  String? get currentUserId => _client.auth.currentUser?.id;

  Future<List<Room>> fetchRooms({
    String? category,
    RoomFeed feed = RoomFeed.latest,
    bool onlyMine = false,
  }) async {
    final userId = currentUserId;
    if ((feed != RoomFeed.latest || onlyMine) && userId == null) return [];

    List<String>? roomIds;
    if (feed == RoomFeed.followed) {
      roomIds = await _roomIdsFrom('room_follows', 'created_at', userId!);
    } else if (feed == RoomFeed.visited) {
      roomIds = await _roomIdsFrom('room_visits', 'last_visited_at', userId!);
    }
    if (roomIds != null && roomIds.isEmpty) return [];

    dynamic query = _client
        .from('voice_rooms')
        .select()
        .neq('status', 'closed');
    if (onlyMine && userId != null) {
      query = query.eq('owner_id', userId);
    }
    if (roomIds != null) {
      query = query.inFilter('id', roomIds);
    }

    final rows = await query.order('created_at', ascending: false);
    final rooms = (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Room.fromMap)
        .toList();
    if (category == null || category.isEmpty || category == 'الكل') {
      return rooms;
    }
    return rooms.where((room) => room.roomTheme == category).toList();
  }

  Future<List<String>> _roomIdsFrom(
    String table,
    String orderColumn,
    String userId,
  ) async {
    final rows = await _client
        .from(table)
        .select('room_id')
        .eq('user_id', userId)
        .order(orderColumn, ascending: false);
    return (rows as List)
        .map((row) => (row as Map<String, dynamic>)['room_id'] as String)
        .toList(growable: false);
  }

  Future<Set<String>> fetchFollowedRoomIds() async {
    final userId = currentUserId;
    if (userId == null) return <String>{};
    final rows = await _client
        .from('room_follows')
        .select('room_id')
        .eq('user_id', userId);
    return (rows as List)
        .map((row) => (row as Map<String, dynamic>)['room_id'] as String)
        .toSet();
  }

  Future<bool> toggleRoomFollow(String roomId) async {
    final userId = currentUserId;
    if (userId == null) throw const AuthException('يجب تسجيل الدخول للمتابعة');
    final existing = await _client
        .from('room_follows')
        .select('room_id')
        .eq('room_id', roomId)
        .eq('user_id', userId)
        .maybeSingle();
    if (existing != null) {
      await _client
          .from('room_follows')
          .delete()
          .eq('room_id', roomId)
          .eq('user_id', userId);
      return false;
    }
    await _client.from('room_follows').insert({
      'room_id': roomId,
      'user_id': userId,
    });
    return true;
  }

  Future<void> recordRoomVisit(String roomId) async {
    final userId = currentUserId;
    if (userId == null) return;
    final now = DateTime.now().toUtc().toIso8601String();
    final existing = await _client
        .from('room_visits')
        .select('visit_count')
        .eq('room_id', roomId)
        .eq('user_id', userId)
        .maybeSingle();
    if (existing == null) {
      await _client.from('room_visits').insert({
        'room_id': roomId,
        'user_id': userId,
        'last_visited_at': now,
        'visit_count': 1,
      });
      return;
    }
    final currentCount = (existing['visit_count'] as num?)?.toInt() ?? 0;
    await _client
        .from('room_visits')
        .update({'last_visited_at': now, 'visit_count': currentCount + 1})
        .eq('room_id', roomId)
        .eq('user_id', userId);
  }

  Future<String> uploadRoomCover(
    Uint8List bytes, {
    required String fileName,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('يجب تسجيل الدخول أولًا');
    final path = '${user.id}/rooms/$fileName';
    await _client.storage
        .from('user-media')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );
    return _client.storage.from('user-media').getPublicUrl(path);
  }

  Future<Room> createRoom({
    required String name,
    required String countryCode,
    String? coverUrl,
    String? description,
    String theme = 'music',
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('يجب تسجيل الدخول لإنشاء غرفة');
    final row = await _client
        .from('voice_rooms')
        .insert({
          'owner_id': user.id,
          'name': name.trim(),
          'country_code': countryCode,
          'cover_url': coverUrl,
          'status': 'open',
          'metadata': {
            'description': description?.trim(),
            'theme': theme,
            'member_count': 0,
            'likes_count': 0,
          },
        })
        .select()
        .single();
    return Room.fromMap(row);
  }

  Future<List<RoomMember>> fetchRoomMembers(String roomId) async {
    final rows = await _client
        .from('voice_room_members')
        .select(
          'user_id,role,joined_at,left_at,seat_index,is_muted,is_speaking',
        )
        .eq('room_id', roomId)
        .isFilter('left_at', null)
        .order('seat_index', ascending: true);
    final maps = (rows as List).cast<Map<String, dynamic>>();
    final profiles = await _profilesByUserIds(
      maps.map((row) => row['user_id'] as String).toSet().toList(),
    );
    String? ownerId;
    try {
      final room = await _client
          .from('voice_rooms')
          .select('owner_id')
          .eq('id', roomId)
          .single();
      ownerId = room['owner_id'] as String?;
    } catch (_) {
      // Keep the role returned by the membership row if the room lookup fails.
    }
    return maps
        .map((row) {
          final adjusted = Map<String, dynamic>.from(row);
          if (ownerId != null && row['user_id'] == ownerId) {
            adjusted['role'] = 'owner';
          }
          return RoomMember.fromMap(
            adjusted,
            profile: profiles[row['user_id'] as String],
          );
        })
        .toList(growable: false);
  }

  Future<Map<String, Map<String, dynamic>>> _profilesByUserIds(
    List<String> userIds,
  ) async {
    if (userIds.isEmpty) return <String, Map<String, dynamic>>{};
    try {
      final rows = await _client
          .from('user_profiles')
          .select('auth_user_id,data,saki_id')
          .inFilter('auth_user_id', userIds)
          .limit(100);
      return {
        for (final row in (rows as List).cast<Map<String, dynamic>>())
          row['auth_user_id'] as String: row,
      };
    } catch (_) {
      return <String, Map<String, dynamic>>{};
    }
  }

  Stream<List<RoomMember>> watchRoomMembers(String roomId) async* {
    yield await fetchRoomMembers(roomId);
    final controller = StreamController<List<RoomMember>>();
    final channel = _client.channel('public:room-members:$roomId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'voice_room_members',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'room_id',
          value: roomId,
        ),
        callback: (_) async {
          if (!controller.isClosed) {
            controller.add(await fetchRoomMembers(roomId));
          }
        },
      )
      ..subscribe();
    try {
      yield* controller.stream;
    } finally {
      await _client.removeChannel(channel);
      await controller.close();
    }
  }

  Future<int> _nextSeatIndex(String roomId, {int seatCount = 10}) async {
    final rows = await _client
        .from('voice_room_members')
        .select('seat_index')
        .eq('room_id', roomId)
        .isFilter('left_at', null)
        .limit(50);
    final occupied = (rows as List)
        .map((row) => (row as Map<String, dynamic>)['seat_index'])
        .whereType<num>()
        .map((value) => value.toInt())
        .toSet();
    for (var index = 0; index < seatCount; index++) {
      if (!occupied.contains(index)) return index;
    }
    return -1;
  }

  Future<void> joinRoom(String roomId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('يجب تسجيل الدخول');
    final room = await _client
        .from('voice_rooms')
        .select('owner_id,metadata')
        .eq('id', roomId)
        .single();
    final metadata = room['metadata'] is Map
        ? Map<String, dynamic>.from(room['metadata'] as Map)
        : const <String, dynamic>{};
    final seatCount = (metadata['seat_count'] as num?)?.toInt() ?? 10;
    final existing = await _client
        .from('voice_room_members')
        .select('seat_index,left_at')
        .eq('room_id', roomId)
        .eq('user_id', user.id)
        .maybeSingle();
    final existingSeat = (existing?['seat_index'] as num?)?.toInt();
    final seatIndex =
        existing != null && existing['left_at'] == null && existingSeat != null
        ? existingSeat
        : await _nextSeatIndex(roomId, seatCount: seatCount);
    if (seatIndex < 0) throw const AuthException('الغرفة ممتلئة حاليًا');
    await _client.from('voice_room_members').upsert({
      'room_id': roomId,
      'user_id': user.id,
      'role': room['owner_id'] == user.id ? 'owner' : 'listener',
      'seat_index': seatIndex,
      'is_muted': false,
      'is_speaking': false,
      'left_at': null,
    }, onConflict: 'room_id,user_id');
    await recordRoomVisit(roomId);
  }

  Future<void> setSeat({
    required String roomId,
    required String userId,
    required int? seatIndex,
  }) async {
    final current = _client.auth.currentUser;
    if (current == null) throw const AuthException('يجب تسجيل الدخول');
    await _client
        .from('voice_room_members')
        .update({'seat_index': seatIndex})
        .eq('room_id', roomId)
        .eq('user_id', userId);
  }

  Future<void> setMemberMuted({
    required String roomId,
    required String userId,
    required bool muted,
  }) async {
    final current = _client.auth.currentUser;
    if (current == null) throw const AuthException('يجب تسجيل الدخول');
    await _client
        .from('voice_room_members')
        .update({'is_muted': muted})
        .eq('room_id', roomId)
        .eq('user_id', userId);
  }

  Future<void> sendGift({
    required String roomId,
    required String giftType,
    int quantity = 1,
    String? receiverId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('يجب تسجيل الدخول لإرسال هدية');
    await _client.from('room_gifts').insert({
      'room_id': roomId,
      'sender_id': user.id,
      'receiver_id': receiverId,
      'gift_type': giftType,
      'quantity': quantity,
    });
  }

  Stream<List<RoomGift>> watchGifts(String roomId) async* {
    Future<List<RoomGift>> fetch() async {
      final rows = await _client
          .from('room_gifts')
          .select(
            'id,room_id,sender_id,receiver_id,gift_type,quantity,created_at',
          )
          .eq('room_id', roomId)
          .order('created_at', ascending: false)
          .limit(30);
      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map(RoomGift.fromMap)
          .toList(growable: false);
    }

    yield await fetch();
    final controller = StreamController<List<RoomGift>>();
    final channel = _client.channel('public:room-gifts:$roomId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'room_gifts',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'room_id',
          value: roomId,
        ),
        callback: (_) async {
          if (!controller.isClosed) controller.add(await fetch());
        },
      )
      ..subscribe();
    try {
      yield* controller.stream;
    } finally {
      await _client.removeChannel(channel);
      await controller.close();
    }
  }

  Future<void> sendSeatReaction({
    required String roomId,
    required int seatIndex,
    required String reaction,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('يجب تسجيل الدخول');
    await _client.from('room_seat_reactions').insert({
      'room_id': roomId,
      'seat_index': seatIndex,
      'user_id': user.id,
      'reaction': reaction,
    });
  }

  Stream<List<SeatReaction>> watchSeatReactions(String roomId) async* {
    Future<List<SeatReaction>> fetch() async {
      final rows = await _client
          .from('room_seat_reactions')
          .select('id,room_id,seat_index,user_id,reaction,created_at')
          .eq('room_id', roomId)
          .order('created_at', ascending: false)
          .limit(50);
      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map(SeatReaction.fromMap)
          .toList(growable: false);
    }

    yield await fetch();
    final controller = StreamController<List<SeatReaction>>();
    final channel = _client.channel('public:room-seat-reactions:$roomId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'room_seat_reactions',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'room_id',
          value: roomId,
        ),
        callback: (_) async {
          if (!controller.isClosed) controller.add(await fetch());
        },
      )
      ..subscribe();
    try {
      yield* controller.stream;
    } finally {
      await _client.removeChannel(channel);
      await controller.close();
    }
  }

  Future<void> updateRoomSettings({
    required Room room,
    required int seatCount,
    required Map<String, dynamic> settings,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null || user.id != room.ownerId) {
      throw const AuthException('إعدادات الغرفة متاحة للمالك فقط');
    }
    final metadata = <String, dynamic>{
      'description': room.description,
      'theme': room.roomTheme,
      'member_count': room.memberCount,
      'likes_count': room.likesCount,
      'seat_count': seatCount,
      'settings': {...room.settings, ...settings},
    };
    await _client
        .from('voice_rooms')
        .update({'metadata': metadata})
        .eq('id', room.id)
        .eq('owner_id', user.id);
  }

  Future<void> updateRoomName({
    required Room room,
    required String name,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null || user.id != room.ownerId) {
      throw const AuthException('تعديل الغرفة متاح للمالك فقط');
    }
    await _client
        .from('voice_rooms')
        .update({'name': name.trim()})
        .eq('id', room.id)
        .eq('owner_id', user.id);
  }

  Future<void> leaveRoom(String roomId) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    await _client
        .from('voice_room_members')
        .update({'left_at': DateTime.now().toUtc().toIso8601String()})
        .eq('room_id', roomId)
        .eq('user_id', user.id);
  }

  Stream<List<Room>> watchRooms({
    RoomFeed feed = RoomFeed.latest,
    bool onlyMine = false,
  }) async* {
    yield await fetchRooms(feed: feed, onlyMine: onlyMine);
    final controller = StreamController<List<Room>>();
    final channel = _client.channel('public:rooms-feed')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'voice_rooms',
        callback: (_) async {
          if (!controller.isClosed) {
            controller.add(await fetchRooms(feed: feed, onlyMine: onlyMine));
          }
        },
      )
      ..subscribe();
    try {
      yield* controller.stream;
    } finally {
      await _client.removeChannel(channel);
      await controller.close();
    }
  }
}
