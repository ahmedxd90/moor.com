import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';

class RoomMessage {
  const RoomMessage({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.authorName,
    this.authorAvatarUrl,
    this.type = 'text',
  });

  final String id;
  final String roomId;
  final String userId;
  final String content;
  final DateTime createdAt;
  final String? authorName;
  final String? authorAvatarUrl;
  final String type;

  factory RoomMessage.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'] is Map<String, dynamic>
        ? map['profiles'] as Map<String, dynamic>
        : null;
    return RoomMessage(
      id: map['id'] as String,
      roomId: map['room_id'] as String,
      userId: map['user_id'] as String,
      content: (map['content'] as String?) ?? '',
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      type: (map['type'] as String?) ?? 'text',
      authorName: profile?['name'] as String?,
      authorAvatarUrl: profile?['avatar_url'] as String?,
    );
  }
}

class MessagesRepository {
  const MessagesRepository();

  SupabaseClient get _client => SupabaseService.client;

  Future<List<RoomMessage>> fetchRoomMessages(String roomId) async {
    final rows = await _client
        .from('room_messages')
        .select('*, profiles(name, avatar_url)')
        .eq('room_id', roomId)
        .order('created_at', ascending: true)
        .limit(100);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(RoomMessage.fromMap)
        .toList();
  }

  Future<void> sendRoomMessage({
    required String roomId,
    required String content,
    String type = 'text',
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('يجب تسجيل الدخول');
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;
    await _client.from('room_messages').insert({
      'room_id': roomId,
      'user_id': user.id,
      'content': trimmed,
      'type': type,
    });
  }

  Stream<List<RoomMessage>> watchRoomMessages(String roomId) async* {
    yield await fetchRoomMessages(roomId);
    final controller = StreamController<List<RoomMessage>>();
    final channel = _client.channel('public:room-messages:$roomId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'room_messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'room_id',
          value: roomId,
        ),
        callback: (_) async {
          if (!controller.isClosed) {
            controller.add(await fetchRoomMessages(roomId));
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
