import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../models/room.dart';

class RoomsRepository {
  const RoomsRepository();

  SupabaseClient get _client => SupabaseService.client;

  String? get currentUserId => _client.auth.currentUser?.id;

  Future<List<Room>> fetchRooms({String? category}) async {
    final rows = await _client
        .from('voice_rooms')
        .select()
        .neq('status', 'closed')
        .order('created_at', ascending: false);
    final rooms = (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Room.fromMap)
        .toList();
    if (category == null || category.isEmpty || category == 'الكل') {
      return rooms;
    }
    return rooms.where((room) => room.roomTheme == category).toList();
  }

  Future<Room> createRoom({
    required String name,
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

  Stream<List<Room>> watchRooms() async* {
    yield await fetchRooms();
    final controller = StreamController<List<Room>>();
    final channel = _client.channel('public:rooms-feed')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'voice_rooms',
        callback: (_) async {
          if (!controller.isClosed) controller.add(await fetchRooms());
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
