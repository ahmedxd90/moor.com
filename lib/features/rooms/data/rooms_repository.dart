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

  Future<void> joinRoom(String roomId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('يجب تسجيل الدخول');
    await _client.from('voice_room_members').upsert({
      'room_id': roomId,
      'user_id': user.id,
      'role': 'listener',
      'left_at': null,
    }, onConflict: 'room_id,user_id');
    await recordRoomVisit(roomId);
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
