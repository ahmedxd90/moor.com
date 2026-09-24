import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

class SakiApiException implements Exception {
  const SakiApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class SakiApiClient {
  const SakiApiClient();

  static const _tokenKey = 'saki_api_session_token';

  Uri _uri(String action, [Map<String, String>? query]) {
    return Uri.parse(AppConfig.apiUrl).replace(queryParameters: {
      'action': action,
      ...?query,
    });
  }

  Future<String?> token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> saveToken(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, value);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Future<Map<String, dynamic>> request(
    String action, {
    String method = 'GET',
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    final headers = <String, String>{'Accept': 'application/json'};
    final session = await token();
    if (session != null && session.isNotEmpty) {
      headers['Authorization'] = 'Bearer $session';
    }
    final uri = _uri(action, query);
    late http.Response response;
    if (method == 'GET') {
      response = await http.get(uri, headers: headers);
    } else {
      headers['Content-Type'] = 'application/json; charset=utf-8';
      response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(body ?? const <String, dynamic>{}),
      );
    }
    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw SakiApiException('استجابة غير صالحة من الخادم', statusCode: response.statusCode);
    }
    if (response.statusCode >= 400 || payload['ok'] != true) {
      throw SakiApiException(
        (payload['message'] ?? payload['error'] ?? 'تعذر تنفيذ الطلب').toString(),
        statusCode: response.statusCode,
      );
    }
    return payload;
  }

  Future<Map<String, dynamic>> uploadAvatar(Uint8List bytes, String fileName) async {
    final session = await token();
    if (session == null) throw const SakiApiException('يجب تسجيل الدخول أولًا');
    final request = http.MultipartRequest('POST', _uri('avatar_upload'))
      ..headers['Authorization'] = 'Bearer $session'
      ..files.add(http.MultipartFile.fromBytes('avatar', bytes, filename: fileName));
    final response = await http.Response.fromStream(await request.send());
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400 || payload['ok'] != true) {
      throw SakiApiException((payload['error'] ?? 'فشل رفع الصورة').toString(), statusCode: response.statusCode);
    }
    return payload;
  }
}
