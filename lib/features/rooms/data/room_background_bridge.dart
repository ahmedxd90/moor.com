import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class RoomBackgroundBridge {
  RoomBackgroundBridge._();

  static const _channel = MethodChannel('co.saki.saki_chat_flutter/room_background');
  static bool _configured = false;
  static void Function(Map<String, dynamic>? data)? _onOpenRoom;

  static void configure({void Function(Map<String, dynamic>? data)? onOpenRoom}) {
    _onOpenRoom = onOpenRoom;
    if (_configured || kIsWeb) return;
    _configured = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openRoom') {
        final data = call.arguments is Map
            ? Map<String, dynamic>.from(call.arguments as Map)
            : null;
        _onOpenRoom?.call(data);
      }
    });
  }

  static Future<bool> start({
    required String roomName,
    String? roomId,
    required String roomNumber,
    String? coverUrl,
    bool showBubble = false,
  }) async {
    if (kIsWeb) return false;
    try {
      final result = await _channel.invokeMethod<bool>('start', {
        'roomId': roomId,
        'roomName': roomName,
        'roomNumber': roomNumber,
        'coverUrl': coverUrl,
        'showBubble': showBubble,
      });
      return result == true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> showBubble({
    required String roomName,
    String? roomId,
    required String roomNumber,
    String? coverUrl,
  }) async {
    if (kIsWeb) return false;
    try {
      final result = await _channel.invokeMethod<bool>('showBubble', {
        'roomId': roomId,
        'roomName': roomName,
        'roomNumber': roomNumber,
        'coverUrl': coverUrl,
      });
      return result == true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> hideBubble() async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<void>('hideBubble');
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  static Future<void> stop() async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<void>('stop');
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  static Future<bool> canDrawOverlays() async {
    if (kIsWeb) return false;
    try {
      return await _channel.invokeMethod<bool>('canDrawOverlays') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> requestOverlayPermission() async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<void>('requestOverlayPermission');
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }
}

class RoomPermissions {
  RoomPermissions._();

  static Future<void> requestCoreRoomPermissions() async {
    if (kIsWeb) return;
    await [Permission.microphone, Permission.notification].request();
  }

  static Future<void> requestMediaPermissions() async {
    if (kIsWeb) return;
    await [
      Permission.audio,
      Permission.photos,
      Permission.videos,
      Permission.storage,
    ].request();
  }
}
