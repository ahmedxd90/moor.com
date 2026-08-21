import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/supabase/supabase_client.dart';

class AuthRepository {
  const AuthRepository();

  SupabaseClient get _client => SupabaseService.client;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  User? get currentUser => _client.auth.currentUser;

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String name,
  }) {
    return _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'name': name.trim()},
    );
  }

  Future<void> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'saki.chat.co://login-callback',
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<Map<String, dynamic>?> getMyProfile() async {
    final user = currentUser;
    if (user == null) return null;
    return _client
        .from('user_profiles')
        .select('id, auth_user_id, data, phone_number, created_at, updated_at')
        .eq('auth_user_id', user.id)
        .maybeSingle();
  }

  bool isProfileComplete(Map<String, dynamic>? profile) {
    if (profile == null) return false;
    final raw = profile['data'];
    final data = raw is Map
        ? Map<String, dynamic>.from(raw)
        : const <String, dynamic>{};
    final fullName = (data['fullName'] as String?)?.trim() ?? '';
    final nickname = (data['nickname'] as String?)?.trim() ?? '';
    final userName = (data['userName'] as String?)?.trim() ?? '';
    final gender = (data['gender'] as String?)?.trim() ?? '';
    return fullName.isNotEmpty &&
        nickname.isNotEmpty &&
        userName.isNotEmpty &&
        gender.isNotEmpty;
  }

  Map<String, dynamic> profileData(Map<String, dynamic>? profile) {
    final raw = profile?['data'];
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  Future<void> saveMyProfile({
    required String fullName,
    required String nickname,
    required String userName,
    required String gender,
    required String countryCode,
    required String about,
    required List<String> interests,
  }) async {
    final user = currentUser;
    if (user == null) throw const AuthException('يجب تسجيل الدخول أولًا');
    final data = {
      'id': user.id,
      'userId': user.id,
      'email': user.email,
      'fullName': fullName.trim(),
      'nickname': nickname.trim(),
      'userName': userName.trim(),
      'gender': gender,
      'countryCode': countryCode,
      'about': about.trim(),
      'interests': interests,
      'followers': <String>[],
      'following': <String>[],
      'favSongs': <String>[],
      'favTeels': <String>[],
      'isOnline': true,
      'isVerified': false,
      'isPremium': false,
      'profileCategoryName': 'New',
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    };
    await _client.from('user_profiles').upsert({
      'auth_user_id': user.id,
      'phone_number': user.phone,
      'data': data,
    }, onConflict: 'auth_user_id');
  }

  Future<void> updateMyProfile(Map<String, dynamic> values) async {
    final user = currentUser;
    if (user == null) throw const AuthException('يجب تسجيل الدخول أولًا');
    final current = await getMyProfile();
    final data = profileData(current)..addAll(values);
    await _client
        .from('user_profiles')
        .update({'data': data})
        .eq('auth_user_id', user.id);
  }

  bool get isConfigured => AppConfig.isConfigured;
}
