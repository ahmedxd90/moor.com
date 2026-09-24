import 'dart:typed_data';

import '../../../core/api/saki_api_client.dart';

class SakiAuthResponse {
  const SakiAuthResponse({this.session, this.user});
  final String? session;
  final Map<String, dynamic>? user;
}

class AuthRepository {
  const AuthRepository();

  static const _api = SakiApiClient();

  Future<SakiAuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final result = await _api.request(
      'login',
      method: 'POST',
      body: {'identity': email.trim(), 'password': password},
    );
    final token = result['token']?.toString();
    if (token == null || token.isEmpty) throw const SakiApiException('لم يرجع الخادم جلسة صالحة');
    await _api.saveToken(token);
    return SakiAuthResponse(session: token, user: _map(result['data']));
  }

  Future<SakiAuthResponse> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    final result = await _api.request(
      'register',
      method: 'POST',
      body: {
        'username': _safeUsername(name),
        'email': email.trim(),
        'password': password,
      },
    );
    return SakiAuthResponse(user: _map(result['data']));
  }

  String _safeUsername(String value) {
    final cleaned = value.trim().toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
    return cleaned.length >= 3 ? cleaned.substring(0, cleaned.length > 30 ? 30 : cleaned.length) : 'saki_user';
  }

  Future<void> signOut() => _api.clearToken();

  Future<void> signInWithGoogle() async {
    throw const SakiApiException('تسجيل Google يحتاج إعداد OAuth على الخادم');
  }

  Future<void> sendPasswordReset({required String email}) async {
    throw const SakiApiException('استعادة كلمة المرور ستُفعّل بعد إضافة SMTP في الاستضافة');
  }

  Future<Map<String, dynamic>?> getMyProfile() async {
    try {
      final result = await _api.request('profile_me');
      final data = _map(result['data']);
      return data.isEmpty ? null : data;
    } on SakiApiException catch (error) {
      if (error.statusCode == 401) await signOut();
      return null;
    }
  }

  Future<Map<String, int>> getMyProfileStats() async {
    final profile = await getMyProfile();
    final id = profile?['id']?.toString();
    if (id == null) return const {};
    final result = await _api.request('user_profile_stats', query: {'user_id': id});
    final rows = result['data'] is List ? result['data'] as List : const [];
    final row = rows.isNotEmpty && rows.first is Map ? Map<String, dynamic>.from(rows.first) : const <String, dynamic>{};
    return {for (final entry in row.entries) entry.key: (entry.value as num?)?.toInt() ?? 0};
  }

  bool isProfileComplete(Map<String, dynamic>? profile) {
    if (profile == null) return false;
    return [profile['display_name'], profile['username'], profile['gender'], profile['country']]
        .every((value) => value?.toString().trim().isNotEmpty == true);
  }

  Map<String, dynamic> profileData(Map<String, dynamic>? profile) => profile ?? <String, dynamic>{};

  Future<String> uploadAvatar(Uint8List bytes, {required String fileName}) async {
    final result = await _api.uploadAvatar(bytes, fileName);
    return ((_map(result['data']))['avatar_url'] ?? '').toString();
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
    final result = await _api.request('profile_update', method: 'POST', body: {
      'display_name': fullName.trim(),
      'username': userName.trim(),
      'gender': gender,
      'country_code': countryCode,
      'country': countryCode,
      'bio': about.trim(),
      if (avatarUrl != null && avatarUrl.isNotEmpty) 'avatar_url': avatarUrl,
    });
    return int.tryParse((_map(result['data'])['saki_id'] ?? '0').toString()) ?? 0;
  }

  Future<void> updateMyProfile(Map<String, dynamic> values) async {
    await _api.request('profile_update', method: 'POST', body: values);
  }

  bool get isConfigured => true;
  Future<String?> get sessionToken => _api.token();
}

Map<String, dynamic> _map(dynamic value) => value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
