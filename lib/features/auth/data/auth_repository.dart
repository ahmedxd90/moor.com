import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/supabase/supabase_client.dart';

class SakiAuthResponse {
  const SakiAuthResponse({this.session, this.user});

  final String? session;
  final Map<String, dynamic>? user;
}

class AuthRepository {
  const AuthRepository();

  static SupabaseClient get _client => SupabaseService.client;

  Future<SakiAuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    return SakiAuthResponse(
      session: response.session?.accessToken,
      user: _authUserMap(response.user),
    );
  }

  Future<SakiAuthResponse> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    final trimmedName = name.trim();
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'fullName': trimmedName,
        'name': trimmedName,
        'nickname': trimmedName,
        'userName': _safeUsername(trimmedName),
      },
    );
    return SakiAuthResponse(
      session: response.session?.accessToken,
      user: _authUserMap(response.user),
    );
  }

  String _safeUsername(String value) {
    final cleaned = value.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-zA-Z0-9_]'),
      '',
    );
    return cleaned.length >= 3
        ? cleaned.substring(0, cleaned.length > 30 ? 30 : cleaned.length)
        : 'saki_user';
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<void> signInWithGoogle() async {
    if (!AppConfig.isConfigured) {
      throw const AuthException('إعداد Supabase غير مكتمل');
    }
    final launched = await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: _authRedirect,
      queryParams: const {'prompt': 'select_account'},
    );
    if (!launched) {
      throw const AuthException('تعذر فتح تسجيل الدخول عبر Google');
    }
  }

  Future<void> sendPasswordReset({required String email}) async {
    await _client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: _authRedirect,
    );
  }

  String get _authRedirect {
    final configured = AppConfig.authRedirectOverride.trim();
    if (configured.isNotEmpty) return configured;
    return '${AppConfig.androidPackage}://login-callback';
  }

  Future<Map<String, dynamic>?> getMyProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    var row = await _client
        .from('user_profiles')
        .select('id,auth_user_id,data,saki_id,created_at,updated_at')
        .eq('auth_user_id', user.id)
        .maybeSingle();

    if (row == null) {
      await _client.from('user_profiles').upsert({
        'auth_user_id': user.id,
        'data': _initialProfileData(user),
      }, onConflict: 'auth_user_id');
      row = await _client
          .from('user_profiles')
          .select('id,auth_user_id,data,saki_id,created_at,updated_at')
          .eq('auth_user_id', user.id)
          .maybeSingle();
    }

    try {
      await _client.rpc('ensure_my_saki_id');
      row = await _client
          .from('user_profiles')
          .select('id,auth_user_id,data,saki_id,created_at,updated_at')
          .eq('auth_user_id', user.id)
          .maybeSingle();
    } catch (_) {
      // Profile and authentication remain usable if optional Saki ID allocation fails.
    }

    if (row == null) return null;
    final profile = Map<String, dynamic>.from(row);
    profile['auth_user_id'] = user.id;
    profile['data'] = _mergeInitialData(_map(profile['data']), user);
    return profile;
  }

  Map<String, dynamic> _initialProfileData(User user) {
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final fullName =
        (metadata['fullName'] ??
                metadata['full_name'] ??
                metadata['name'] ??
                '')
            .toString()
            .trim();
    final emailName = (user.email ?? '').split('@').first;
    final username = (metadata['userName'] ?? metadata['username'] ?? '')
        .toString()
        .trim();
    final resolvedUsername = username.isNotEmpty
        ? username
        : _safeUsername(fullName.isNotEmpty ? fullName : emailName);
    return {
      'fullName': fullName,
      'name': fullName,
      'nickname': fullName,
      'userName': resolvedUsername,
      'gender': (metadata['gender'] ?? '').toString(),
      'countryCode': (metadata['countryCode'] ?? '').toString(),
      if (user.email != null) 'email': user.email,
    };
  }

  Map<String, dynamic> _mergeInitialData(
    Map<String, dynamic> stored,
    User user,
  ) {
    final initial = _initialProfileData(user);
    for (final entry in initial.entries) {
      final existing = stored[entry.key];
      if (existing == null || existing.toString().trim().isEmpty) {
        stored[entry.key] = entry.value;
      }
    }
    return stored;
  }

  Future<Map<String, int>> getMyProfileStats() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const {};

    final followers = await _client
        .from('user_follows')
        .select('follower_id')
        .eq('following_id', userId)
        .limit(1000);
    final following = await _client
        .from('user_follows')
        .select('following_id')
        .eq('follower_id', userId)
        .limit(1000);
    final posts = await _client
        .from('moments')
        .select('id')
        .eq('user_id', userId)
        .limit(1000);

    return {
      'posts': posts.length,
      'followers': followers.length,
      'following': following.length,
      'visitors': 0,
    };
  }

  bool isProfileComplete(Map<String, dynamic>? profile) {
    if (profile == null) return false;
    final data = profileData(profile);
    final name = data['fullName'] ?? data['name'] ?? data['display_name'];
    final username = data['userName'] ?? data['username'];
    final country =
        data['countryCode'] ?? data['country'] ?? data['country_code'];
    return [
      name,
      username,
      data['gender'],
      country,
    ].every((value) => value?.toString().trim().isNotEmpty == true);
  }

  Map<String, dynamic> profileData(Map<String, dynamic>? profile) {
    if (profile == null) return <String, dynamic>{};
    final nested = profile['data'];
    return nested is Map
        ? Map<String, dynamic>.from(nested)
        : Map<String, dynamic>.from(profile);
  }

  Future<String> uploadAvatar(
    Uint8List bytes, {
    required String fileName,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw const AuthException('يجب تسجيل الدخول أولًا');
    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
    final path = '$userId/avatars/$safeName';
    final contentType = safeName.toLowerCase().endsWith('.png')
        ? 'image/png'
        : 'image/jpeg';
    await _client.storage
        .from('user-media')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(upsert: true, contentType: contentType),
        );
    return _client.storage.from('user-media').getPublicUrl(path);
  }

  Future<int> saveMyProfile({
    required String fullName,
    required String nickname,
    required String userName,
    required String gender,
    required String countryCode,
    required String about,
    required List<String> interests,
    String? avatarUrl,
  }) async {
    final values = <String, dynamic>{
      'fullName': fullName.trim(),
      'name': fullName.trim(),
      'nickname': nickname.trim(),
      'userName': userName.trim(),
      'gender': gender,
      'countryCode': countryCode,
      'country': countryCode,
      'about': about.trim(),
      'bio': about.trim(),
      'interests': interests,
      if (avatarUrl != null && avatarUrl.isNotEmpty) ...{
        'avatarUrl': avatarUrl,
        'avatar_url': avatarUrl,
      },
    };
    return _mergeAndSaveProfile(values);
  }

  Future<void> updateMyProfile(Map<String, dynamic> values) async {
    await _mergeAndSaveProfile(values);
  }

  Future<int> _mergeAndSaveProfile(Map<String, dynamic> values) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw const AuthException('يجب تسجيل الدخول أولًا');

    final current = await _client
        .from('user_profiles')
        .select('data')
        .eq('auth_user_id', userId)
        .maybeSingle();
    final data = _map(current?['data'])..addAll(values);
    await _client.from('user_profiles').upsert({
      'auth_user_id': userId,
      'data': data,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'auth_user_id');
    final result = await _client.rpc('ensure_my_saki_id');
    return result is num ? result.toInt() : int.tryParse('$result') ?? 0;
  }

  bool get isConfigured => AppConfig.isConfigured;

  Future<String?> get sessionToken async =>
      _client.auth.currentSession?.accessToken;
}

Map<String, dynamic> _authUserMap(User? user) {
  if (user == null) return <String, dynamic>{};
  return {
    'id': user.id,
    'email': user.email,
    'user_metadata': user.userMetadata ?? const <String, dynamic>{},
  };
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
