import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';

class MomentsRepository {
  const MomentsRepository();

  SupabaseClient get _client => SupabaseService.client;

  String? get currentUserId => _client.auth.currentUser?.id;

  Future<List<Map<String, dynamic>>> fetchMoments() async {
    final rows = await _client
        .from('moments')
        .select(
          'id,user_id,content,media_url,likes_count,comments_count,shares_count,created_at',
        )
        .order('created_at', ascending: false)
        .limit(50);
    final moments = (rows as List).cast<Map<String, dynamic>>();
    final ids = moments.map((row) => row['user_id'] as String).toSet().toList();
    final profiles = ids.isEmpty
        ? const <String, Map<String, dynamic>>{}
        : {
            for (final row
                in (await _client
                            .from('user_profiles')
                            .select('auth_user_id,data')
                            .inFilter('auth_user_id', ids)
                            .limit(100)
                        as List)
                    .cast<Map<String, dynamic>>())
              row['auth_user_id'] as String: row,
          };
    final liked = await _likedIds(
      moments.map((row) => row['id'] as String).toList(),
    );
    return moments
        .map((row) {
          final profile = profiles[row['user_id']];
          final rawData = profile?['data'];
          final data = rawData is Map
              ? Map<String, dynamic>.from(rawData)
              : const <String, dynamic>{};
          return {
            ...row,
            'liked_by_me': liked.contains(row['id']),
            'name':
                data['fullName'] ??
                data['userName'] ??
                data['nickname'] ??
                'عضو Saki',
            'avatar_url': data['avatarUrl'] ?? data['avatar_url'],
          };
        })
        .toList(growable: false);
  }

  Future<Set<String>> _likedIds(List<String> momentIds) async {
    final userId = currentUserId;
    if (userId == null || momentIds.isEmpty) return <String>{};
    final rows = await _client
        .from('moment_likes')
        .select('moment_id')
        .eq('user_id', userId)
        .inFilter('moment_id', momentIds)
        .limit(100);
    return (rows as List)
        .map((row) => (row as Map<String, dynamic>)['moment_id'] as String)
        .toSet();
  }

  Stream<List<Map<String, dynamic>>> watchMoments() async* {
    yield await fetchMoments();
    final controller = StreamController<List<Map<String, dynamic>>>();
    Future<void> refresh() async {
      if (!controller.isClosed) controller.add(await fetchMoments());
    }

    final channel = _client.channel('public:moments-feed')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'moments',
        callback: (_) => refresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'moment_likes',
        callback: (_) => refresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'moment_comments',
        callback: (_) => refresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'moment_shares',
        callback: (_) => refresh(),
      )
      ..subscribe();
    try {
      yield* controller.stream;
    } finally {
      await _client.removeChannel(channel);
      await controller.close();
    }
  }

  Future<String?> uploadMomentMedia(
    Uint8List bytes, {
    String extension = 'jpg',
  }) async {
    final userId = currentUserId;
    if (userId == null) throw const AuthException('يجب تسجيل الدخول أولًا');
    final path =
        '$userId/moments/${DateTime.now().microsecondsSinceEpoch}.$extension';
    await _client.storage
        .from('user-media')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: false,
            contentType: 'image/$extension',
          ),
        );
    return _client.storage.from('user-media').getPublicUrl(path);
  }

  Future<void> createMoment({required String content, String? mediaUrl}) async {
    final userId = currentUserId;
    if (userId == null) throw const AuthException('يجب تسجيل الدخول أولًا');
    final trimmed = content.trim();
    if (trimmed.isEmpty && (mediaUrl == null || mediaUrl.isEmpty)) {
      throw const PostgrestException(message: 'أضف نصًا أو صورة للمنشور');
    }
    await _client.from('moments').insert({
      'user_id': userId,
      'content': trimmed,
      'media_url': mediaUrl,
    });
  }

  Future<bool> toggleLike({
    required String momentId,
    required bool liked,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw const AuthException('يجب تسجيل الدخول أولًا');
    if (liked) {
      await _client
          .from('moment_likes')
          .delete()
          .eq('moment_id', momentId)
          .eq('user_id', userId);
      return false;
    }
    await _client.from('moment_likes').insert({
      'moment_id': momentId,
      'user_id': userId,
    });
    return true;
  }

  Future<List<Map<String, dynamic>>> fetchComments(String momentId) async {
    final rows = await _client
        .from('moment_comments')
        .select('id,moment_id,user_id,content,created_at')
        .eq('moment_id', momentId)
        .order('created_at', ascending: true)
        .limit(100);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> addComment({
    required String momentId,
    required String content,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw const AuthException('يجب تسجيل الدخول أولًا');
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;
    await _client.from('moment_comments').insert({
      'moment_id': momentId,
      'user_id': userId,
      'content': trimmed,
    });
  }

  Future<void> shareMoment(String momentId) async {
    final userId = currentUserId;
    if (userId == null) throw const AuthException('يجب تسجيل الدخول أولًا');
    await _client.from('moment_shares').upsert({
      'moment_id': momentId,
      'user_id': userId,
    }, onConflict: 'moment_id,user_id');
  }
}
