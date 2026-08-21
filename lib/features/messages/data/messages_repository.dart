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
    this.metadata = const {},
  });

  final String id;
  final String roomId;
  final String userId;
  final String content;
  final DateTime createdAt;
  final String? authorName;
  final String? authorAvatarUrl;
  final String type;
  final Map<String, dynamic> metadata;

  factory RoomMessage.fromMap(
    Map<String, dynamic> map, {
    Map<String, dynamic>? profile,
  }) {
    final rawMetadata = map['metadata'];
    final metadata = rawMetadata is Map
        ? Map<String, dynamic>.from(rawMetadata)
        : const <String, dynamic>{};
    final profileData = profile?['data'] is Map
        ? Map<String, dynamic>.from(profile!['data'] as Map)
        : const <String, dynamic>{};
    final name =
        (metadata['author_name'] as String?) ??
        (profileData['fullName'] as String?) ??
        (profileData['userName'] as String?) ??
        profile?['display_name'] as String?;
    final avatar =
        (metadata['author_avatar_url'] as String?) ??
        (profileData['avatarUrl'] as String?) ??
        (profileData['avatar_url'] as String?);
    return RoomMessage(
      id: map['id'] as String,
      roomId: map['room_id'] as String,
      userId: map['user_id'] as String,
      content: (map['content'] as String?) ?? '',
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      type: (map['message_type'] as String?) ?? 'text',
      metadata: metadata,
      authorName: name,
      authorAvatarUrl: avatar,
    );
  }
}

class MessagesRepository {
  const MessagesRepository();

  SupabaseClient get _client => SupabaseService.client;

  Future<List<RoomMessage>> fetchRoomMessages(String roomId) async {
    final rows = await _client
        .from('room_messages')
        .select('id,room_id,user_id,content,message_type,metadata,created_at')
        .eq('room_id', roomId)
        .order('created_at', ascending: true)
        .limit(100);
    final maps = (rows as List).cast<Map<String, dynamic>>();
    final profiles = await _profilesByUserIds(
      maps.map((row) => row['user_id'] as String).toSet().toList(),
    );
    return maps
        .map(
          (row) => RoomMessage.fromMap(
            row,
            profile: profiles[row['user_id'] as String],
          ),
        )
        .toList(growable: false);
  }

  Future<Map<String, Map<String, dynamic>>> _profilesByUserIds(
    List<String> userIds,
  ) async {
    if (userIds.isEmpty) return <String, Map<String, dynamic>>{};
    try {
      final rows = await _client
          .from('user_profiles')
          .select('auth_user_id,data')
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

  Future<void> sendRoomMessage({
    required String roomId,
    required String content,
    String type = 'text',
    Map<String, dynamic>? metadata,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('يجب تسجيل الدخول');
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;
    await _client.from('room_messages').insert({
      'room_id': roomId,
      'user_id': user.id,
      'content': trimmed,
      'message_type': type,
      'metadata': metadata ?? const <String, dynamic>{},
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
