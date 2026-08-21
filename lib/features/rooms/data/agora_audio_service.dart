import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

class AgoraAudioState {
  const AgoraAudioState({
    this.initialized = false,
    this.joined = false,
    this.speaking = false,
    this.muted = true,
    this.remoteMuted = false,
    this.remoteUsers = 0,
    this.error,
  });

  final bool initialized;
  final bool joined;
  final bool speaking;
  final bool muted;
  final bool remoteMuted;
  final int remoteUsers;
  final String? error;

  AgoraAudioState copyWith({
    bool? initialized,
    bool? joined,
    bool? speaking,
    bool? muted,
    bool? remoteMuted,
    int? remoteUsers,
    String? error,
    bool clearError = false,
  }) {
    return AgoraAudioState(
      initialized: initialized ?? this.initialized,
      joined: joined ?? this.joined,
      speaking: speaking ?? this.speaking,
      muted: muted ?? this.muted,
      remoteMuted: remoteMuted ?? this.remoteMuted,
      remoteUsers: remoteUsers ?? this.remoteUsers,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class AgoraAudioService {
  AgoraAudioService({String? appId, String? token})
    : _appId = appId ?? _defaultAppId,
      _token = token ?? _defaultToken;

  static const _defaultAppId = String.fromEnvironment(
    'AGORA_APP_ID',
    defaultValue: '0d1e69abe9734f03944293c27b74365d',
  );
  static const _defaultToken = String.fromEnvironment('AGORA_TOKEN');

  final String _appId;
  final String _token;
  final _state = StreamController<AgoraAudioState>.broadcast();
  AgoraAudioState _current = const AgoraAudioState();
  RtcEngine? _engine;
  RtcEngineEventHandler? _handler;
  bool _disposed = false;

  AgoraAudioState get currentState => _current;
  Stream<AgoraAudioState> get states => _state.stream;
  bool get hasToken => _token.isNotEmpty;

  Future<void> initialize() async {
    if (_current.initialized || _disposed) return;
    if (_appId.isEmpty) {
      throw StateError('لم يتم ضبط Agora App ID');
    }

    final engine = createAgoraRtcEngine();
    await engine.initialize(RtcEngineContext(appId: _appId));
    final handler = RtcEngineEventHandler(
      onError: (error, message) {
        _emit(_current.copyWith(error: 'Agora: $error $message'));
      },
      onJoinChannelSuccess: (_, __) {
        _emit(_current.copyWith(joined: true, clearError: true));
      },
      onLeaveChannel: (_, __) {
        _emit(
          _current.copyWith(
            joined: false,
            speaking: false,
            muted: true,
            remoteUsers: 0,
          ),
        );
      },
      onUserJoined: (_, __, ___) {
        _emit(_current.copyWith(remoteUsers: _current.remoteUsers + 1));
      },
      onUserOffline: (_, __, ___) {
        _emit(
          _current.copyWith(
            remoteUsers: _current.remoteUsers > 0
                ? _current.remoteUsers - 1
                : 0,
          ),
        );
      },
    );
    engine.registerEventHandler(handler);
    await engine.enableAudio();
    _engine = engine;
    _handler = handler;
    _emit(_current.copyWith(initialized: true, clearError: true));
  }

  Future<void> joinAsListener(String channelId) async {
    await initialize();
    final engine = _engine;
    if (engine == null || _current.joined) return;
    await engine.joinChannel(
      token: _token,
      channelId: channelId,
      uid: 0,
      options: const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        clientRoleType: ClientRoleType.clientRoleAudience,
        publishMicrophoneTrack: false,
        autoSubscribeAudio: true,
      ),
    );
  }

  Future<void> takeSeat() async {
    final engine = _engine;
    if (engine == null || !_current.joined) return;
    final permission = await Permission.microphone.request();
    if (!permission.isGranted && !permission.isLimited) {
      throw StateError('يجب السماح بالوصول إلى الميكروفون للتحدث');
    }
    await engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await engine.updateChannelMediaOptions(
      const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishMicrophoneTrack: true,
        autoSubscribeAudio: true,
      ),
    );
    await engine.muteLocalAudioStream(false);
    _emit(_current.copyWith(speaking: true, muted: false, clearError: true));
  }

  Future<void> leaveSeat() async {
    final engine = _engine;
    if (engine == null || !_current.joined) return;
    await engine.muteLocalAudioStream(true);
    await engine.setClientRole(role: ClientRoleType.clientRoleAudience);
    await engine.updateChannelMediaOptions(
      const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        clientRoleType: ClientRoleType.clientRoleAudience,
        publishMicrophoneTrack: false,
        autoSubscribeAudio: true,
      ),
    );
    _emit(_current.copyWith(speaking: false, muted: true));
  }

  Future<void> setMicrophoneMuted(bool muted) async {
    final engine = _engine;
    if (engine == null || !_current.speaking) return;
    await engine.muteLocalAudioStream(muted);
    _emit(_current.copyWith(muted: muted));
  }

  Future<void> setRemoteAudioMuted(bool muted) async {
    final engine = _engine;
    if (engine == null) return;
    await engine.muteAllRemoteAudioStreams(muted);
    _emit(_current.copyWith(remoteMuted: muted));
  }

  Future<void> leaveChannel() async {
    final engine = _engine;
    if (engine == null) return;
    if (_current.joined) await engine.leaveChannel();
    if (_handler != null) engine.unregisterEventHandler(_handler!);
    await engine.release();
    _engine = null;
    _handler = null;
    _emit(const AgoraAudioState());
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await leaveChannel();
    await _state.close();
  }

  void _emit(AgoraAudioState next) {
    if (_disposed) return;
    _current = next;
    if (!_state.isClosed) _state.add(next);
  }
}
